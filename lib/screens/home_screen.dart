import 'package:flutter/material.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedTab = 0;
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

  Future<void> _initServices() async {
    final authService = context.read<AuthService>();
    final orderService = context.read<OrderService>();
    final locationService = context.read<LocationService>();
    final socketService = context.read<SocketService>();

    if (authService.authHeader != null) {
      orderService.setAuthHeader(authService.authHeader!);
      locationService.setAuthHeader(authService.authHeader!);
      socketService.setAuthHeader(authService.authHeader!);
      socketService.initSocket();

      // Listen for new orders via socket
      socketService.on('new_order', (data) {
        debugPrint('Socket: New order received: $data');
        _playSound(); // تشغيل صوت التنبيه
        orderService.fetchOrders();
        orderService.fetchStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔔 لديك طلب جديد!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
            ),
          );
        }
      });

      // Also listen for status updates (optional but good for real-time)
      socketService.on('order_status_updated', (data) {
        orderService.fetchOrders();
      });
    }

    await orderService.fetchOrders();
    await orderService.fetchStats();
    orderService.startPolling();
  }

  Future<void> _toggleOnlineStatus() async {
    setState(() => _isOnline = !_isOnline);
    final locationService = context.read<LocationService>();
    if (_isOnline) {
      await locationService.startTracking();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('أنت الآن متاح لاستقبال الطلبات'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      await locationService.stopTracking();
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
    _tabController.dispose();
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
          _premiumStatItem('الأرباح', '${stats.todayEarnings} ر.س', Icons.account_balance_wallet_outlined),
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

  const _OrderCard({
    required this.order,
    required this.orderService,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = OrderStatusHelper.getColor(order.status);
    final statusLabel = OrderStatusHelper.getLabel(order.status);

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
                    const SizedBox(height: 16),

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
                      '${order.total.toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary,
                      ),
                    ),
                    const Spacer(),
                    if (order.status == 'ready' || order.status == 'pending')
                      ElevatedButton(
                        onPressed: () => orderService.acceptOrder(order.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('قبول وتوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
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
