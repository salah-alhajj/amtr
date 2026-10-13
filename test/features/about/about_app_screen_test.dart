import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/about/presentation/screens/about_app_screen.dart';
import 'package:mosaed/features/about/presentation/widgets/app_hero_header.dart';
import 'package:mosaed/features/about/presentation/widgets/developer_profile_card.dart';
import 'package:mosaed/features/about/presentation/widgets/feature_highlight_card.dart';
import 'package:mosaed/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mosaed/features/settings/presentation/screens/settings_screen.dart';
import 'package:mosaed/core/widgets/business_drawer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> arStrings;
  late Map<String, String> enStrings;

  setUpAll(() {
    final arFile = File('i18n/ar.json');
    final Map<String, dynamic> arJson = json.decode(arFile.readAsStringSync());
    arStrings = arJson.map((k, v) => MapEntry(k, v.toString()));

    final enFile = File('i18n/en.json');
    final Map<String, dynamic> enJson = json.decode(enFile.readAsStringSync());
    enStrings = enJson.map((k, v) => MapEntry(k, v.toString()));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    LocalizationHelper.setStrings(arStrings, 'ar');
  });

  Widget buildTestableWidget({
    required Widget child,
    Locale locale = const Locale('ar'),
  }) {
    LocalizationHelper.setStrings(
      locale.languageCode == 'ar' ? arStrings : enStrings,
      locale.languageCode,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(create: (_) => LocaleBloc()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        locale: locale,
        home: Directionality(
          textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: child,
        ),
      ),
    );
  }

  group('AboutAppScreen & Developer Feature Tests', () {
    testWidgets('AboutAppScreen renders successfully with hero header, overview, and developer card', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(child: const AboutAppScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // فحص عنوان الصفحة
      expect(find.text('عن التطبيق والمطور'), findsWidgets);

      // فحص ترويسة التطبيق واسمه
      expect(find.byType(AppHeroHeader), findsOneWidget);
      expect(find.text('مساعد'), findsOneWidget);
      expect(find.text('نظام محلي متكامل لإدارة الطلبات، التجميع والشحن'), findsOneWidget);
      expect(find.text('نسخة آمنة ومحلية 100%'), findsOneWidget);

      // فحص بطاقة نبذة عن التطبيق للمستخدم العادي
      expect(find.text('ما هو هذا التطبيق؟'), findsOneWidget);

      // فحص بطاقات المميزات السبع (FeatureHighlightCard)
      expect(find.byType(FeatureHighlightCard), findsNWidgets(7));
      expect(find.text('إدارة الطلبات والمبيعات بكل يسر'), findsOneWidget);
      expect(find.text('تجميع الشحنات وتوفير مصاريف النقل'), findsOneWidget);
      expect(find.text('دليل العملاء ومتابعة الديون'), findsOneWidget);
      expect(find.text('تحويل العملات وأسعار الصرف الحية'), findsOneWidget);
      expect(find.text('فواتير وسندات PDF جاهزة للمشاركة'), findsOneWidget);
      expect(find.text('أمان تام ويعمل 100% بدون إنترنت'), findsOneWidget);
      expect(find.text('نسخ احتياطي واستعادة بلمسة واحدة'), findsOneWidget);

      // فحص بطاقة المطور صلاح الدين الحاج (Salah aldain alhajj)
      expect(find.byType(DeveloperProfileCard), findsOneWidget);
      expect(find.text('صلاح الدين الحاج'), findsOneWidget);
      expect(find.text('Salah aldain alhajj'), findsOneWidget);
      expect(find.text('مطور ومصمم التطبيق (App Creator & Lead Developer)'), findsOneWidget);
      expect(find.text('كلمة من المطور'), findsOneWidget);
      expect(find.text('تواصل مع المطور عبر واتساب'), findsOneWidget);
      expect(find.text('مشاركة التطبيق'), findsOneWidget);
      expect(find.text('جولة تعريفية بالمميزات'), findsOneWidget);
    });

    testWidgets('Tapping on interactive tour button opens OnboardingScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(child: const AboutAppScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // التمرير إلى زر جولة تعريفية بالمميزات
      final tourBtn = find.text('جولة تعريفية بالمميزات');
      expect(tourBtn, findsOneWidget);

      await tester.ensureVisible(tourBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(tourBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // التأكد من الانتقال إلى شاشة التعريف OnboardingScreen
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('English translation renders correctly with all non-technical content and developer name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      LocalizationHelper.setStrings(enStrings, 'en');

      await tester.pumpWidget(buildTestableWidget(
        child: const AboutAppScreen(),
        locale: const Locale('en'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('About App & Developer'), findsWidgets);
      expect(find.text('Mosaed'), findsOneWidget);
      expect(find.text('100% Offline & Private'), findsOneWidget);
      expect(find.text('What is this app?'), findsOneWidget);
      expect(find.text('Easy Orders & Sales Management'), findsOneWidget);
      expect(find.text('Smart Cargo Consolidation & Cost Savings'), findsOneWidget);
      expect(find.text('Customer Ledger & Debt Tracking'), findsOneWidget);
      expect(find.text('Salah aldain alhajj'), findsWidgets);
      expect(find.text('App Creator & Lead Developer'), findsOneWidget);
      expect(find.text('Contact Developer on WhatsApp'), findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.text('Interactive Feature Tour'), findsOneWidget);
    });

    testWidgets('SettingsScreen navigates to AboutAppScreen when About card is tapped', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestableWidget(child: const SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final aboutTile = find.text('عن التطبيق والمطور');
      expect(aboutTile, findsOneWidget);

      await tester.ensureVisible(aboutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(aboutTile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(AboutAppScreen), findsOneWidget);
    });

    testWidgets('BusinessDrawer renders About App menu item and triggers navigation callback', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool aboutNavigated = false;

      await tester.pumpWidget(buildTestableWidget(
        child: Scaffold(
          drawer: BusinessDrawer(
            onNavigateAbout: () => aboutNavigated = true,
          ),
          body: const SizedBox(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final scaffoldState = tester.firstState<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final drawerAboutItem = find.text('عن التطبيق والمطور');
      expect(drawerAboutItem, findsOneWidget);

      await tester.ensureVisible(drawerAboutItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      await tester.tap(drawerAboutItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(aboutNavigated, isTrue);
    });
  });
}
