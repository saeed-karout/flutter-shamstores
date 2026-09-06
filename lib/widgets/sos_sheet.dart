import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/constants.dart';

/// جهة اتصال في الطوارئ
class SupportContact {
  final String key;
  final String label;
  final String hint;
  final String phone;
  final String? whatsapp;

  const SupportContact({
    required this.key,
    required this.label,
    required this.hint,
    required this.phone,
    this.whatsapp,
  });

  factory SupportContact.fromJson(Map<String, dynamic> json) => SupportContact(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        hint: json['hint']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        whatsapp: json['whatsapp']?.toString(),
      );

  bool get isEmergency => key == 'police' || key == 'ambulance' || key == 'fire';
}

/// زرّ الطوارئ ولوحته.
///
/// السائق وحده على الطريق، وقد يقع ما لا يُحلّ من داخل التطبيق: عطل مركبة،
/// عنوان خطأ، زبون عدائي، حادث. فيحتاج **رقماً واحداً بضغطة واحدة** لا أن
/// يبحث في قوائم.
///
/// والترتيب مقصود: المحلّ أولاً — هو أقرب من يعرف الطلب ويستطيع التصرّف —
/// ثم دعم المنصّة، ثم أرقام الطوارئ الرسمية.
class SosSheet extends StatefulWidget {
  final Dio dio;

  const SosSheet({super.key, required this.dio});

  static Future<void> show(BuildContext context, Dio dio) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SosSheet(dio: dio),
    );
  }

  @override
  State<SosSheet> createState() => _SosSheetState();
}

class _SosSheetState extends State<SosSheet> {
  List<SupportContact> _contacts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await widget.dio.get('/delivery/support/contact');
      final data = res.data['data'] ?? res.data;
      final list = (data['contacts'] as List?) ?? [];
      setState(() {
        _contacts = list
            .whereType<Map>()
            .map((e) => SupportContact.fromJson(e.cast<String, dynamic>()))
            .where((c) => c.phone.isNotEmpty)
            .toList();
        _loading = false;
      });
    } catch (e) {
      // أرقام الطوارئ لا تحتاج شبكة — الشبكة هي أوّل ما يسقط في الطوارئ
      setState(() {
        _contacts = const [
          SupportContact(key: 'police', label: 'الشرطة', hint: 'حادث أو اعتداء', phone: '112'),
          SupportContact(key: 'ambulance', label: 'الإسعاف', hint: 'إصابة', phone: '110'),
          SupportContact(key: 'fire', label: 'الإطفاء', hint: 'حريق', phone: '113'),
        ];
        _error = 'تعذّر جلب أرقام المحلّ — أرقام الطوارئ تعمل دائماً';
        _loading = false;
      });
    }
  }

  Future<void> _call(String phone) async {
    await launchUrl(Uri(scheme: 'tel', path: phone));
  }

  Future<void> _whatsapp(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\D'), '');
    await launchUrl(
      Uri.parse('https://wa.me/$cleaned'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, MediaQuery.of(context).padding.bottom + 18),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
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
          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.sos, color: AppColors.error),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب مساعدة',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16.5, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'اضغط للاتصال مباشرةً',
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _error!,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.warning),
              ),
            ),
          ],

          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _contacts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 9),
                itemBuilder: (_, i) => _contactTile(_contacts[i]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _contactTile(SupportContact contact) {
    final color = contact.isEmergency ? AppColors.error : AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: contact.isEmergency ? color.withValues(alpha: 0.3) : AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _call(contact.phone),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: Row(
                  children: [
                    Icon(contact.isEmergency ? Icons.emergency : Icons.phone_in_talk, color: color, size: 21),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contact.label,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (contact.hint.isNotEmpty)
                            Text(
                              contact.hint,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      contact.phone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (contact.whatsapp != null && contact.whatsapp!.isNotEmpty)
            IconButton(
              onPressed: () => _whatsapp(contact.whatsapp!),
              icon: const Icon(Icons.chat, color: AppColors.success),
              tooltip: 'واتساب',
            ),
        ],
      ),
    );
  }
}
