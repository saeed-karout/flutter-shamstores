class DeliveryOrder {
  final String id;
  final String orderNumber;
  final String? customerName;
  final String? customerPhone;
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

  DeliveryOrder({
    required this.id,
    required this.orderNumber,
    this.customerName,
    this.customerPhone,
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
  });

  factory DeliveryOrder.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double defaultValue = 0.0]) {
      if (value == null) return defaultValue;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? defaultValue;
    }

    return DeliveryOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      deliveryAddress: json['deliveryAddress'] as String?,
      deliveryLat: parseDouble(json['deliveryLat'], 0.0),
      deliveryLng: parseDouble(json['deliveryLng'], 0.0),
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
      restaurantName: json['restaurantName'] as String? ?? json['restaurant']?['name'] as String?,
      restaurantAddress: json['restaurantAddress'] as String? ?? json['restaurant']?['address'] as String?,
      restaurantLat: parseDouble(json['restaurantLat'] ?? json['restaurant']?['latitude']),
      restaurantLng: parseDouble(json['restaurantLng'] ?? json['restaurant']?['longitude']),
      estimatedDeliveryTime: json['estimatedDeliveryTime'] as String?,
      items: (json['orderItems'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  bool get needsCashCollection => !isPaid && paymentMethod == 'cash';
  bool get isActive => ['accepted', 'preparing', 'ready', 'delivering'].contains(status);
  bool get isCompleted => ['delivered', 'completed'].contains(status);

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
