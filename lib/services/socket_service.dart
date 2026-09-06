import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../utils/constants.dart';

/// اتصال الزمن الحقيقي بالخادم.
///
/// **العلّة التي كانت هنا:** التطبيق يستمع إلى `new_order` و
/// `order_status_updated`، والخادم يبثّ `notification:new` و`order:updated`.
/// أسماء لا تلتقي، فلا يصل السائق شيءٌ لحظةَ تعيينه — ينتظر دورة الاستطلاع
/// كاملة. والتطبيق يبدو بطيئاً وهو سليم، والخادم يبدو صامتاً وهو يبثّ.
///
/// وكان الاشتراك يُسجَّل في `initState` مباشرةً على الـsocket، فيتكرّر مع كل
/// إعادة بناء للشاشة ويُستدعى المعالج مرّاتٍ لحدث واحد. صار التسجيل هنا،
/// مرّةً واحدة، والشاشات تشترك بدوالّ ردّ.
class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  bool _isConnected = false;
  String? _authHeader;

  /// يُستدعى عند وصول طلب جديد أو تغيّر حالة طلب
  final List<void Function(Map<String, dynamic> data)> _orderListeners = [];

  /// يُستدعى عند إشعار جديد
  final List<void Function(Map<String, dynamic> data)> _notificationListeners = [];

  bool get isConnected => _isConnected;

  void addOrderListener(void Function(Map<String, dynamic>) listener) {
    if (!_orderListeners.contains(listener)) _orderListeners.add(listener);
  }

  void removeOrderListener(void Function(Map<String, dynamic>) listener) {
    _orderListeners.remove(listener);
  }

  void addNotificationListener(void Function(Map<String, dynamic>) listener) {
    if (!_notificationListeners.contains(listener)) _notificationListeners.add(listener);
  }

  void removeNotificationListener(void Function(Map<String, dynamic>) listener) {
    _notificationListeners.remove(listener);
  }

  void setAuthHeader(String authHeader) {
    if (_authHeader == authHeader && _socket != null) return;
    _authHeader = authHeader;
    disconnect();
    connect();
  }

  void connect() {
    if (_authHeader == null) return;
    if (_socket != null) return;

    final token = _authHeader!.replaceFirst('Bearer ', '');

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          // `polling` احتياطاً: بعض شبكات الهاتف في سوريا تقطع WebSocket،
          // وقصرُ النقل عليه كان يعني انقطاعاً صامتاً بلا بديل.
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(9999)
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('Socket connected');
      notifyListeners();
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('Socket disconnected');
      notifyListeners();
    });

    _socket!.onConnectError((data) => debugPrint('Socket connect error: $data'));
    _socket!.onError((data) => debugPrint('Socket error: $data'));

    // الخادم يُلحق السائق بغرفته تلقائياً من الرمز — لا حاجة إلى `join`
    _socket!.on(SocketEvents.orderUpdated, (data) => _dispatch(_orderListeners, data));
    _socket!.on(SocketEvents.notification, (data) {
      _dispatch(_notificationListeners, data);
      // إشعار من نوع طلب يعني قائمةً تغيّرت — نحدّثها بلا انتظار
      final map = _asMap(data);
      if (map != null && map['type'] == 'order') _dispatch(_orderListeners, data);
    });
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.map((k, v) => MapEntry(k.toString(), v));
    return null;
  }

  void _dispatch(
    List<void Function(Map<String, dynamic>)> listeners,
    dynamic data,
  ) {
    final map = _asMap(data) ?? <String, dynamic>{};
    // نسخة من القائمة: مستمعٌ قد يلغي اشتراكه داخل معالجه
    for (final listener in List.of(listeners)) {
      try {
        listener(map);
      } catch (e) {
        debugPrint('Socket listener error: $e');
      }
    }
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }

  @override
  void dispose() {
    _orderListeners.clear();
    _notificationListeners.clear();
    disconnect();
    super.dispose();
  }
}
