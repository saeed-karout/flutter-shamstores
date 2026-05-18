import 'package:flutter/material.dart';

class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://shamstores-app-mixd9.ondigitalocean.app/api',
  );
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: 'https://shamstores-app-mixd9.ondigitalocean.app',
  );
  static const String appName = 'Shamstores Driver';
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int locationUpdateInterval = 15; // seconds
}

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
  static const String orderDetail = '/order-detail';
  static const String earnings = '/earnings';
  static const String profile = '/profile';
}

class AppColors {
  static const Color primary = Color(0xFF0F2921); // عميق جداً
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

class OrderStatusHelper {
  static String getLabel(String status) {
    const labels = {
      'pending': 'جديد',
      'accepted': 'مقبول',
      'preparing': 'قيد التحضير',
      'ready': 'جاهز',
      'delivering': 'في الطريق',
      'delivered': 'تم التسليم',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
    };
    return labels[status] ?? status;
  }

  static Color getColor(String status) {
    const colors = {
      'pending': AppColors.info,
      'accepted': AppColors.secondary,
      'preparing': AppColors.warning,
      'ready': AppColors.accent,
      'delivering': AppColors.primary,
      'delivered': AppColors.success,
      'completed': AppColors.success,
      'cancelled': AppColors.error,
    };
    return colors[status] ?? AppColors.muted;
  }

  static IconData getIcon(String status) {
    const icons = {
      'pending': Icons.notifications_outlined,
      'accepted': Icons.check_circle_outline,
      'preparing': Icons.restaurant_outlined,
      'ready': Icons.done_all,
      'delivering': Icons.delivery_dining,
      'delivered': Icons.verified_outlined,
      'completed': Icons.task_alt,
      'cancelled': Icons.cancel_outlined,
    };
    return icons[status] ?? Icons.info_outline;
  }
}
