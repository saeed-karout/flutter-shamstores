import 'package:characters/characters.dart';

class DeliveryOrder {
  final String id;
  final String orderNumber;
  final String? customerName;
  final String? customerPhone;
  final String? customerAvatar;
  final String? deliveryAddress;
  final double? deliveryLat;
  final double? deliveryLng;
  final String status;
  final double total;
  final double subtotal;
  final double discountAmount;
  final double deliveryFee;
  final String? couponCode;
  final bool isPaid;
  final String paymentMethod;
  final String createdAt;
  final String? notes;
  final String? restaurantName;
  final String? restaurantAddress;
  final double? restaurantLat;
  final double? restaurantLng;
  final String? estimatedDeliveryTime;
  final List<OrderItem> items;

  /// طلبٌ جاهز بلا سائق: يراه كل سائقي النشاط ويسبق إليه أوّلهم
  final bool isAvailable;

  DeliveryOrder({
    required this.id,
    required this.orderNumber,
    this.customerName,
    this.customerPhone,
    this.customerAvatar,
    this.deliveryAddress,
    this.deliveryLat,
    this.deliveryLng,
    required this.status,
    required this.total,
    this.subtotal = 0,
    this.discountAmount = 0,
    this.deliveryFee = 0,
    this.couponCode,
    this.isPaid = false,
    this.paymentMethod = 'cash',
    required this.createdAt,
    this.notes,
    this.restaurantName,
    this.restaurantAddress,
    this.restaurantLat,
    this.restaurantLng,
    this.estimatedDeliveryTime,
    this.items = const [],
    this.isAvailable = false,
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    // الإحداثيات: `null` لا صفر.
    //
    // صفرٌ إحداثيةٌ صحيحة — نقطةٌ في خليج غينيا. فطلبٌ بلا موقع كان يرسم
    // دبوساً هناك ويحسب المسافة بآلاف الكيلومترات، وهو أسوأ من ألّا يُرسم.
    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      final parsed = value is num ? value.toDouble() : double.tryParse(value.toString());
      if (parsed == null || parsed == 0) return null;
      return parsed;
    }

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerAvatar: json['customerAvatar'] as String? ?? json['creator']?['avatarUrl'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryLat: parseNullableDouble(json['deliveryLat']),
      deliveryLng: parseNullableDouble(json['deliveryLng']),
      status: json['status'] as String? ?? 'pending',
      total: parseDouble(json['total']),
      subtotal: parseDouble(json['subtotal']),
      discountAmount: parseDouble(json['discountAmount']),
      deliveryFee: parseDouble(json['deliveryFee']),
      couponCode: json['couponCode'] as String?,
      isPaid: json['isPaid'] is bool ? json['isPaid'] : (json['isPaid']?.toString() == 'true' || json['isPaid']?.toString() == '1'),
      paymentMethod: json['paymentMethod'] as String? ?? 'cash',
      createdAt: json['createdAt'] as String? ?? '',
      notes: json['notes'] as String?,
      restaurantName: json['restaurantName'] as String? ??
          json['restaurant']?['name'] as String? ??
          json['store']?['name'] as String?,
      restaurantAddress: json['restaurantAddress'] as String? ??
          json['restaurant']?['address'] as String? ??
          json['store']?['address'] as String?,
      restaurantLat: parseNullableDouble(
          json['restaurantLat'] ?? json['restaurant']?['latitude'] ?? json['store']?['latitude']),
      restaurantLng: parseNullableDouble(
          json['restaurantLng'] ?? json['restaurant']?['longitude'] ?? json['store']?['longitude']),
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      isAvailable: json['isAvailable'] == true,
      items: (json['orderItems'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get needsCashCollection => !isPaid && paymentMethod == 'cash';

  // الحالات تطابق تعداد Prisma. كانت تذكر `accepted` و`completed` ولا وجود
  // لهما، فيسقط كل طلب من كل تصفية ويرى السائق قوائم فارغة وطلباته موجودة.
  bool get isActive => ['preparing', 'ready', 'delivering'].contains(status);
  bool get isCompleted => ['delivered', 'served'].contains(status);
  bool get isCancelled => status == 'cancelled';

  /// جاهزٌ للاستلام من المحلّ — أوّل ما يبحث عنه السائق في قائمته
  bool get awaitingPickup => status == 'ready';
  bool get onTheWay => status == 'delivering';

  /// أوّل حرف من اسم الزبون — يُرسَم حين لا صورة، بدل أيقونة عامّة واحدة
  /// تتكرّر على كل الطلبات فلا تميّز شيئاً
  String get customerInitial {
    final name = (customerName ?? '').trim();
    return name.isEmpty ? '؟' : name.characters.first;
  }

  bool get hasPickupPoint => restaurantLat != null && restaurantLng != null;
  bool get hasDropPoint => deliveryLat != null && deliveryLng != null;

  String get itemsSummary {
    if (items.isEmpty) return 'لا يوجد أصناف';
    return items.map((i) => '${i.itemName} (x${i.quantity})').join('، ');
  }
}

class OrderItem {
  final String id;
  final String itemName;
  final int quantity;
  final double price;
  final String? size;
  final String? notes;

  OrderItem({
    required this.id,
    required this.itemName,
    required this.quantity,
    required this.price,
    this.size,
    this.notes,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    final menuItem = json['menuItem'] as Map<String, dynamic>?;
    final product = json['product'] as Map<String, dynamic>?;
    final itemData = menuItem ?? product ?? {};

    return OrderItem(
      id: json['id']?.toString() ?? '',
      itemName: itemData['name'] as String? ?? 'صنف',
      quantity: json['quantity'] is int ? json['quantity'] : (int.tryParse(json['quantity']?.toString() ?? '1') ?? 1),
      price: parseDouble(json['price']),
      size: json['size'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

class DriverStats {
  final int todayOrders;
  final int completedOrders;
  final double todayEarnings;
  final double totalEarnings;
  final double rating;
  final bool isOnline;

  DriverStats({
    this.todayOrders = 0,
    this.completedOrders = 0,
    this.todayEarnings = 0,
    this.totalEarnings = 0,
    this.rating = 5.0,
    this.isOnline = false,
  });

  factory DriverStats.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return DriverStats(
      todayOrders: json['todayOrders'] is int ? json['todayOrders'] : (int.tryParse(json['todayOrders']?.toString() ?? '0') ?? 0),
      completedOrders: json['completedOrders'] is int ? json['completedOrders'] : (int.tryParse(json['completedOrders']?.toString() ?? '0') ?? 0),
      todayEarnings: parseDouble(json['todayEarnings']),
      totalEarnings: parseDouble(json['totalEarnings'] ?? json['earnings'] ?? 0),
      rating: parseDouble(json['rating'], 5.0),
      isOnline: json['isOnline'] is bool ? json['isOnline'] : (json['isOnline']?.toString() == 'true'),
    );
  }
}
