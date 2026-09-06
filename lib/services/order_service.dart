import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';

class OrderService extends ChangeNotifier {
  List<DeliveryOrder> _orders = [];
  List<DeliveryOrder> _history = [];
  DriverStats _stats = DriverStats();
  bool _isLoading = false;
  String? _error;
  Timer? _pollTimer;

  List<DeliveryOrder> get orders => _orders;
  List<DeliveryOrder> get history => _history;
  List<DeliveryOrder> get activeOrders =>
      _orders.where((o) => o.isActive).toList();
  List<DeliveryOrder> get pendingOrders =>
      _orders.where((o) => o.awaitingPickup).toList();
  List<DeliveryOrder> get onTheWayOrders =>
      _orders.where((o) => o.onTheWay).toList();
  List<DeliveryOrder> get completedOrders =>
      _orders.where((o) => o.isCompleted).toList();
  DriverStats get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  late final Dio _dio;
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

  /// «استلمت الطلب وانطلقت» — لا حالة `accepted` في الخادم، والانتقال
  /// الصحيح من `ready` هو `delivering`.
  Future<bool> acceptOrder(String orderId) async {
    return _updateOrderStatus(orderId, 'delivering');
  }

  Future<bool> updateStatus(String orderId, String status) async {
    return _updateOrderStatus(orderId, status);
  }

  Future<void> fetchHistory() async {
    if (_authHeader == null) return;
    try {
      final res = await _dio.get('/delivery/driver/history');
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
      notifyListeners();
    } catch (e) {
      debugPrint('fetchHistory error: $e');
    }
  }


  Future<bool> markDelivered(String orderId, {File? image}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final order = getOrderById(orderId);
      
      // 1. رفع الإثبات إذا وجد
      if (image != null) {
        final formData = FormData.fromMap({
          'proof': await MultipartFile.fromFile(image.path, filename: 'proof.jpg'),
        });
        await _dio.post('/delivery/orders/$orderId/proof', data: formData);
      }

      // 2. تحديث الحالة إلى "delivered" أولاً لضمان قبول الإكمال
      await _dio.patch('/delivery/orders/$orderId/status', data: {'status': 'delivered'});

      // 3. إذا كان الطلب نقداً، نؤكد المستلم
      if (order != null && order.paymentMethod == 'cash') {
        await _dio.post('/delivery/orders/$orderId/confirm-payment', data: {'paymentMethod': 'cash'});
      }

      // 4. الإكمال النهائي
      final res = await _dio.post('/delivery/orders/$orderId/complete');
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchOrders();
        await fetchStats();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('markDelivered error: $e');
      // محاولة الإكمال البسيط في حال فشل التسلسل المعقد
      try {
        final res = await _dio.patch('/delivery/orders/$orderId/status', data: {'status': 'delivered'});
        return res.data['success'] == true;
      } catch (_) {
        return false;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
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
