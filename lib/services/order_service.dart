import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';

class OrderService extends ChangeNotifier {
  List<DeliveryOrder> _orders = [];
  List<DeliveryOrder> _history = [];
  bool _historyLoading = false;
  String? _historyError;
  DriverStats _stats = DriverStats();
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;

  List<DeliveryOrder> get orders => _orders;
  List<DeliveryOrder> get history => _history;
  List<DeliveryOrder> get activeOrders =>
      _orders.where((o) => o.isActive).toList();
  /// الجاهزة المعيَّنة له
  List<DeliveryOrder> get pendingOrders =>
      _orders.where((o) => o.awaitingPickup && !o.isAvailable).toList();
  /// البركة: جاهزة بلا سائق
  List<DeliveryOrder> get availableOrders =>
      _orders.where((o) => o.isAvailable).toList();
  List<DeliveryOrder> get onTheWayOrders =>
      _orders.where((o) => o.onTheWay).toList();
  /// المكتملة تأتي من السجلّ لا من الطلبات العاملة.
  ///
  /// **العلّة:** التبويب كان يصفّي `_orders` بحثاً عن `delivered` — و`_orders`
  /// يأتي من `/driver/orders` الذي يعيد العاملة وحدها
  /// (`pending|preparing|ready|delivering`). أي أن التبويب كان فارغاً
  /// ببنائه: يصفّي قائمةً لا يمكن أن تحوي مطلوبَه. والسجلّ الحقيقي كان
  /// مدفوناً في شاشةٍ داخل القائمة الجانبية.
  List<DeliveryOrder> get completedOrders => _history;
  DriverStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get historyLoading => _historyLoading;
  String? get historyError => _historyError;

  late final Dio _dio;

  /// عميل HTTP مهيّأ بالعنوان والرمز — تستعمله أوراقٌ صغيرة (الطوارئ مثلاً)
  /// بدل أن تبني عميلاً ثانياً وتكرّر الإعداد
  Dio get client => _dio;
  String? _authHeader;

  OrderService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
    ));
  }

  void setAuthHeader(String authHeader) {
    _authHeader = authHeader;
    _dio.options.headers['Authorization'] = authHeader;
  }

  Future<void> fetchOrders() async {
    if (_authHeader == null) return;
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.get('/delivery/driver/orders');
      final data = res.data;
      final list = data is List ? data : (data['data'] as List? ?? []);
      _orders = list
          .where((e) => e is Map<String, dynamic>)
          .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('Fetched ${_orders.length} orders');
    } on DioException catch (e) {
      _error = (e.response?.data as Map?)?['error'] as String? ?? 'خطأ في تحميل الطلبات';
      debugPrint('OrderService fetchOrders error: ${e.message}');
    } catch (e) {
      _error = 'حدث خطأ غير متوقع';
      debugPrint('OrderService fetchOrders unexpected error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStats() async {
    if (_authHeader == null) return;
    try {
      final res = await _dio.get('/delivery/driver/earnings');
      final data = res.data;
      if (data['success'] == true) {
        _stats = DriverStats.fromJson(data['data'] ?? data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchStats error: $e');
    }
  }

  Future<void> fetchEarnings() async => fetchStats();

  /// قبول الطلب.
  ///
  /// `POST /accept` لا `PATCH /status`: الطلب قد يكون من البركة — جاهزاً بلا
  /// سائق — وتحديث الحالة يشترط أن يكون معيَّناً للسائق أصلاً، فيرتدّ 404.
  /// ومسار القبول يطالب بالطلب ذرّياً فيفصل حين يضغط سائقان معاً.
  Future<String?> acceptOrder(String orderId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.post('/delivery/orders/' + orderId + '/accept');
      if (res.data['success'] == true) {
        await refreshQuietly();
        return null;
      }
      return res.data['error'] as String? ?? 'تعذّر قبول الطلب';
    } on DioException catch (e) {
      // 409 يعني أن سائقاً آخر سبقه — رسالة الخادم أدقّ من أي نصّ عام
      final message = (e.response?.data as Map?)?['error'] as String?;
      debugPrint('acceptOrder error: ' + e.toString());
      return message ?? 'تعذّر قبول الطلب';
    } catch (e) {
      debugPrint('acceptOrder error: ' + e.toString());
      return 'تعذّر قبول الطلب';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateStatus(String orderId, String status) async {
    return _updateOrderStatus(orderId, status);
  }

  /// سجلّ ما انتهى — مسلَّماً كان أو مُلغى.
  ///
  /// `silent` للتحديث الخلفي بعد إتمام طلب: لا يومض مؤشّر تحميل على قائمةٍ
  /// معروضة أصلاً.
  Future<void> fetchHistory({bool silent = false}) async {
    if (_authHeader == null) return;
    if (!silent) {
      _historyLoading = true;
      _historyError = null;
      notifyListeners();
    }
    try {
      final res = await _dio.get('/delivery/driver/history', queryParameters: {'limit': 50});
      final data = res.data;
      // الخادم يردّ `{data: {orders, pagination}}` لا مصفوفةً مباشرة، وقراءته
      // كمصفوفة كانت تعطي `null` دائماً — فيبقى السجلّ فارغاً أبداً.
      final list = data is List
          ? data
          : (data['data']?['orders'] as List? ?? data['data'] as List? ?? []);
      _history = list
          .where((e) => e is Map<String, dynamic>)
          .map((e) => DeliveryOrder.fromJson(e as Map<String, dynamic>))
          .toList();
      _historyError = null;
    } on DioException catch (e) {
      _historyError =
          (e.response?.data as Map?)?['error'] as String? ?? 'تعذّر تحميل السجلّ';
      debugPrint('fetchHistory error: ' + e.toString());
    } catch (e) {
      _historyError = 'تعذّر تحميل السجلّ';
      debugPrint('fetchHistory error: ' + e.toString());
    } finally {
      _historyLoading = false;
      notifyListeners();
    }
  }


  /// تسليم الطلب.
  ///
  /// **الترتيب كان مقلوباً.** كان يضع الحالة `delivered` أوّلاً «لضمان قبول
  /// الإكمال»، ثم يستدعي `/complete` — و`/complete` يشترط `delivering`
  /// فيرتدّ 404. النتيجة: الطلب يصير `delivered` بلا تحصيل مسجَّل، وبلا
  /// `actualDeliveryTime`، وبلا إشعار للزبون، وبلا قيد أرباح للسائق.
  /// والفشل يُبتلع في `catch` فيبدو كل شيء ناجحاً.
  ///
  /// الترتيب الصحيح: إثبات ← تحصيل ← إكمال. و`/complete` هو من ينقل الحالة.
  Future<String?> markDelivered(
    String orderId, {
    File? image,
    String? paymentMethod,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final order = getOrderById(orderId);

      // 1) إثبات التسليم إن صُوّر
      if (image != null) {
        try {
          final formData = FormData.fromMap({
            'proof': await MultipartFile.fromFile(image.path, filename: 'proof.jpg'),
          });
          await _dio.post('/delivery/orders/' + orderId + '/proof', data: formData);
        } catch (e) {
          // صورة لم تُرفع لا تمنع تسليماً وقع فعلاً
          debugPrint('proof upload failed: ' + e.toString());
        }
      }

      // 2) تحصيل المبلغ — قبل الإكمال لأن الخادم يشترطه على الدفع عند الباب
      final needsCollection = order?.needsCashCollection ?? false;
      if (needsCollection) {
        await _dio.post(
          '/delivery/orders/' + orderId + '/confirm-payment',
          data: {'paymentMethod': paymentMethod ?? order?.paymentMethod ?? 'cash'},
        );
      }

      // 3) الإكمال — وهو من ينقل الحالة إلى delivered
      final res = await _dio.post('/delivery/orders/' + orderId + '/complete');
      if (res.data['success'] == true) {
        await refreshQuietly();
        return null;
      }
      return res.data['error'] as String? ?? 'تعذّر إكمال الطلب';
    } on DioException catch (e) {
      final message = (e.response?.data as Map?)?['error'] as String?;
      debugPrint('markDelivered error: ' + e.toString());
      return message ?? 'تعذّر إكمال الطلب — تحقّق من الاتصال';
    } catch (e) {
      debugPrint('markDelivered error: ' + e.toString());
      return 'تعذّر إكمال الطلب';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// تسجيل استلام المبلغ وحده — خطوة مستقلّة قبل التسليم
  Future<String?> collectPayment(String orderId, String paymentMethod) async {
    try {
      final res = await _dio.post(
        '/delivery/orders/' + orderId + '/confirm-payment',
        data: {'paymentMethod': paymentMethod},
      );
      if (res.data['success'] == true) {
        await refreshQuietly();
        return null;
      }
      return res.data['error'] as String? ?? 'تعذّر تسجيل الاستلام';
    } on DioException catch (e) {
      return (e.response?.data as Map?)?['error'] as String? ?? 'تعذّر تسجيل الاستلام';
    } catch (e) {
      return 'تعذّر تسجيل الاستلام';
    }
  }

  Future<bool> reachedRestaurant(String orderId) async {
    try {
      final res = await _dio.post('/delivery/orders/$orderId/reached-restaurant');
      if (res.data['success'] == true) {
        await fetchOrders();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('reachedRestaurant error: $e');
      return false;
    }
  }

  Future<bool> _updateOrderStatus(String orderId, String status) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _dio.patch(
        '/delivery/orders/$orderId/status',
        data: {'status': status},
      );
      if (res.data['success'] == true) {
        // Optimistically update the order locally
        final idx = _orders.indexWhere((o) => o.id == orderId);
        if (idx != -1) {
          _orders[idx] = DeliveryOrder(
            id: _orders[idx].id,
            orderNumber: _orders[idx].orderNumber,
            customerName: _orders[idx].customerName,
            customerPhone: _orders[idx].customerPhone,
            deliveryAddress: _orders[idx].deliveryAddress,
            deliveryLat: _orders[idx].deliveryLat,
            deliveryLng: _orders[idx].deliveryLng,
            status: status,
            total: _orders[idx].total,
            subtotal: _orders[idx].subtotal,
            discountAmount: _orders[idx].discountAmount,
            deliveryFee: _orders[idx].deliveryFee,
            isPaid: _orders[idx].isPaid,
            paymentMethod: _orders[idx].paymentMethod,
            createdAt: _orders[idx].createdAt,
            notes: _orders[idx].notes,
            restaurantName: _orders[idx].restaurantName,
            restaurantAddress: _orders[idx].restaurantAddress,
            restaurantLat: _orders[idx].restaurantLat,
            restaurantLng: _orders[idx].restaurantLng,
            items: _orders[idx].items,
          );
        }
        await fetchOrders();
        await fetchStats();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('updateOrderStatus error: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> confirmPayment(String orderId, String paymentMethod) async {
    try {
      final res = await _dio.post(
        '/delivery/orders/$orderId/confirm-payment',
        data: {'paymentMethod': paymentMethod},
      );
      if (res.data['success'] == true) {
        await fetchOrders();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('confirmPayment error: $e');
      return false;
    }
  }

  Future<bool> rateOrder(String orderId, int stars, String? comment) async {
    try {
      final res = await _dio.post(
        '/delivery/orders/$orderId/rate',
        data: {'stars': stars, 'comment': comment ?? ''},
      );
      return res.data['success'] == true;
    } catch (e) {
      debugPrint('rateOrder error: $e');
      return false;
    }
  }

  DeliveryOrder? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (_) {
      return null;
    }
  }

  /// دورة احتياطية.
  ///
  /// السوكِت هو المصدر الأساسي بعد إصلاح أسماء الأحداث؛ هذه تمسك ما يضيع
  /// حين تنقطع الشبكة أو ينام النظام. لذلك صارت أبطأ: كانت كل ٣٠ ثانية
  /// وهي المصدر الوحيد فعلياً، فتستهلك بطارية السائق طوال نوبته.
  void startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(seconds: AppConfig.pollIntervalSeconds),
      (_) async {
        await fetchOrders();
        await fetchStats();
      },
    );
  }

  /// تحديث فوري يستدعيه السوكِت — بلا شاشة تحميل تقفز أمام السائق
  Future<void> refreshQuietly() async {
    await fetchOrders();
    await fetchStats();
    // السجلّ معه: الطلب الذي يخرج من القائمة العاملة يجب أن يظهر في
    // «المكتملة» فوراً، وإلا بدا وكأنه اختفى
    await fetchHistory(silent: true);
  }

  /// حضور السائق.
  ///
  /// كان الزرّ يشغّل تتبّع الموقع محلياً ولا يخبر الخادم. و
  /// `assignDeliveryDriver` يرفض التعيين لسائق غير متصل (403)، فالسائق
  /// «متاح» على شاشته و«غير متاح» عند التاجر — ولا يصله طلب أبداً.
  Future<bool> setOnline(bool online) async {
    if (_authHeader == null) return false;
    try {
      await _dio.post(online ? '/delivery/driver/online' : '/delivery/driver/offline');
      return true;
    } catch (e) {
      debugPrint('setOnline error: $e');
      return false;
    }
  }

  Future<bool> fetchAvailability() async {
    if (_authHeader == null) return false;
    try {
      final res = await _dio.get('/delivery/driver/availability');
      final data = res.data['data'] ?? res.data;
      return data['isOnline'] == true;
    } catch (e) {
      debugPrint('fetchAvailability error: $e');
      return false;
    }
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
