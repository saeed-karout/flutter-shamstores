import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/order_service.dart';
import 'services/location_service.dart';
import 'services/inbox_service.dart';
import 'services/push_service.dart';
import 'services/socket_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/order_detail_screen.dart';
import 'screens/tracking_screen.dart';
import 'utils/app_theme.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // بلا هذا يرمي `DateFormat(..., 'ar')` استثناء LocaleDataException عند أول
  // تاريخ يُعرض — وشاشة السجلّ كلّها تواريخ.
  await initializeDateFormatting('ar');
  // الإشعارات تُهيَّأ قبل runApp: معالج الخلفية يجب أن يُسجَّل
  // قبل أن يوقظ النظام التطبيق برسالة
  await PushService.init();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    // شريط الحالة فوق شريط تطبيق داكن، فأيقوناته فاتحة
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const ShamDeliveryApp());
}

class ShamDeliveryApp extends StatelessWidget {
  const ShamDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => OrderService()),
        ChangeNotifierProvider(create: (_) => LocationService()),
        ChangeNotifierProvider(create: (_) => SocketService()),
        // يشارك عميل `OrderService` نفسه: عنوانٌ واحد ورمزٌ واحد، فلا
        // يبقى صندوق الوارد بلا مصادقة حين يسجّل السائق دخوله
        ChangeNotifierProvider(
          create: (ctx) => InboxService(ctx.read<OrderService>().client),
        ),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        // **الوضع الفاتح دائماً.**
        //
        // `ThemeMode.system` كان يجعل مظهر التطبيق يتبع هاتف السائق: نصفهم
        // يفتحه فاتحاً ونصفهم داكناً، فيصير شكلٌ واحد مستحيلاً وتُختبَر
        // شاشةٌ ويشتكي من رأى غيرها. والألوان في `AppColors` مضبوطة للفاتح
        // أصلاً (بطاقات بيضاء، نصّ داكن)، فالوضع الداكن كان يخلطها.
        theme: AppTheme.lightTheme,
        themeMode: ThemeMode.light,
        locale: const Locale('ar', 'SA'),
        supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        initialRoute: AppRoutes.splash,
        routes: {
          AppRoutes.splash: (_) => const SplashScreen(),
          AppRoutes.login: (_) => const LoginScreen(),
          AppRoutes.home: (_) => const HomeScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == AppRoutes.orderDetail) {
            final orderId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orderId),
            );
          }
          if (settings.name == AppRoutes.tracking) {
            final orderId = settings.arguments as String;
            return MaterialPageRoute(
              builder: (_) => TrackingScreen(orderId: orderId),
            );
          }
          return null;
        },
      ),
    );
  }
}
