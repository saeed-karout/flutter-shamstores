import 'package:flutter/material.dart';

class AppConfig {
  /// عنوان الـAPI.
  ///
  /// كان الافتراضي يشير إلى نشرٍ قديم على DigitalOcean لم يعد يعمل، فأي بناء
  /// بلا `--dart-define` كان يخرج تطبيقاً لا يتصل بشيء — والسائق يرى «تعذّر
  /// الاتصال بالخادم» ويظنّ العطل في هاتفه.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://shamstores.com/api',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://shamstores.com',
  );
  static const String appName = 'Shamstores Driver';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// كل كم ثانية يُرفع الموقع.
  ///
  /// التاجر يتتبّع السائق على الخريطة، ونقطةٌ تتحرّك كل دقيقة تبدو معلّقة.
  /// وخمس عشرة ثانية توازن بين وضوح الحركة وبطارية الهاتف.
  static const int locationUpdateInterval = 15;

  /// دورة الاحتياط حين ينقطع السوكِت — لا بديلاً عنه.
  static const int pollIntervalSeconds = 45;
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String orderDetail = '/order-detail';
  static const String tracking = '/tracking';
  static const String earnings = '/earnings';
  static const String profile = '/profile';
}

/// أحداث السوكِت كما يبثّها الخادم في `backend/src/realtime/socket.ts`.
///
/// كان التطبيق يستمع إلى `new_order` و`order_status_updated` — اسمان لا
/// يبثّهما الخادم إطلاقاً. فبقي السائق ينتظر دورة الاستطلاع كاملةً قبل أن
/// يرى طلباً وصل قبل نصف دقيقة، والتطبيق يبدو بطيئاً وهو سليم.
class SocketEvents {
  static const String notification = 'notification:new';
  static const String orderUpdated = 'order:updated';
  static const String dataChanged = 'data:changed';
}

class AppColors {
  static const Color primary = Color(0xFF0F2921);
  static const Color secondary = Color(0xFF1E4D3F);
  static const Color accent = Color(0xFFC8E235);
  static const Color dark = Color(0xFF091612);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textLight = Color(0xFFE8F5E9);
  static const Color textDark = Color(0xFF1A1A1A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color error = Color(0xFFD32F2F);
  static const Color warning = Color(0xFFFFA000);
  static const Color success = Color(0xFF388E3C);
  static const Color info = Color(0xFF1976D2);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF0F4F3);
  static const Color border = Color(0xFFEEEEEE);
  static const Color muted = Color(0xFF9E9E9E);
  static const Color textMuted = Color(0xFF757575);
}

/// حالات الطلب.
///
/// **هذه القائمة تطابق تعداد Prisma حرفاً بحرف** — لا اجتهاد فيها. كانت تحوي
/// `accepted` و`completed` وهما لا وجود لهما في الخادم، وتُسقط `served` وهي
/// موجودة: فيقرأ السائق حالةً بالإنجليزية الخام حين تصله، ويرسل حالةً
/// يرفضها الخادم حين يغيّرها.
class OrderStatusHelper {
  static const List<String> all = [
    'pending',
    'preparing',
    'ready',
    'delivering',
    'delivered',
    'served',
    'cancelled',
  ];

  static String getLabel(String status) {
    const labels = {
      'pending': 'قيد الانتظار',
      'preparing': 'قيد التحضير',
      'ready': 'جاهز للاستلام',
      'delivering': 'في الطريق',
      'delivered': 'تم التسليم',
      'served': 'مكتمل',
      'cancelled': 'ملغي',
    };
    return labels[status] ?? status;
  }

  static Color getColor(String status) {
    const colors = {
      'pending': AppColors.info,
      'preparing': AppColors.warning,
      'ready': AppColors.info,
      'delivering': AppColors.primary,
      'delivered': AppColors.success,
      'served': AppColors.success,
      'cancelled': AppColors.error,
    };
    return colors[status] ?? AppColors.muted;
  }

  static IconData getIcon(String status) {
    const icons = {
      'pending': Icons.schedule,
      'preparing': Icons.restaurant_outlined,
      'ready': Icons.inventory_2_outlined,
      'delivering': Icons.delivery_dining,
      'delivered': Icons.verified_outlined,
      'served': Icons.task_alt,
      'cancelled': Icons.cancel_outlined,
    };
    return icons[status] ?? Icons.info_outline;
  }
}

class PaymentHelper {
  static String label(String method) {
    const labels = {
      'cash': 'نقداً',
      'card': 'بطاقة',
      'online': 'أونلاين',
      'sham_cash': 'شام كاش',
    };
    return labels[method] ?? method;
  }

  static IconData icon(String method) {
    const icons = {
      'cash': Icons.payments_outlined,
      'card': Icons.credit_card,
      'online': Icons.language,
      'sham_cash': Icons.phone_android,
    };
    return icons[method] ?? Icons.payments_outlined;
  }
}
