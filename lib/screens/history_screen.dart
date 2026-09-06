import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<OrderService>().history;

    return Scaffold(
      appBar: AppBar(title: const Text('سجل الطلبات')),
      body: history.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة'))
          : ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final order = history[index];
                return Card(
                  child: ListTile(
                    title: Text('طلب #${order.orderNumber}'),
                    subtitle: Text(DateFmt.dateTime(order.createdAt)),
                    trailing: Text(Money.format(order.total), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () => Navigator.pushNamed(context, AppRoutes.orderDetail, arguments: order.id),
                  ),
                );
              },
            ),
    );
  }
}
