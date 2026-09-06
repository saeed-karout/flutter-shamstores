import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../utils/constants.dart';

/// خريطة التوصيل — نقطة الاستلام، ونقطة التسليم، وموقع السائق.
///
/// **لماذا OpenStreetMap لا خرائط Google:** مفتاح Google في
/// `AndroidManifest.xml` كان نصّاً حرفياً `YOUR_GOOGLE_MAPS_API_KEY_HERE`.
/// خريطةٌ بمفتاح غير صالح لا تعتذر — ترسم شبكة رمادية فارغة. فالسائق يفتح
/// الطلب فيجد مستطيلاً رمادياً، ويظنّ التطبيق معطّلاً.
///
/// وبلاطات OSM لا تحتاج مفتاحاً ولا حساب فوترة ولا بطاقة مصرفية — وهي
/// اعتبارات ليست هيّنة لمنصّة تعمل من سوريا.
class DeliveryMap extends StatefulWidget {
  final LatLng? pickup;
  final LatLng? drop;
  final LatLng? driver;
  final String? pickupLabel;
  final String? dropLabel;

  /// يمنع تحريك الخريطة — للمعاينة داخل بطاقة
  final bool interactive;

  /// مسار القيادة الحقيقي. بغيابه يُرسم خطّ مستقيم — وهو يكذب مرّتين:
  /// يقصّر المسافة، ويعطي اتجاهاً لا يصلح للسير.
  final List<LatLng>? route;

  const DeliveryMap({
    super.key,
    this.pickup,
    this.drop,
    this.driver,
    this.pickupLabel,
    this.dropLabel,
    this.interactive = true,
    this.route,
  });

  @override
  State<DeliveryMap> createState() => DeliveryMapState();
}

class DeliveryMapState extends State<DeliveryMap> {
  final MapController _controller = MapController();
  bool _ready = false;

  List<LatLng> get _points => [
        ...[widget.pickup, widget.drop, widget.driver].whereType<LatLng>(),
        // نقاط المسار تدخل في حساب الإطار: مسارٌ يلتفّ خارج المستطيل الذي
        // يحدّه الطرفان يُقصّ نصفه إن حُسب الإطار من الطرفين وحدهما
        ...(widget.route ?? const <LatLng>[]),
      ];

  /// يضبط الإطار ليشمل كل النقاط.
  ///
  /// تثبيت التكبير على رقم واحد يخفي أحد الطرفين حين يتباعدان، وهو أسوأ ما
  /// تفعله خريطة توصيل: أن تُري السائق نصف الرحلة.
  void fitAll() {
    final points = _points;
    if (points.isEmpty || !_ready) return;

    if (points.length == 1) {
      _controller.move(points.first, 15);
      return;
    }

    _controller.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(56),
        maxZoom: 16,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DeliveryMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickup != widget.pickup ||
        oldWidget.drop != widget.drop ||
        oldWidget.route?.length != widget.route?.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => fitAll());
    }
  }

  LatLng get _center {
    final points = _points;
    if (points.isEmpty) return const LatLng(33.5138, 36.2765); // دمشق
    final lat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;

    if (points.isEmpty) {
      return Container(
        color: AppColors.secondary,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 40, color: Colors.white38),
            SizedBox(height: 8),
            Text(
              'لا يوجد موقع مسجّل لهذا الطلب',
              style: TextStyle(color: Colors.white70, fontFamily: 'Cairo', fontSize: 13),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 14,
        interactionOptions: InteractionOptions(
          flags: widget.interactive ? InteractiveFlag.all & ~InteractiveFlag.rotate : InteractiveFlag.none,
        ),
        onMapReady: () {
          _ready = true;
          fitAll();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          // شرط استخدام بلاطات OSM: معرّف تطبيق حقيقي لا الافتراضي
          userAgentPackageName: 'com.shamstores.delivery',
          maxZoom: 19,
        ),

        // المسار الحقيقي إن توفّر، وإلا خطّ مستقيم متقطّع يقول الاتجاه
        // والمسافة التقريبية. المتقطّع مقصود: شكلُه يقول إنه تقدير لا طريق.
        if (widget.route != null && widget.route!.length > 1)
          PolylineLayer(
            polylines: [
              // حاشية بيضاء تحت الخطّ: الأزرق وحده يضيع فوق شوارع OSM
              Polyline(
                points: widget.route!,
                strokeWidth: 8,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              Polyline(
                points: widget.route!,
                strokeWidth: 5,
                color: AppColors.info,
              ),
            ],
          )
        else if (widget.pickup != null && widget.drop != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [widget.pickup!, widget.drop!],
                strokeWidth: 3,
                color: AppColors.primary.withValues(alpha: 0.65),
                pattern: StrokePattern.dashed(segments: const [10, 6]),
              ),
            ],
          ),

        MarkerLayer(
          markers: [
            if (widget.pickup != null)
              _pin(widget.pickup!, Icons.storefront, AppColors.warning, widget.pickupLabel ?? 'الاستلام'),
            if (widget.drop != null)
              _pin(widget.drop!, Icons.person_pin_circle, AppColors.error, widget.dropLabel ?? 'التسليم'),
            if (widget.driver != null) _driverPin(widget.driver!),
          ],
        ),

        const RichAttributionWidget(
          attributions: [TextSourceAttribution('OpenStreetMap contributors')],
        ),
      ],
    );
  }

  Marker _pin(LatLng point, IconData icon, Color color, String label) => Marker(
        point: point,
        width: 108,
        height: 62,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Icon(icon, color: color, size: 34, shadows: const [
              Shadow(color: Colors.black45, blurRadius: 4),
            ]),
          ],
        ),
      );

  Marker _driverPin(LatLng point) => Marker(
        point: point,
        width: 38,
        height: 38,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.accent,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
          ),
          child: const Icon(Icons.navigation, size: 18, color: AppColors.primary),
        ),
      );
}

/// المسافة بالمتر بين نقطتين — صيغة هافرساين.
///
/// تُحسب هنا لا عبر `geolocator` لأن الشاشة قد تعرض المسافة بين الاستلام
/// والتسليم، ولا علاقة لموقع الجهاز بها.
double distanceMeters(LatLng a, LatLng b) {
  const earthRadius = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;

  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLng / 2) * math.sin(dLng / 2) * math.cos(lat1) * math.cos(lat2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

String formatDistance(double meters) {
  if (meters < 1000) return '${meters.toStringAsFixed(0)} م';
  return '${(meters / 1000).toStringAsFixed(1)} كم';
}
