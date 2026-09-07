import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'order_detail_screen.dart';

/// سجلّ ما انتهى.
///
/// **ما كان هنا:** قائمة `ListTile` عارية تقول «طلب #123» وتاريخاً ومبلغاً،
/// بلا حالة تحميل ولا خطأ ولا تحديث — فالشبكة المنقطعة تظهر «لا توجد طلبات
/// سابقة»، وهو كذبٌ يجعل السائق يظنّ عمله ضاع.
///
/// وفوق ذلك: لم يكن للسائق أين يرى مجموع ما وصّله. الرأس هنا يقوله.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  /// `all` أو حالة بعينها — السائق يبحث عادةً عن طلبٍ مُلغى ليعرف سببه
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchHistory();
    });
  }

  List<DeliveryOrder> _apply(List<DeliveryOrder> all) {
    if (_filter == 'all') return all;
    if (_filter == 'cancelled') {
      return all.where((o) => o.status == 'cancelled').toList();
    }
    return all.where((o) => o.isCompleted).toList();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<OrderService>();
    final orders = _apply(service.history);

    final deliveredCount = service.history.where((o) => o.isCompleted).length;
    final total = service.history
        .where((o) => o.isCompleted)
        .fold<double>(0, (sum, o) => sum + o.total);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل الطلبات'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _summary(deliveredCount, total),
          _filters(),
          Expanded(child: _body(service, orders)),
        ],
      ),
    );
  }

  Widget _summary(int count, double total) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('طلبات مسلَّمة', '$count', Icons.check_circle_outline),
          Container(width: 1, height: 34, color: Colors.white24),
          _summaryItem('قيمة ما وصّلت', Money.format(total), Icons.payments_outlined),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.accent, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontFamily: 'Cairo', color: Colors.white54, fontSize: 10.5),
        ),
      ],
    );
  }

  Widget _filters() {
    const options = {
      'all': 'الكل',
      'delivered': 'مسلَّمة',
      'cancelled': 'ملغاة',
    };

    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: options.entries.map((e) {
          final selected = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: selected,
              onSelected: (_) => setState(() => _filter = e.key),
              labelStyle: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
              selectedColor: AppColors.accent,
              backgroundColor: AppColors.background,
              side: BorderSide.none,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body(OrderService service, List<DeliveryOrder> orders) {
    if (service.historyLoading && service.history.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (service.historyError != null && service.history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              service.historyError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: service.fetchHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: service.fetchHistory,
      child: orders.isEmpty
          ? ListView(
              // الفراغ يبقى قابلاً للسحب، وإلا تعذّر التحديث منه
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                Icon(Icons.history_toggle_off, size: 60, color: AppColors.muted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'لا توجد طلبات في هذا التصنيف',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.muted, fontSize: 14),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: orders.length,
              itemBuilder: (context, index) => _HistoryCard(order: orders[index]),
            ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final DeliveryOrder order;

  const _HistoryCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled';
    final color = cancelled ? AppColors.error : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    cancelled ? Icons.cancel_outlined : Icons.check_circle_outline,
                    color: color,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '#${order.orderNumber}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            OrderStatusHelper.getLabel(order.status),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // من أين استلمه — يميّز طلبات اليوم بعضها عن بعض أكثر
                      // من رقمٍ لا يحفظه أحد
                      Text(
                        order.restaurantName ?? order.customerName ?? 'طلب توصيل',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: AppColors.textDark,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFmt.dateTime(order.createdAt),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  Money.format(order.total),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
