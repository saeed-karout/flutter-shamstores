import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// مسار القيادة بين نقطتين.
class DrivingRoute {
  /// نقاط الخطّ المرسوم على الخريطة
  final List<LatLng> points;

  /// المسافة بالمتر على الطريق — لا الخطّ المستقيم
  final double distanceMeters;

  /// الزمن المتوقّع بالثواني
  final double durationSeconds;

  const DrivingRoute({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  String get formattedDistance => distanceMeters < 1000
      ? '${distanceMeters.toStringAsFixed(0)} م'
      : '${(distanceMeters / 1000).toStringAsFixed(1)} كم';

  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 1) return 'أقلّ من دقيقة';
    if (minutes < 60) return '$minutes دقيقة';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours ساعة' : '$hours س $rest د';
  }
}

/// حساب المسار داخل التطبيق.
///
/// **لماذا:** الخريطة كانت ترسم خطّاً مستقيماً بين نقطتين. والخطّ المستقيم
/// يكذب مرّتين: يقصّر المسافة (نهر أو جدار بينهما لا يعبره السائق)، ويعطي
/// اتجاهاً لا يصلح للسير. والبديل الوحيد كان زرّاً يخرج إلى خرائط Google —
/// أي مغادرة التطبيق، وفقدان زرّ «تم التسليم» وزرّ الطوارئ معه.
///
/// **OSRM** خدمة توجيه مفتوحة بلا مفتاح ولا فوترة — متّسقة مع اختيار
/// OpenStreetMap للبلاطات.
///
/// ⚠️ الخادم العام (`router.project-osrm.org`) خادم تجريبي بلا ضمان خدمة.
/// للإنتاج الجادّ يُستضاف OSRM ذاتياً ويُضبط `ROUTING_BASE_URL`. ولذلك
/// **الفشل هنا ليس عطلاً**: تعود الخريطة إلى الخطّ المستقيم وتكمل عملها.
class RouteService {
  static const String _baseUrl = String.fromEnvironment(
    'ROUTING_BASE_URL',
    defaultValue: 'https://router.project-osrm.org',
  );

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// ذاكرة صغيرة: الشاشة تُعاد بناؤها مع كل نبضة موقع، وطلبُ مسارٍ لكل نبضة
  /// يُغرق الخدمة ويستهلك بيانات السائق بلا فائدة.
  static final Map<String, DrivingRoute> _cache = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(3)},${a.longitude.toStringAsFixed(3)}'
      '|${b.latitude.toStringAsFixed(3)},${b.longitude.toStringAsFixed(3)}';

  static Future<DrivingRoute?> fetch(LatLng from, LatLng to) async {
    final key = _key(from, to);
    final cached = _cache[key];
    if (cached != null) return cached;

    try {
      final coords = '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final res = await _dio.get(
        '$_baseUrl/route/v1/driving/$coords',
        queryParameters: const {'overview': 'full', 'geometries': 'geojson'},
      );

      final routes = res.data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map;
      final geometry = route['geometry'] as Map?;
      final rawPoints = geometry?['coordinates'] as List?;
      if (rawPoints == null || rawPoints.isEmpty) return null;

      // GeoJSON يكتب [طول, عرض] — والعكس يضع المسار في نصف الكرة الآخر
      final points = rawPoints
          .whereType<List>()
          .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
          .toList();

      final result = DrivingRoute(
        points: points,
        distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
        durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
      );

      // حدٌّ للذاكرة: نوبة طويلة بعشرات الطلبات لا يجوز أن تُراكم بلا سقف
      if (_cache.length > 40) _cache.clear();
      _cache[key] = result;
      return result;
    } catch (e) {
      debugPrint('RouteService failed: $e');
      return null;
    }
  }
}
