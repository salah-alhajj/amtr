import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/about/presentation/screens/about_app_screen.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:mosaed/features/dashboard/presentation/widgets/currency_selector_bar.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/navigation/main_navigation_shell.dart';
import 'package:mosaed/features/navigation/widgets/amtr_bottom_nav_bar.dart';
import 'package:mosaed/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/screens/add_edit_order_screen.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/shipments/presentation/screens/add_edit_shipment_screen.dart';
import 'package:mosaed/features/shipments/presentation/screens/shipments_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// يبني غلاف التطبيق الكامل مع جميع المزودات للاختبار المعزول للشاشات
Widget _buildTestHarness({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('ar'),
  BusinessModeCubit? businessModeCubit,
  LocaleBloc? localeBloc,
  ThemeBloc? themeBloc,
}) {
  final orderRepo = OrderRepositoryImpl();
  final shipmentRepo = ShipmentRepositoryImpl();
  final customerRepo = CustomerRepositoryImpl();
  final productRepo = ProductRepositoryImpl();
  final expenseRepo = ExpenseRepositoryImpl();

  final effectiveLocaleBloc = localeBloc ?? (LocaleBloc()..add(ChangeLocale(locale)));
  final effectiveThemeBloc = themeBloc ?? ThemeBloc();
  final effectiveBusinessCubit =
      businessModeCubit ?? (BusinessModeCubit()..loadFromPreferences());

  return MultiBlocProvider(
    providers: [
      BlocProvider<LocaleBloc>.value(value: effectiveLocaleBloc),
      BlocProvider<ThemeBloc>.value(value: effectiveThemeBloc),
      BlocProvider<BusinessModeCubit>.value(value: effectiveBusinessCubit),
      BlocProvider<CashBoxCubit>(
        create: (_) => CashBoxCubit()..loadDate(DateTime.now()),
      ),
      BlocProvider<DashboardBloc>(
        create: (_) => DashboardBloc(
          orderRepo: orderRepo,
          shipmentRepo: shipmentRepo,
          customerRepo: customerRepo,
          expenseRepo: expenseRepo,
          productRepo: productRepo,
        )..add(const LoadDashboardData()),
      ),
      BlocProvider<OrdersBloc>(
        create: (_) => OrdersBloc(repository: orderRepo)..add(const LoadOrders()),
      ),
      BlocProvider<ShipmentsBloc>(
        create: (_) =>
            ShipmentsBloc(repository: shipmentRepo)..add(const LoadShipments()),
      ),
      BlocProvider<CustomersBloc>(
        create: (_) => CustomersBloc(
          repository: customerRepo,
          orderRepository: orderRepo,
        )..add(const LoadCustomers()),
      ),
      BlocProvider<ProductsBloc>(
        create: (_) =>
            ProductsBloc(repository: productRepo)..add(const LoadProducts()),
      ),
      BlocProvider<ExpensesBloc>(
        create: (_) =>
            ExpensesBloc(repository: expenseRepo)..add(const LoadExpenses()),
      ),
    ],
    child: BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, localeState) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: localeState.locale,
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            AppLocalizationsDelegate(
              arabicDialect: localeState.arabicDialect,
            ),
          ],
          builder: (context, widgetChild) {
            return Directionality(
              textDirection: localeState.textDirection,
              child: widgetChild ?? const SizedBox.shrink(),
            );
          },
          home: child,
        );
      },
    ),
  );
}

Future<void> _pumpReady(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _waitUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 30; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
    await tester.pump();
  }
}

Future<void> _pumpSettledAsync(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

/// يلتقط كافة أخطاء FlutterError (بما في ذلك RenderFlex overflow) أثناء تنفيذ الإجراء
Future<List<FlutterErrorDetails>> _captureFlutterErrors(
  Future<void> Function() body,
) async {
  final errors = <FlutterErrorDetails>[];
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    errors.add(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = originalOnError;
  }
  return errors;
}

void _assertNoFlutterErrors(
  List<FlutterErrorDetails> errors,
  String contextLabel,
) {
  if (errors.isNotEmpty) {
    final summary = errors.map((e) {
      final ctx = e.context?.toDescription() ?? '';
      return '[${e.library ?? "flutter"}] ${e.exceptionAsString()} ($ctx)';
    }).join('\n---\n');
    fail('Captured ${errors.length} FlutterError(s) in $contextLabel:\n$summary');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    LocalJsonLocalization.delegate.directories = ['i18n'];
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');

    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'business_mode': AppConstants.businessModeTradeLogistics,
      'multi_currency_enabled': true,
      'default_currency': AppConstants.currencyYer,
      'locale_code': 'ar',
    });
    await PreferencesService.instance.init();
    await CurrencyService.instance.init();
    await LocalizationHelper.load('ar');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 8,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
  });

  group('1) BusinessModeCubit Live Switching & Tab Index 4 Safety', () {
    testWidgets(
      'Switching between productive_family and trade_logistics on tab index 4 causes no RangeError and updates bottom bar immediately',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await PreferencesService.instance.setBusinessMode(
          AppConstants.businessModeProductiveFamily,
        );
        await LocalizationHelper.load('ar');

        final businessCubit = BusinessModeCubit()..loadFromPreferences();
        addTearDown(businessCubit.close);

        final errors = await _captureFlutterErrors(() async {
          await _pumpReady(
            tester,
            _buildTestHarness(
              businessModeCubit: businessCubit,
              child: const MainNavigationShell(),
            ),
          );

          // التحقق من الشريط السفلي لوضع الأسر المنتجة أولاً
          AmtrBottomNavBar navBar = tester.widget<AmtrBottomNavBar>(
            find.byType(AmtrBottomNavBar),
          );
          expect(navBar.items.length, 5);
          expect(navBar.items[0].label, 'nav_today'.i18n());
          expect(navBar.items[2].label, 'nav_catalog'.i18n());
          expect(navBar.items[3].label, 'nav_cashbox'.i18n());
          expect(navBar.items[4].label, 'nav_customers'.i18n());

          // الانتقال إلى التبويب رقم 4 (الخامس)
          navBar.onItemSelected(4);
          await _pumpSettledAsync(tester);

          navBar = tester.widget<AmtrBottomNavBar>(
            find.byType(AmtrBottomNavBar),
          );
          expect(navBar.selectedIndex, 4);

          // التبديل الحي إلى وضع التجارة والشحنات أثناء الوقوف على التبويب 4
          await businessCubit.updateProfile(
            businessMode: AppConstants.businessModeTradeLogistics,
          );
          await _pumpSettledAsync(tester);

          navBar = tester.widget<AmtrBottomNavBar>(
            find.byType(AmtrBottomNavBar),
          );
          expect(navBar.selectedIndex, 4);
          expect(navBar.items[0].label, 'nav_home'.i18n());
          expect(navBar.items[2].label, 'nav_shipments'.i18n());
          expect(navBar.items[3].label, 'nav_customers'.i18n());
          expect(navBar.items[4].label, 'nav_settings'.i18n());

          // التبديل العكسي الحي إلى وضع الأسر المنتجة أثناء الوقوف على التبويب 4
          await businessCubit.updateProfile(
            businessMode: AppConstants.businessModeProductiveFamily,
          );
          await _pumpSettledAsync(tester);

          navBar = tester.widget<AmtrBottomNavBar>(
            find.byType(AmtrBottomNavBar),
          );
          expect(navBar.selectedIndex, 4);
          expect(navBar.items[0].label, 'nav_today'.i18n());
          expect(navBar.items[2].label, 'nav_catalog'.i18n());
          expect(navBar.items[4].label, 'nav_customers'.i18n());

          // تفريغ أي مؤقتات متبقية
          await tester.pump(const Duration(seconds: 10));
        });

        _assertNoFlutterErrors(errors, 'BusinessModeCubit live switching');
      },
    );
  });

  group('2) Trade & Shipments Screens at 360x740 (Light & Dark)', () {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final themeLabel = themeMode == ThemeMode.light ? 'Light' : 'Dark';

      testWidgets(
        'MainNavigationShell (5 trade tabs) at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeTradeLogistics,
          );
          await PreferencesService.instance.setMultiCurrencyEnabled(true);
          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const MainNavigationShell(),
              ),
            );

            for (var tabIndex = 0; tabIndex < 5; tabIndex++) {
              final navBar = tester.widget<AmtrBottomNavBar>(
                find.byType(AmtrBottomNavBar),
              );
              navBar.onItemSelected(tabIndex);
              await _pumpSettledAsync(tester);
            }
          });

          _assertNoFlutterErrors(
            errors,
            'MainNavigationShell 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'HomeDashboardScreen + CurrencySelectorBar (YER, SAR, USD) at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeTradeLogistics,
          );
          await PreferencesService.instance.setMultiCurrencyEnabled(true);
          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const HomeDashboardScreen(),
              ),
            );

            await _waitUntilFound(tester, find.byType(CurrencySelectorBar));
            expect(find.byType(CurrencySelectorBar), findsOneWidget);

            // النقر على العملات الثلاث
            for (final key in ['currency_sar', 'currency_usd', 'currency_yer']) {
              final finder = find.text(key.i18n());
              expect(finder, findsOneWidget);
              await tester.tap(finder);
              await _pumpSettledAsync(tester);
            }
          });

          _assertNoFlutterErrors(
            errors,
            'HomeDashboardScreen + CurrencySelectorBar 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'ShipmentsListScreen at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const ShipmentsListScreen(),
              ),
            );
          });

          _assertNoFlutterErrors(
            errors,
            'ShipmentsListScreen 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'AddEditShipmentScreen at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const AddEditShipmentScreen(),
              ),
            );

            await _waitUntilFound(tester, find.byType(Form));
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              await tester.drag(scrollables.first, const Offset(0, -400));
              await tester.pump(const Duration(milliseconds: 200));
            }
            await tester.pump(const Duration(seconds: 10));
          });

          _assertNoFlutterErrors(
            errors,
            'AddEditShipmentScreen 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'AddEditOrderScreen (full form) at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeTradeLogistics,
          );
          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const AddEditOrderScreen(),
              ),
            );

            // تمرير النموذج الكامل للتحقق من عدم وجود Overflow في أي قسم
            final scrollable = find.byType(Scrollable).first;
            for (var i = 0; i < 4; i++) {
              await tester.drag(scrollable, const Offset(0, -450));
              await tester.pump(const Duration(milliseconds: 150));
            }
          });

          _assertNoFlutterErrors(
            errors,
            'AddEditOrderScreen 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'AboutAppScreen at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const AboutAppScreen(),
              ),
            );

            final scrollable = find.byType(Scrollable).first;
            await tester.drag(scrollable, const Offset(0, -400));
            await tester.pump(const Duration(milliseconds: 200));
          });

          _assertNoFlutterErrors(
            errors,
            'AboutAppScreen 360x740 [$themeLabel]',
          );
        },
      );

      testWidgets(
        'OnboardingScreen at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await LocalizationHelper.load('ar');

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                themeMode: themeMode,
                child: const OnboardingScreen(isFromSettings: true),
              ),
            );

            // التحقق من عدم وجود Overflow في الصفحة الأولى والصفحة التالية
            final pageView = find.byType(PageView);
            if (pageView.evaluate().isNotEmpty) {
              await tester.drag(pageView, const Offset(-300, 0));
              await tester.pump(const Duration(milliseconds: 350));
            }
          });

          _assertNoFlutterErrors(
            errors,
            'OnboardingScreen 360x740 [$themeLabel]',
          );
        },
      );
    }
  });

  group('3) Forensic i18n Audit Across lib/ and i18n/{ar,en,tr,fr,es}.json', () {
    test(
      'All .i18n() and .trParams() keys exist in all 5 locales, placeholders match trParams, en.json has no Arabic, ar.json uses SAMA symbol instead of ر.س',
      () async {
        const locales = ['ar', 'en', 'tr', 'fr', 'es'];
        final Map<String, Map<String, String>> translations = {};

        for (final lang in locales) {
          final file = File('i18n/$lang.json');
          expect(file.existsSync(), isTrue, reason: 'Missing i18n/$lang.json');
          final decoded = json.decode(await file.readAsString()) as Map<String, dynamic>;
          translations[lang] = decoded.map(
            (key, value) => MapEntry(key, value.toString()),
          );
        }

        // مسح جميع ملفات lib/**/*.dart
        final libDir = Directory('lib');
        final dartFiles = libDir
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .toList();

        final i18nPattern = RegExp(r'''['"]([a-zA-Z0-9_.-]+)['"]\s*\.i18n\(''');
        final trParamsPattern = RegExp(r'''['"]([a-zA-Z0-9_.-]+)['"]\s*\.trParams\(''');

        final Set<String> i18nKeys = {};
        final Set<String> trParamsKeys = {};
        final List<String> i18nCallSitesWithPlaceholders = [];
        final Map<String, Set<String>> missingKeysByLocale = {
          for (final l in locales) l: <String>{},
        };

        final placeholderRegex = RegExp(r'\{[a-zA-Z0-9_]+\}');

        for (final file in dartFiles) {
          final content = await file.readAsString();
          for (final match in i18nPattern.allMatches(content)) {
            final key = match.group(1)!;
            i18nKeys.add(key);

            // التحقق من عدم استدعاء مفتاح يحتوي {placeholder} عبر .i18n() بدون .trParams()
            final arVal = translations['ar']?[key];
            if (arVal != null && placeholderRegex.hasMatch(arVal)) {
              i18nCallSitesWithPlaceholders.add('${file.path}: "$key" -> "$arVal"');
            }
          }
          for (final match in trParamsPattern.allMatches(content)) {
            final key = match.group(1)!;
            trParamsKeys.add(key);
          }
        }

        final allUsedKeys = {...i18nKeys, ...trParamsKeys};
        expect(allUsedKeys, isNotEmpty, reason: 'No i18n keys found in lib/');

        for (final key in allUsedKeys) {
          for (final lang in locales) {
            if (!translations[lang]!.containsKey(key)) {
              missingKeysByLocale[lang]!.add(key);
            }
          }
        }

        // 1. التحقق من وجود كل مفتاح في اللغات الخمس
        final missingReport = StringBuffer();
        missingKeysByLocale.forEach((lang, keys) {
          if (keys.isNotEmpty) {
            missingReport.writeln('$lang.json missing (${keys.length}): ${keys.join(', ')}');
          }
        });
        expect(
          missingReport.isEmpty,
          isTrue,
          reason: 'Missing translation keys:\n$missingReport',
        );

        // 2. التحقق من عدم استدعاء مفاتيح {placeholder} عبر .i18n()
        expect(
          i18nCallSitesWithPlaceholders,
          isEmpty,
          reason:
              'Keys containing {placeholder} called with .i18n() instead of .trParams():\n${i18nCallSitesWithPlaceholders.join('\n')}',
        );

        // 3. التحقق من خلو en.json من أي حرف عربي
        final arabicCharRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]');
        final arabicInEn = <String>[];
        translations['en']!.forEach((key, value) {
          if (arabicCharRegex.hasMatch(value)) {
            arabicInEn.add('$key: $value');
          }
        });
        expect(
          arabicInEn,
          isEmpty,
          reason: 'Arabic characters found in en.json:\n${arabicInEn.join('\n')}',
        );

        // 4. التحقق من خلو ar.json من "ر.س" واستخدام رمز البنك المركزي السعودي ⃁
        final oldSarInAr = <String>[];
        translations['ar']!.forEach((key, value) {
          if (value.contains('ر.س')) {
            oldSarInAr.add('$key: $value');
          }
        });
        expect(
          oldSarInAr,
          isEmpty,
          reason: 'Legacy "ر.س" found in ar.json (use ⃁ instead):\n${oldSarInAr.join('\n')}',
        );
        expect(
          translations['ar']!.values.any((v) => v.contains('\u20C1')),
          isTrue,
          reason: 'Expected SAMA symbol ⃁ (U+20C1) in ar.json',
        );
      },
    );
  });

  group('4) RTL (Arabic) vs LTR (English) Overflow Check at 360x740', () {
    for (final lang in ['ar', 'en']) {
      final dirLabel = lang == 'ar' ? 'RTL (ar)' : 'LTR (en)';

      testWidgets(
        'MainNavigationShell renders cleanly in $dirLabel at 360x740',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeTradeLogistics,
          );
          await PreferencesService.instance.setMultiCurrencyEnabled(true);
          await PreferencesService.instance.setLocaleCode(lang);
          await tester.runAsync(() => LocalizationHelper.load(lang));

          final localeBloc = LocaleBloc()..add(const LoadPersistedLocale());
          addTearDown(localeBloc.close);

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                locale: Locale(lang),
                localeBloc: localeBloc,
                child: const MainNavigationShell(),
              ),
            );

            for (var tabIndex = 0; tabIndex < 5; tabIndex++) {
              final navBar = tester.widget<AmtrBottomNavBar>(
                find.byType(AmtrBottomNavBar),
              );
              navBar.onItemSelected(tabIndex);
              await _pumpSettledAsync(tester);
            }
          });

          _assertNoFlutterErrors(errors, 'MainNavigationShell $dirLabel');
        },
      );

      testWidgets(
        'HomeDashboardScreen renders cleanly in $dirLabel at 360x740',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeTradeLogistics,
          );
          await PreferencesService.instance.setMultiCurrencyEnabled(true);
          await PreferencesService.instance.setLocaleCode(lang);
          await tester.runAsync(() => LocalizationHelper.load(lang));

          final localeBloc = LocaleBloc()..add(const LoadPersistedLocale());
          addTearDown(localeBloc.close);

          final errors = await _captureFlutterErrors(() async {
            await _pumpReady(
              tester,
              _buildTestHarness(
                locale: Locale(lang),
                localeBloc: localeBloc,
                child: const HomeDashboardScreen(),
              ),
            );
          });

          _assertNoFlutterErrors(errors, 'HomeDashboardScreen $dirLabel');
        },
      );
    }
  });
}
