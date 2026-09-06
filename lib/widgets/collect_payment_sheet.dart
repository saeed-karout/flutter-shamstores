import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// ورقة تحصيل المبلغ قبل إتمام التسليم.
///
/// **لماذا خطوة صريحة:** كان التطبيق يستدعي «تأكيد الدفع» في الخلفية بلا أن
/// يسأل السائق. فيضغط «تم التسليم» فيُسجَّل قبضُ مبلغٍ ربّما لم يقبضه — ثم
/// يُحاسَب عليه آخر النوبة. المال لا يُسجَّل بالنيابة عن أحد.
///
/// وهي تُظهر المبلغ كبيراً: السائق يقرأه على الباب ويعدّ الأوراق، لا يفتّش
/// عنه في سطر صغير.
class CollectPaymentSheet extends StatefulWidget {
  final DeliveryOrder order;

  const CollectPaymentSheet({super.key, required this.order});

  /// يعيد طريقة الدفع المؤكَّدة، أو `null` إن تراجع السائق
  static Future<String?> show(BuildContext context, DeliveryOrder order) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectPaymentSheet(order: order),
    );
  }

  @override
  State<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends State<CollectPaymentSheet> {
  late String _method = widget.order.paymentMethod;
  bool _confirmed = false;

  static const _methods = ['cash', 'sham_cash', 'card', 'online'];

  @override
  Widget build(BuildContext context) {
    final order = widget.order;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).viewInsets.bottom + 18),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'استلام المبلغ',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            'من ${order.customerName ?? 'الزبون'} — طلب #${order.orderNumber}',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.textMuted),
          ),

          const SizedBox(height: 18),

          // المبلغ كبير: يُقرأ على الباب لا يُفتَّش عنه
          Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                const Text(
                  'المبلغ المطلوب',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  Money.format(order.total),
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          const Text(
            'كيف دفع؟',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _methods.map((m) {
              final active = _method == m;
              return InkWell(
                onTap: () => setState(() => _method = m),
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.background,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: active ? AppColors.primary : AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PaymentHelper.icon(m),
                        size: 17,
                        color: active ? AppColors.white : AppColors.textMuted,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        PaymentHelper.label(m),
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: active ? AppColors.white : AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // إقرارٌ صريح: توقيعُ السائق على أنه قبض
          InkWell(
            onTap: () => setState(() => _confirmed = !_confirmed),
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: _confirmed ? AppColors.success : AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                    _confirmed ? Icons.check_box : Icons.check_box_outline_blank,
                    color: _confirmed ? AppColors.success : AppColors.muted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'أُقرّ بأنني استلمت ${Money.format(order.total)}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton(
            onPressed: _confirmed ? () => Navigator.pop(context, _method) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              disabledBackgroundColor: AppColors.border,
              foregroundColor: AppColors.white,
              minimumSize: const Size(0, 52),
            ),
            child: const Text('استلمت المبلغ — أتمّ التسليم'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'تراجع',
              style: TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
