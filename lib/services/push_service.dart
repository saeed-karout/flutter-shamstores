import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// إشعارات خارج التطبيق.
///
/// **لماذا لا يكفي السوكِت:** السوكِت يعمل ما دام التطبيق مفتوحاً. والسائق
/// يقفل هاتفه ويضعه في جيبه — عندها يقطع النظام الاتصال ولا يصله شيء. أي
/// أن الطلب يبقى معلّقاً حتى يفتح التطبيق بنفسه ليكتشفه، وهو عكس ما يُراد.
///
/// FCM يوقظ الهاتف من النظام نفسه، فيرنّ التنبيه والشاشة مطفأة.
///
/// **قناة عالية الأولوية بصوت خاص:** إشعارٌ صامت في درج الإشعارات لا يُرى
/// إلا مصادفةً. وطلبُ توصيل يبرد إن لم يُلتقط في دقائقه الأولى.
class PushService {
  static final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// قناة الطلبات — الصوت جزءٌ من تعريفها، ولا يتغيّر بعد إنشائها على
  /// الجهاز. لذلك يحمل المعرّف رقم نسخة: تغييرُ الصوت لاحقاً يحتاج قناةً
  /// جديدة، وإلا بقي الجهاز على القديم بلا سبب ظاهر.
  static const AndroidNotificationChannel _ordersChannel = AndroidNotificationChannel(
    'sham_orders_v2',
    'طلبات التوصيل',
    description: 'تنبيه عند وصول طلب جديد أو تغيّر حالته',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('notification'),
    enableVibration: true,
  );

  static bool _initialized = false;

  /// يُستدعى حين يفتح السائق التطبيق من إشعار.
  ///
  /// بدونه يفتح الإشعار التطبيق على آخر شاشة كان عليها بقائمة قديمة —
  /// فيقرأ «طلب جديد» ولا يجده. الشاشة تسجّل هنا ما تفعله عند الفتح.
  static void Function(Map<String, dynamic> data)? onOpened;

  static void _handleOpen(Map<String, dynamic> data) {
    try {
      onOpened?.call(data);
    } catch (e) {
      debugPrint('onOpened handler failed: $e');
    }
  }

  /// يُستدعى قبل `runApp`
  static Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      const androidInit = AndroidInitializationSettings('@mipmap/logo');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _local.initialize(
        settings: const InitializationSettings(android: androidInit, iOS: iosInit),
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null) return;
          try {
            _handleOpen(Map<String, dynamic>.from(jsonDecode(payload) as Map));
          } catch (_) {
            _handleOpen(const {});
          }
        },
      );

      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_ordersChannel);

      // أندرويد ١٣ فما فوق يمنع الإشعارات حتى يأذن المستخدم صراحةً
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);

      // الرسالة الواردة والتطبيق مفتوح لا يعرضها النظام تلقائياً — نعرضها
      // بأنفسنا، وإلا بدا التطبيق صامتاً وهو يستقبل
      FirebaseMessaging.onMessage.listen(_showForeground);

      FirebaseMessaging.onBackgroundMessage(_backgroundHandler);

      // التطبيق في الخلفية والسائق ضغط الإشعار
      FirebaseMessaging.onMessageOpenedApp.listen(
        (message) => _handleOpen(Map<String, dynamic>.from(message.data)),
      );

      // التطبيق كان مقفلاً تماماً: الرسالة التي أقلعته تُقرأ مرّةً واحدة
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        _handleOpen(Map<String, dynamic>.from(initial.data));
      }

      _initialized = true;
      debugPrint('PushService initialized');
    } catch (e) {
      // غياب Firebase لا يجوز أن يمنع التطبيق من الإقلاع: السائق يعمل
      // بالسوكِت والاستطلاع، والإشعار تحسينٌ لا شرط
      debugPrint('PushService init failed: $e');
    }
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if (title == null && body == null) return;

    await _local.show(
      id: message.hashCode,
      title: title ?? 'شام ستورز',
      body: body ?? '',
      payload: jsonEncode(message.data),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _ordersChannel.id,
          _ordersChannel.name,
          channelDescription: _ordersChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          sound: const RawResourceAndroidNotificationSound('notification'),
          playSound: true,
          enableVibration: true,
          styleInformation: BigTextStyleInformation(body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
    );
  }

  /// الرمز الحالي — يُسجَّل عند كل إقلاع لا مرّةً واحدة.
  ///
  /// يتغيّر مع إعادة التثبيت ومسح البيانات والتدوير الدوري من Firebase.
  /// ورمزٌ ميّت عند الخادم يعني إشعاراً يصمت بلا أن يلاحظ أحد.
  static Future<void> registerToken(Dio dio) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await dio.post('/delivery/driver/fcm-token', data: {'fcmToken': token});
      debugPrint('FCM token registered');

      FirebaseMessaging.instance.onTokenRefresh.listen((fresh) async {
        try {
          await dio.post('/delivery/driver/fcm-token', data: {'fcmToken': fresh});
        } catch (e) {
          debugPrint('FCM refresh register failed: $e');
        }
      });
    } catch (e) {
      debugPrint('registerToken failed: $e');
    }
  }

  /// إبطال الرمز عند الخروج: هاتفٌ سلّمه السائق لغيره لا تصله إشعارات طلبات
  static Future<void> unregisterToken(Dio dio) async {
    try {
      await dio.post('/delivery/driver/fcm-token', data: {'fcmToken': null});
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      debugPrint('unregisterToken failed: $e');
    }
  }
}

/// معالج الخلفية **يجب** أن يكون دالّة عليا مُعلَّمة — يعمل في عزلة Dart
/// منفصلة لا ترى حالة التطبيق.
@pragma('vm:entry-point')
Future<void> _backgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');
}
