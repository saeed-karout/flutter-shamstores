import 'package:intl/intl.dart';

/// تنسيق المبالغ والتواريخ.
///
/// **العملة:** كانت كل شاشة تكتب `ر.س` — الريال السعودي. والمنصّة سورية
/// تسعّر بالليرة، فيقرأ السائق مبلغاً بعملة لا يقبض بها، ويحسب عمولته على
/// رقم يظنّه شيئاً آخر.
///
/// **الكسور:** `toStringAsFixed(2)` على مبلغ بالليرة يعطي «175000.00» —
/// فاصلتان عشريتان لا معنى لهما في عملة أصغر ورقة فيها خمسون. والفواصل
/// الألفية هي ما يجعل الرقم يُقرأ بنظرة.
class Money {
  static final NumberFormat _fmt = NumberFormat('#,##0', 'en');

  static String format(num amount) => '${_fmt.format(amount.round())} ل.س';
}

/// التاريخ بالعربية.
///
/// كان السجلّ يعرض `createdAt` خاماً: «2026-09-06T14:06:42.498Z» — نصٌّ لا
/// يقرأه أحد، ويحمل توقيتاً عالمياً لا توقيت السائق.
class DateFmt {
  static String dateTime(String? iso) {
    final parsed = _parse(iso);
    if (parsed == null) return '';
    return DateFormat('d MMMM yyyy — h:mm a', 'ar').format(parsed);
  }

  static String date(String? iso) {
    final parsed = _parse(iso);
    if (parsed == null) return '';
    return DateFormat('d MMMM yyyy', 'ar').format(parsed);
  }

  static String time(String? iso) {
    final parsed = _parse(iso);
    if (parsed == null) return '';
    return DateFormat('h:mm a', 'ar').format(parsed);
  }

  /// «قبل ٥ دقائق» — أنفع من ساعةٍ مطلقة حين يقرأ السائق طلباً وصل للتوّ
  static String relative(String? iso) {
    final parsed = _parse(iso);
    if (parsed == null) return '';

    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return date(iso);
  }

  static DateTime? _parse(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    // التوقيت يصل عالمياً؛ عرضه بلا تحويل يخطئ بساعتين أو ثلاث
    return DateTime.tryParse(iso)?.toLocal();
  }
}
