import 'package:amtr/core/services/preferences_service.dart';
import 'package:amtr/core/theme/theme.dart';
import 'package:amtr/features/onboarding/data/onboarding_data.dart';
import 'package:amtr/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:amtr/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    LocalizationHelper.setStrings({
      'common_skip': 'تخطي',
      'common_next': 'التالي',
      'common_start': 'ابدأ الآن',
      'onboarding_slide0_badge': 'هوية أمتر',
      'onboarding_slide0_title': 'مرحباً بك في أمتر',
    }, 'ar');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
  });

  test('OnboardingData contains exactly 8 items with slide 0 having no illustration and slide 7 being closing', () {
    expect(OnboardingData.items.length, 8);
    // السلايد 0 يحمل اللوجو وليس فيه illustration
    expect(OnboardingData.items[0].isLogoSlide, isTrue);
    expect(OnboardingData.items[0].imagePath, isNull);

    // السلايدات من 1 إلى 7 تشمل illustrations
    for (int i = 1; i <= 7; i++) {
      expect(OnboardingData.items[i].imagePath, isNotNull);
      expect(OnboardingData.items[i].imagePath, contains('onboarding_$i'));
    }

    // السلايد 7 هو ختامي
    expect(OnboardingData.items[7].isClosingSlide, isTrue);
  });

  testWidgets('OnboardingScreen renders initial slide 0 correctly with logo and counter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // فحص ظهور العداد 1 / 8
    expect(find.text('1 / 8'), findsOneWidget);
    // فحص شارة السلايد الأول
    expect(find.text('هوية أمتر'), findsOneWidget);
    expect(find.text('مرحباً بك في أمتر'), findsOneWidget);
    // فحص زر تخطي
    expect(find.text('تخطي'), findsOneWidget);
    // فحص زر التالي
    expect(find.text('التالي'), findsOneWidget);
  });

  testWidgets('OnboardingScreen completes and saves preference upon skip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const Directionality(
                      textDirection: TextDirection.rtl,
                      child: OnboardingScreen(isFromSettings: true),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Open'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // الضغط على زر تخطي
    await tester.tap(find.text('تخطي'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    // التحقق من حفظ حالة إكمال الأونبوردينج
    expect(PreferencesService.instance.isOnboardingCompleted(), isTrue);
  });
}
