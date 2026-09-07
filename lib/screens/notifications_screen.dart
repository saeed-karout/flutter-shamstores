import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/inbox_service.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

/// صندوق وارد السائق.
///
/// إشعار الهاتف يُمسح بمسحة إصبع ولا يعود. ورسالةٌ من الإدارة — تعليماتُ
/// نوبة، عنوانُ مستودع، إعلانُ صيانة — تُقرأ مرّةً وتُنسى. هنا تبقى.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InboxService>().fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxService>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.accent,
        elevation: 0,
        actions: [
          if (inbox.unread > 0)
            TextButton(
              onPressed: inbox.markAllRead,
              child: const Text(
                'تعليم الكل كمقروء',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.accent),
              ),
            ),
        ],
      ),
      body: _body(inbox),
    );
  }

  Widget _body(InboxService inbox) {
    if (inbox.loading && inbox.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (inbox.error != null && inbox.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 56, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              inbox.error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textMuted, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => inbox.fetch(),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => inbox.fetch(),
      child: inbox.messages.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Icon(Icons.notifications_off_outlined,
                    size: 60, color: AppColors.muted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'لا إشعارات بعد',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'Cairo', color: AppColors.muted, fontSize: 14),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: inbox.messages.length,
              itemBuilder: (context, i) => _MessageCard(
                message: inbox.messages[i],
                onTap: () => inbox.markRead(inbox.messages[i].id),
              ),
            ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final InboxMessage message;
  final VoidCallback onTap;

  const _MessageCard({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // البثّ الإداري يُميَّز: رسالةٌ من الإدارة ليست تحديثَ حالة طلب، والخلط
    // بينهما يجعل السائق يتخطّى كليهما
    final accent = message.isBroadcast ? AppColors.warning : AppColors.info;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        // غير المقروء يُعلَّم بحافّة لا بلونٍ كامل: خلفيةٌ ملوّنة على قائمةٍ
        // طويلة تُتعب العين
        border: message.isRead
            ? null
            : Border.all(color: accent.withValues(alpha: 0.45), width: 1.4),
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    message.isBroadcast ? Icons.campaign_outlined : Icons.notifications_outlined,
                    color: accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              message.title,
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 13.5,
                                fontWeight: message.isRead ? FontWeight.w700 : FontWeight.w900,
                                color: AppColors.textDark,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!message.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6, top: 3),
                              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        message.message,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        DateFmt.relative(message.createdAt),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
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
