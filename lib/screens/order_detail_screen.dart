import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/order_service.dart';
import '../services/location_service.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';
import '../widgets/delivery_map.dart';
import '../utils/formatters.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _actionLoading = false;
  File? _deliveryImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (pickedFile != null) {
      setState(() => _deliveryImage = File(pickedFile.path));
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsApp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    final uri = Uri.parse('https://wa.me/$cleaned');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _launchMapNavigation(double lat, double lng) async {
    final uri = Uri.parse('google.navigation:q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      await launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderService = context.watch<OrderService>();
    final locationService = context.watch<LocationService>();
    final order = orderService.getOrderById(widget.orderId);

    if (order == null) return const Scaffold(body: Center(child: Text('الطلب غير موجود')));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // معاينة غير تفاعلية: النقر يفتح شاشة التتبّع كاملة، بدل
                  // خريطة صغيرة تسرق لمسة السائق وهو يريد التمرير
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.tracking,
                      arguments: order.id,
                    ),
                    child: DeliveryMap(
                      interactive: false,
                      pickup: order.hasPickupPoint
                          ? LatLng(order.restaurantLat!, order.restaurantLng!)
                          : null,
                      drop: order.hasDropPoint
                          ? LatLng(order.deliveryLat!, order.deliveryLng!)
                          : null,
                      driver: locationService.currentPosition != null
                          ? LatLng(
                              locationService.currentPosition!.latitude,
                              locationService.currentPosition!.longitude,
                            )
                          : null,
                      pickupLabel: order.restaurantName ?? 'الاستلام',
                      dropLabel: order.customerName ?? 'التسليم',
                    ),
                  ),
                  
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.4), Colors.transparent, Colors.black.withOpacity(0.6)],
                      ),
                    ),
                  ),

                  if (order.hasDropPoint || order.hasPickupPoint)
                    Positioned(
                      bottom: 15,
                      right: 15,
                      child: FloatingActionButton.extended(
                        heroTag: 'open-tracking',
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.tracking,
                          arguments: order.id,
                        ),
                        icon: const Icon(Icons.map_outlined, size: 18),
                        label: const Text(
                          'تتبّع على الخريطة',
                          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            leading: IconButton(
              icon: const CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.arrow_back, color: AppColors.primary, size: 20)),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('طلب #${order.orderNumber}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary)),
                          Text(order.createdAt, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                      _buildStatusBadge(order.status),
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildContactSection(order),
                  const SizedBox(height: 25),
                  const Text('محتويات الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildItemsList(order),
                  const SizedBox(height: 25),
                  _buildLocationDetails(order, locationService),
                  const SizedBox(height: 25),
                  _buildPaymentSummary(order),
                  const SizedBox(height: 150),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomActions(order, orderService),
    );
  }

  Widget _buildStatusBadge(String status) {
    final color = OrderStatusHelper.getColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(30), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(OrderStatusHelper.getLabel(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildContactSection(DeliveryOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)]),
      child: Row(
        children: [
          // صورة صاحب الطلب — وجهٌ يبحث عنه السائق عند الباب.
          // وبلا صورة: الحرف الأول من اسمه، لا أيقونةٌ عامّة تتكرّر على كل
          // الطلبات فلا تميّز أحداً.
          CircleAvatar(
            radius: 25,
            backgroundColor: AppColors.accent,
            backgroundImage: (order.customerAvatar != null && order.customerAvatar!.isNotEmpty)
                ? NetworkImage(order.customerAvatar!)
                : null,
            child: (order.customerAvatar == null || order.customerAvatar!.isEmpty)
                ? Text(
                    order.customerInitial,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.customerName ?? 'عميل شام ستور', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(order.customerPhone ?? 'لا يوجد رقم هاتف', style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
              ],
            ),
          ),
          IconButton(onPressed: () => _launchPhone(order.customerPhone ?? ''), icon: const Icon(Icons.phone, color: AppColors.success)),
          IconButton(onPressed: () => _launchWhatsApp(order.customerPhone ?? ''), icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Color(0xFF25D366))),
        ],
      ),
    );
  }

  Widget _buildItemsList(DeliveryOrder order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: BorderRadius.circular(8)),
                child: Text('${item.quantity}x', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(item.itemName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
              Text(Money.format(item.price), style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildLocationDetails(DeliveryOrder order, LocationService ls) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('موقع التوصيل', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(15)),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.location_on, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(child: Text(order.deliveryAddress ?? 'غير محدد', style: const TextStyle(fontSize: 14))),
                ],
              ),
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المسافة التقريبية:', style: TextStyle(color: AppColors.textMuted)),
                  Text(ls.formattedDistanceTo(order.deliveryLat ?? 0, order.deliveryLng ?? 0) ?? '-', style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () => _launchMapNavigation(order.deliveryLat ?? 0, order.deliveryLng ?? 0),
                icon: const Icon(Icons.navigation),
                label: const Text('بدء التوجيه (GPS)'),
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSummary(DeliveryOrder order) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _summaryRow('المجموع الفرعي', Money.format(order.subtotal), Colors.white70),
          _summaryRow('رسوم التوصيل', '+${Money.format(order.deliveryFee)}', Colors.white70),
          if (order.discountAmount > 0) _summaryRow('الخصم', '-${Money.format(order.discountAmount)}', AppColors.accent),
          const Divider(color: Colors.white24, height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              Text(Money.format(order.total), style: const TextStyle(color: AppColors.accent, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: color, fontSize: 13)), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildBottomActions(DeliveryOrder order, OrderService orderService) {
    if (!order.isActive) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Theme.of(context).cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (order.status == 'delivering') ...[
            if (_deliveryImage != null)
              Container(
                height: 100,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(_deliveryImage!), fit: BoxFit.cover)),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _deliveryImage = null)),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.camera_alt),
                label: const Text('تصوير إثبات التسليم'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 45)),
              ),
            const SizedBox(height: 10),
          ],
          _actionLoading
            ? const LinearProgressIndicator()
            : ElevatedButton(
                onPressed: () async {
                  setState(() => _actionLoading = true);

                  String? error;
                  if (order.status == 'delivering') {
                    final ok = await orderService.markDelivered(order.id, image: _deliveryImage);
                    error = ok ? null : 'تعذّر تأكيد التسليم';
                  } else {
                    error = await orderService.acceptOrder(order.id);
                  }

                  if (!mounted) return;
                  setState(() => _actionLoading = false);

                  // الفشل كان يُبتلع صامتاً: يضغط السائق فلا يتغيّر شيء
                  if (error != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(error),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(context);
                },
                child: Text(
                  order.status == 'delivering'
                      ? 'تأكيد إتمام التسليم'
                      : order.isAvailable
                          ? 'استلم هذا الطلب'
                          : 'قبول الطلب وبدء الرحلة',
                ),
              ),
        ],
      ),
    );
  }
}
