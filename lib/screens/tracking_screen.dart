import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order_model.dart';
import '../services/location_service.dart';
import '../services/order_service.dart';
import '../utils/constants.dart';
import '../widgets/collect_payment_sheet.dart';
import '../widgets/delivery_map.dart';
import '../widgets/sos_sheet.dart';

/// شاشة التتبّع — الخريطة ملء الشاشة مع لوحة سفلية للخطوة التالية.
///
/// كانت الخريطة شريطاً بارتفاع ٢٥٠ بكسل في أعلى صفحة التفاصيل، يُمرَّر بعيداً
/// بمجرّد أن يقرأ السائق العنوان. وهو يقود: يحتاج الخريطة كاملةً وزرّاً
/// واحداً كبيراً، لا بطاقةً يبحث فيها.
class TrackingScreen extends StatefulWidget {
  final String orderId;

  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final GlobalKey<DeliveryMapState> _mapKey = GlobalKey<DeliveryMapState>();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // موقع السائق أوّل ما تحتاجه الخريطة، ولا يصل إلا بعد قراءة أولى
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationService>().getCurrentPosition();
    });
  }

  Future<void> _navigate(LatLng target) async {
    final geo = Uri.parse('geo:${target.latitude},${target.longitude}?q=${target.latitude},${target.longitude}');
    if (await canLaunchUrl(geo)) {
      await launchUrl(geo);
      return;
    }
    await launchUrl(
      Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}'),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _advance(DeliveryOrder order) async {
    final service = context.read<OrderService>();

    // الدفع عند الباب يمرّ بورقة تحصيل صريحة: المال لا يُسجَّل بالنيابة عن
    // أحد، والخادم يرفض الإكمال قبل تسجيله أصلاً.
    String? method;
    if (!order.awaitingPickup && order.needsCashCollection) {
      method = await CollectPaymentSheet.show(context, order);
      if (method == null) return; // تراجع السائق
      if (!mounted) return;
    }

    setState(() => _busy = true);

    String? error;
    if (order.awaitingPickup) {
      final ok = await service.updateStatus(order.id, 'delivering');
      error = ok ? null : 'تعذّر التحديث — حاول ثانيةً';
    } else {
      error = await service.markDelivered(order.id, paymentMethod: method);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? (order.awaitingPickup ? 'انطلقت — بالتوفيق' : 'تم تسليم الطلب ✅')),
        backgroundColor: error == null ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (error == null && !order.awaitingPickup && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final locationService = context.watch<LocationService>();
    final order = orderService.getOrderById(widget.orderId);

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('التتبّع')),
        body: const Center(
          child: Text('الطلب لم يعد ضمن طلباتك', style: TextStyle(fontFamily: 'Cairo')),
        ),
      );
    }

    final pickup = order.hasPickupPoint ? LatLng(order.restaurantLat!, order.restaurantLng!) : null;
    final drop = order.hasDropPoint ? LatLng(order.deliveryLat!, order.deliveryLng!) : null;
    final position = locationService.currentPosition;
    final driver = position != null ? LatLng(position.latitude, position.longitude) : null;

    // الوجهة تتبع مرحلة الطلب: قبل الاستلام المحلّ، وبعده الزبون
    final target = order.awaitingPickup ? (pickup ?? drop) : (drop ?? pickup);
    final remaining = (driver != null && target != null) ? distanceMeters(driver, target) : null;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DeliveryMap(
              key: _mapKey,
              pickup: pickup,
              drop: drop,
              driver: driver,
              pickupLabel: order.restaurantName ?? 'الاستلام',
              dropLabel: order.customerName ?? 'التسليم',
            ),
          ),

          // الرجوع
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _roundButton(Icons.arrow_back, () => Navigator.pop(context)),
          ),

          // إعادة الإطار — الخريطة تنزلق تحت الإصبع أثناء القيادة
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Column(
              children: [
                _roundButton(Icons.center_focus_strong, () => _mapKey.currentState?.fitAll()),
                const SizedBox(height: 8),
                _roundButton(Icons.my_location, () async {
                  await context.read<LocationService>().getCurrentPosition();
                  _mapKey.currentState?.fitAll();
                }),
                const SizedBox(height: 8),
                // الطوارئ في متناول الإبهام وهو على الطريق — لا في قائمة
                Material(
                  color: AppColors.error,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => SosSheet.show(context, context.read<OrderService>().client),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(Icons.sos, color: Colors.white, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: _panel(order, target, remaining),
          ),
        ],
      ),
    );
  }

  Widget _roundButton(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
        ),
      );

  Widget _panel(DeliveryOrder order, LatLng? target, double? remaining) {
    final isPickupStage = order.awaitingPickup;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Icon(
                isPickupStage ? Icons.storefront : Icons.person_pin_circle,
                color: isPickupStage ? AppColors.warning : AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPickupStage ? 'استلم من' : 'سلّم إلى',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      isPickupStage
                          ? (order.restaurantName ?? 'المحلّ')
                          : (order.customerName ?? 'الزبون'),
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (remaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    formatDistance(remaining),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),

          if ((isPickupStage ? order.restaurantAddress : order.deliveryAddress) != null) ...[
            const SizedBox(height: 8),
            Text(
              (isPickupStage ? order.restaurantAddress : order.deliveryAddress)!,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, height: 1.7, color: AppColors.textMuted),
            ),
          ],

          const SizedBox(height: 14),

          Row(
            children: [
              if (target != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _navigate(target),
                    icon: const Icon(Icons.navigation_outlined, size: 18),
                    label: const Text('ابدأ الملاحة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              if (target != null && order.customerPhone != null) const SizedBox(width: 10),
              if (order.customerPhone != null)
                SizedBox(
                  width: 56,
                  child: OutlinedButton(
                    onPressed: () => launchUrl(Uri(scheme: 'tel', path: order.customerPhone)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      padding: EdgeInsets.zero,
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.phone, size: 20),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: _busy ? null : () => _advance(order),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 52),
              backgroundColor: isPickupStage ? AppColors.primary : AppColors.success,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(
                    isPickupStage ? 'استلمت الطلب — انطلقت' : 'تم التسليم',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800),
                  ),
          ),

          if (order.needsCashCollection) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اقبض ${order.total.toStringAsFixed(0)} ل.س نقداً عند التسليم',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
