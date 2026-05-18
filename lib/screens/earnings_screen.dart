import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../utils/constants.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchEarnings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<OrderService>().stats;

    return Scaffold(
      appBar: AppBar(title: const Text('الأرباح والإحصائيات')),
      body: RefreshIndicator(
        onRefresh: () => context.read<OrderService>().fetchEarnings(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildStatCard('إجمالي الأرباح', '${stats.totalEarnings.toStringAsFixed(2)} ر.س', Icons.account_balance_wallet, Colors.green),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildStatCard('الطلبات المكتملة', stats.completedOrders.toString(), Icons.check_circle, Colors.blue)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildStatCard('طلبات اليوم', stats.todayOrders.toString(), Icons.today, Colors.orange)),
                ],
              ),
              const SizedBox(height: 30),
              const Text('نصائح لزيادة أرباحك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildTip('التزم بمواعيد التوصيل لزيادة تقييمك.'),
              _buildTip('حافظ على نظافة الطرود وابتسامتك مع العملاء.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.3))),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
          const SizedBox(height: 5),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: AppColors.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
