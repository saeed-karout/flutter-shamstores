// اختبار دخان: يبني التطبيق ويتأكّد أنه يقف على شاشة البداية.
//
// كان الملف قالبَ `flutter create` بحاله — يبني `MyApp` (لا وجود لها، اسم
// الصنف `ShamDeliveryApp`) ويبحث عن عدّادٍ لا مكان له في تطبيق توصيل. فكان
// `flutter analyze` يرسب بخطأ ترجمة، و`flutter test` يفشل دائماً — واختبارٌ
// راسبٌ أبداً يُقرأ ضوضاءً فيُطفأ، ثم لا يبقى اختبار.
//
// نتوقّف عند شاشة البداية عمداً ولا نتجاوزها: ما بعدها يقرأ التخزين ويسأل
// الشبكة، وذلك اختبار تكامل لا اختبار دخان.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sham_delivery/screens/splash_screen.dart';
import 'package:sham_delivery/services/auth_service.dart';
import 'package:sham_delivery/utils/app_theme.dart';
import 'package:sham_delivery/utils/constants.dart';

void main() {
  testWidgets('شاشة البداية تُبنى بلا أخطاء', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthService(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          // الشاشة تنتقل إلى /login بعد ثانيتين؛ وجهةٌ فارغة تكفي — الغرض
          // أن تُبنى شاشة البداية لا أن يُختبر ما بعدها
          routes: {
            AppRoutes.login: (_) => const Scaffold(),
            AppRoutes.home: (_) => const Scaffold(),
          },
          home: const Directionality(
            textDirection: TextDirection.rtl,
            child: SplashScreen(),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(tester.takeException(), isNull);

    // مؤقّت التنقّل يبقى معلّقاً وإلا رسب الاختبار بـ«Pending timers»
    await tester.pump(const Duration(seconds: 3));
  });
}
