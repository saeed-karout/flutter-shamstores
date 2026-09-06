import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';
import '../services/location_service.dart';
import '../services/socket_service.dart';
import '../models/order_model.dart';
import '../utils/constants.dart';
import 'order_detail_screen.dart';
import 'history_screen.dart';
import 'earnings_screen.dart';
import '../utils/formatters.dart';
import '../widgets/delivery_map.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  bool _isOnline = false;
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initServices();
  }

  Future<void> _playSound() async {
    try {
      // Check if file exists would be better, but for now just catch error
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('Note: notification.mp3 not found in assets/sounds/');
    }
  }

  /// يقارن عدد الطلبات قبل التحديث وبعده: التنبيه للطلب *الجديد* وحده، فلا
  /// يرنّ في جيب السائق كلّما غيّر هو نفسه حالة طلب.
  void _onRealtimeOrder(Map<String, dynamic> data) async {
    final orderService = context.read<OrderService>();
    final before = orderService.orders.length;
    await orderService.refreshQuietly();
    if (!mounted) return;

    final after = orderService.orders.length;
    if (after > before) {
      _playSound();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔔 لديك طلب جديد'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _initServices() async {
    final authService = context.read<AuthService>();
    final orderService = context.read<OrderService>();
    final locationService = context.read<LocationService>();
    final socketService = context.read<SocketService>();

    if (authService.authHeader != null) {
      orderService.setAuthHeader(authService.authHeader!);
      locationService.setAuthHeader(authService.authHeader!);
      // الاشتراك بدالّة ردّ لا بالحدث مباشرةً: التسجيل على الـsocket في كل
      // بناءٍ للشاشة كان يكرّر المعالج، فيرنّ التنبيه مرّاتٍ لحدثٍ واحد.
      socketService.addOrderListener(_onRealtimeOrder);
      socketService.setAuthHeader(authService.authHeader!);
    }

    await orderService.fetchOrders();
    await orderService.fetchStats();
    // حالة الحضور تأتي من الخادم لا من ذاكرة الشاشة: السائق قد يكون متصلاً
    // من جلسة سابقة، فيفتح التطبيق فيجد الزرّ مطفأً وهو يستقبل طلبات.
    final online = await orderService.fetchAvailability();
    if (mounted && online) {
      setState(() => _isOnline = true);
      await locationService.startTracking();
    }

    orderService.startPolling();
  }

  /// تبديل الحضور.
  ///
  /// **العلّة التي كانت هنا:** الزرّ يشغّل تتبّع الموقع محلياً ولا يخبر
  /// الخادم. و`assignDeliveryDriver` يرفض التعيين لسائق `isOnline = false`
  /// بخطأ 403 — فالسائق «متاح» على شاشته و«غير متاح» عند التاجر، ولا يصله
  /// طلب واحد مهما انتظر.
  /// قبول طلب — من البركة أو من المعيَّن له.
  ///
  /// الخطأ يُعرض للسائق لا يُبتلع: «سبقك سائق آخر» جوابٌ يفهمه، أمّا زرٌّ
  /// يُضغط ولا يحدث شيء فيُقرأ تطبيقاً معطّلاً.
  Future<void> _acceptOrder(DeliveryOrder order) async {
    final error = await context.read<OrderService>().acceptOrder(order.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'الطلب لك الآن — في الطريق'),
        backgroundColor: error == null ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (error == null && mounted) {
      Navigator.pushNamed(context, AppRoutes.tracking, arguments: order.id);
    }
  }

  Future<void> _toggleOnlineStatus() async {
    final next = !_isOnline;
    final orderService = context.read<OrderService>();
    final locationService = context.read<LocationService>();

    setState(() => _isOnline = next);

    final ok = await orderService.setOnline(next);
    if (!mounted) return;

    if (!ok) {
      // لا نترك الزرّ يكذب: فشل الخادم يعيد الحالة كما كانت
      setState(() => _isOnline = !next);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذّر تحديث حالتك — تحقّق من الاتصال'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (next) {
      await locationService.startTracking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أنت الآن متاح لاستقبال الطلبات'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      await locationService.stopTracking();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('أنت خارج الخدمة الآن'),
          backgroundColor: AppColors.textMuted,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700)),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      context.read<OrderService>().stopPolling();
      context.read<LocationService>().stopTracking();
      await context.read<AuthService>().logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  void dispose() {
    // بلا إلغاء الاشتراك يبقى المعالج معلّقاً على خدمةٍ تعيش أطول من الشاشة
    context.read<SocketService>().removeOrderListener(_onRealtimeOrder);
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final orderService = context.watch<OrderService>();
    final locationService = context.watch<LocationService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: AppColors.accent),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'شام ستور',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.accent),
                ),
                Text(
                  authService.user?.name ?? 'مندوب التوصيل',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Connection Status Dot
          _buildOnlineBadge(),
          const SizedBox(width: 10),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: const CircleAvatar(backgroundColor: AppColors.accent, child: Icon(Icons.person, color: AppColors.primary, size: 40)),
              accountName: Text(authService.user?.name ?? 'مندوب التوصيل', style: const TextStyle(fontWeight: FontWeight.bold)),
              accountEmail: Text(authService.user?.phone ?? ''),
              decoration: const BoxDecoration(color: AppColors.primary),
            ),
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('الرئيسية'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('سجل الطلبات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('الأرباح والإحصائيات'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EarningsScreen()));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error)),
              onTap: _logout,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Stats Card
          _buildPremiumStats(orderService.stats),

          // Location status
          if (_isOnline && !locationService.hasPermission)
            _buildLocationWarning(),

          // Tab bar
          Container(
            color: AppColors.white,
            child: TabBar(
              controller: _tabController,
              labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w700, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.muted,
              indicatorColor: AppColors.accent,
              indicatorWeight: 3,
              tabs: [
                Tab(
                  text: 'الجديدة',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined),
                      if (orderService.pendingOrders.isNotEmpty || orderService.orders.any((o) => o.status == 'ready' || o.status == 'pending'))
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Center(
                              child: Text(
                                '${orderService.orders.where((o) => o.status == 'ready' || o.status == 'pending').length}',
                                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Tab(text: 'النشطة', icon: Icon(Icons.delivery_dining)),
                const Tab(text: 'المكتملة', icon: Icon(Icons.task_alt)),
              ],
            ),
          ),

          // Order lists
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOrderList(
                  orderService.orders.where((o) => o.status == 'ready' || o.status == 'pending').toList(),
                  orderService,
                  emptyMsg: 'لا توجد طلبات جاهزة للاستلام'
                ),
                _buildOrderList(orderService.activeOrders, orderService, emptyMsg: 'لا توجد طلبات نشطة'),
                _buildOrderList(orderService.completedOrders, orderService, emptyMsg: 'لا توجد طلبات مكتملة'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineBadge() {
    return Center(
      child: GestureDetector(
        onTap: _toggleOnlineStatus,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isOnline ? AppColors.accent : Colors.white12,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.primary : AppColors.muted,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _isOnline ? 'متاح' : 'غير متصل',
                style: TextStyle(
                  color: _isOnline ? AppColors.primary : Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumStats(DriverStats stats) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _premiumStatItem('اليوم', '${stats.todayOrders}', Icons.shopping_cart_outlined),
          _premiumStatItem('المكتملة', '${stats.completedOrders}', Icons.check_circle_outline),
          _premiumStatItem('الأرباح', Money.format(stats.todayEarnings), Icons.account_balance_wallet_outlined),
          _premiumStatItem('التقييم', '${stats.rating}★', Icons.star_outline),
        ],
      ),
    );
  }

  Widget _premiumStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent.withOpacity(0.8), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildLocationWarning() {
    return Container(
      color: AppColors.warning.withOpacity(0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.location_off, color: AppColors.warning, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'يرجى السماح بالوصول إلى الموقع لتتبعك',
              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<DeliveryOrder> orders, OrderService orderService, {required String emptyMsg}) {
    if (orderService.isLoading && orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: AppColors.muted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              emptyMsg,
              style: const TextStyle(
                fontFamily: 'Cairo',
                color: AppColors.muted,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
        await orderService.fetchOrders();
        await orderService.fetchStats();
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (ctx, i) => _OrderCard(
          order: orders[i],
          orderService: orderService,
          onAccept: () => _acceptOrder(orders[i]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderDetailScreen(orderId: orders[i].id),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final DeliveryOrder order;
  final OrderService orderService;
  final VoidCallback onTap;
  /// القبول يبقى في الشاشة الأمّ: هي من تملك الـcontext لعرض النتيجة
  /// والانتقال إلى التتبّع بعدها
  final VoidCallback onAccept;

  const _OrderCard({
    required this.order,
    required this.orderService,
    required this.onTap,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatusHelper.getColor(order.status);
    final statusLabel = OrderStatusHelper.getLabel(order.status);

    // المسافة من موقع السائق إلى المحلّ — تُحسب هنا لا في الخادم لأنها
    // تتغيّر مع كل خطوة يخطوها
    final position = context.watch<LocationService>().currentPosition;
    final pickupDistance = (position != null && order.hasPickupPoint)
        ? formatDistance(distanceMeters(
            LatLng(position.latitude, position.longitude),
            LatLng(order.restaurantLat!, order.restaurantLng!),
          ))
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          child: Column(
            children: [
              // Top Section: ID and Status
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: AppColors.primary.withOpacity(0.03),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (order.isAvailable) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'متاح للجميع',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Text(
                      '#${order.orderNumber}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),

              // Middle Section: Content
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Items Summary (Names)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 20, color: AppColors.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            order.itemsSummary,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // **من أين يستلم** — أوّل ما يحتاجه السائق قبل أن يتحرّك،
                    // وكان غائباً عن البطاقة كلّياً. والمسافة معه: قرارُ قبول
                    // الطلب يتعلّق ببُعده لا باسمه.
                    if (order.restaurantName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.storefront, size: 18, color: AppColors.warning),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.restaurantName!,
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textDark,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (order.restaurantAddress != null)
                                    Text(
                                      order.restaurantAddress!,
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                            if (pickupDistance != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'يبعد $pickupDistance',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.warning,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Customer and Distance (Placeholder for distance)
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.accent,
                          child: Icon(Icons.person, size: 14, color: AppColors.primary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          order.customerName ?? 'عميل شام ستور',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textDark.withOpacity(0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.error),
                        const SizedBox(width: 4),
                        Text(
                          order.deliveryAddress?.split(',').first ?? 'العنوان غير محدد',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Section: Action or Price
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
                ),
                child: Row(
                  children: [
                    Text(
                      Money.format(order.total),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    // `pending` سقطت: طلبٌ لم يؤكّده التاجر بعد ليس جاهزاً
                    // للاستلام، وعرض زرّ القبول عليه يرسل السائق إلى محلٍّ
                    // لم يبدأ التحضير.
                    if (order.status == 'pending' || order.status == 'preparing')
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              order.status == 'pending' ? Icons.hourglass_top : Icons.restaurant,
                              size: 15,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                // سببُ الانتظار مكتوب: بدونه يظنّ السائق أن
                                // التطبيق لم يستلم الطلب
                                order.status == 'pending'
                                    ? 'بانتظار تأكيد المحلّ'
                                    : 'المحلّ يجهّز الطلب',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (order.status == 'ready')
                      ElevatedButton(
                        onPressed: onAccept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: Text(
                          order.isAvailable ? 'استلم هذا الطلب' : 'قبول وتوصيل',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    else
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
