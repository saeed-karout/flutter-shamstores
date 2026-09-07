import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// إشعارٌ في صندوق الوارد
class InboxMessage {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final String? createdAt;

  const InboxMessage({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory InboxMessage.fromJson(Map<String, dynamic> json) => InboxMessage(
        id: json['id']?.toString() ?? '',
        type: json['type']?.toString() ?? 'alert',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        isRead: json['isRead'] == true,
        createdAt: json['createdAt']?.toString(),
      );

  /// بثٌّ إداري — تعليماتُ نوبة أو إعلانُ صيانة، لا حدثَ طلب
  bool get isBroadcast => type == 'admin_broadcast';

  InboxMessage copyWith({bool? isRead}) => InboxMessage(
        id: id,
        type: type,
        title: title,
        message: message,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

/// صندوق وارد السائق.
///
/// **لماذا لا يكفي إشعار الهاتف:** الإشعار يُمسح بمسحة إصبع ولا يعود. ورسالةٌ
/// من الإدارة — تعليماتُ نوبة، عنوانُ مستودع، رقمُ طوارئ — تُقرأ مرّةً
/// وتُنسى. وسائقٌ لم يفتح التطبيق بعد التحديث لا رمز إشعارات له أصلاً، فلا
/// يصله شيء إطلاقاً ما لم يكن ثمّة مكانٌ ينتظره فيه ما فاته.
class InboxService extends ChangeNotifier {
  final Dio _dio;

  InboxService(this._dio);

  List<InboxMessage> _messages = [];
  int _unread = 0;
  bool _loading = false;
  String? _error;

  List<InboxMessage> get messages => _messages;
  int get unread => _unread;
  bool get loading => _loading;
  String? get error => _error;

  Future<void> fetch({bool silent = false}) async {
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final res = await _dio.get('/notifications', queryParameters: {'limit': 50});
      final data = res.data?['data'];
      final list = (data?['items'] ?? data?['notifications']) as List?;

      _messages = (list ?? [])
          .whereType<Map>()
          .map((e) => InboxMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // العدّاد من الخادم لا من طول القائمة: القائمة مرقّمة وقد تُقصّ
      _unread = (data?['unreadCount'] as num?)?.toInt() ??
          _messages.where((m) => !m.isRead).length;
      _error = null;
    } on DioException catch (e) {
      _error = (e.response?.data as Map?)?['error'] as String? ?? 'تعذّر تحميل الإشعارات';
      debugPrint('inbox fetch failed: ' + e.toString());
    } catch (e) {
      _error = 'تعذّر تحميل الإشعارات';
      debugPrint('inbox fetch failed: ' + e.toString());
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// عدّاد وحده — نداء خفيف للجرس، يُستدعى مع كل تحديث للطلبات
  Future<void> refreshUnread() async {
    try {
      final res = await _dio.get('/notifications/unread-count');
      final count = (res.data?['data']?['unreadCount'] as num?)?.toInt();
      if (count != null && count != _unread) {
        _unread = count;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('unread count failed: ' + e.toString());
    }
  }

  /// التعليم متفائل: الواجهة تتغيّر فوراً وتُصحَّح إن فشل الخادم — نقرةٌ
  /// تنتظر الشبكة تُقرأ تطبيقاً بطيئاً
  Future<void> markRead(String id) async {
    final index = _messages.indexWhere((m) => m.id == id);
    if (index == -1 || _messages[index].isRead) return;

    _messages[index] = _messages[index].copyWith(isRead: true);
    if (_unread > 0) _unread -= 1;
    notifyListeners();

    try {
      await _dio.patch('/notifications/' + id + '/read');
    } catch (e) {
      debugPrint('markRead failed: ' + e.toString());
      await refreshUnread();
    }
  }

  Future<void> markAllRead() async {
    if (_unread == 0) return;
    _messages = _messages.map((m) => m.copyWith(isRead: true)).toList();
    _unread = 0;
    notifyListeners();

    try {
      await _dio.patch('/notifications/read-all');
    } catch (e) {
      debugPrint('markAllRead failed: ' + e.toString());
      await refreshUnread();
    }
  }
}
