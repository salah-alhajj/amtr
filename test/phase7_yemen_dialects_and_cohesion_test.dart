import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/data_sync_bus.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/customers/presentation/widgets/quick_debt_collection_sheet.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/manufacturing/data/repositories/raw_material_repository.dart';
import 'package:mosaed/features/navigation/main_navigation_shell.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/widgets/quick_order_sheet.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/settings/presentation/screens/settings_screen.dart';
import 'package:mosaed/features/settings/presentation/widgets/language_selector_card.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_ledger_repository.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/widgets/supplier_transaction_sheet.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/raw_material.dart';
import 'package:mosaed/models/supplier.dart';
import 'package:mosaed/models/supplier_transaction.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    SharedPreferences.setMockInitialValues({
      'app_onboarding_completed': true,
      'app_business_mode': AppConstants.businessModeProductiveFamily,
      'app_business_name': 'مطبخ الخير',
      'app_default_currency': AppConstants.currencyYer,
      'app_locale_code': 'ar',
      'app_arabic_dialect': ArabicDialect.standardId,
    });
    await PreferencesService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 12,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    await PreferencesService.instance.setLocaleCode('ar');
    await PreferencesService.instance.setArabicDialect(ArabicDialect.standardId);
    await PreferencesService.instance.setBusinessMode(
      AppConstants.businessModeProductiveFamily,
    );
    await LocalizationHelper.load('ar', arabicDialect: ArabicDialect.standardId);
    for (final table in const [
      'supplier_transactions',
      'raw_materials',
      'suppliers',
      'expenses',
      'payment_transactions',
      'order_items',
      'orders',
      'products',
      'customers',
    ]) {
      await db.delete(table);
    }
  });

  Widget buildHarness({
    required Widget child,
    LocaleBloc? localeBloc,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    final orderRepo = OrderRepositoryImpl();
    final shipmentRepo = ShipmentRepositoryImpl();
    final customerRepo = CustomerRepositoryImpl();
    final productRepo = ProductRepositoryImpl();
    final expenseRepo = ExpenseRepositoryImpl();

    return MultiBlocProvider(
      providers: [
        if (localeBloc != null)
          BlocProvider<LocaleBloc>.value(value: localeBloc)
        else
          BlocProvider<LocaleBloc>(create: (_) => LocaleBloc()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
        BlocProvider<BusinessModeCubit>(
          create: (_) => BusinessModeCubit()..loadFromPreferences(),
        ),
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
            home: Directionality(
              textDirection: localeState.textDirection,
              child: child,
            ),
          );
        },
      ),
    );
  }

  group('1) Multi-Region Yemeni Dialect JSON Overlays Audit', () {
    test('All 4 regional Yemeni dialect files are valid, placeholder-safe, and free of legacy SAR', () async {
      final arMap = (json.decode(await File('i18n/ar.json').readAsString())
              as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));

      final phRegex = RegExp(r'\{[a-zA-Z0-9_]+\}');
      final dialectExpectedTerms = <String, String>{
        'ye_sanaa': 'الزلط',
        'ye_aden': 'البيس',
        'ye_taiz': 'القروش',
        'ye_hadramaut': 'الدراهم',
      };

      final builtDialects = <String, Map<String, String>>{};
      for (final dialect in ArabicDialect.supported) {
        if (dialect.id == ArabicDialect.standardId) {
          expect(dialect.assetPath, isNull);
          continue;
        }
        final file = File(dialect.assetPath!);
        expect(file.existsSync(), isTrue, reason: 'Missing ${dialect.assetPath}');
        final overlay = (json.decode(await file.readAsString())
                as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v.toString()));

        expect(
          overlay.keys.toSet(),
          equals(arMap.keys.toSet()),
          reason: '${dialect.assetPath} must provide 100% full 1:1 coverage of ar.json keys',
        );
        builtDialects[dialect.id] = overlay;

        var adaptedCount = 0;
        for (final entry in overlay.entries) {
          expect(
            entry.value.trim(),
            isNotEmpty,
            reason: '${dialect.assetPath} has empty value for ${entry.key}',
          );
          expect(
            entry.value.contains('  '),
            isFalse,
            reason: '${dialect.assetPath} has double spaces in ${entry.key}',
          );
          expect(
            entry.value.contains('ر.س'),
            isFalse,
            reason: '${dialect.assetPath} contains legacy ر.س in ${entry.key}',
          );
          final expectedPh =
              phRegex.allMatches(arMap[entry.key]!).map((m) => m.group(0)!).toSet();
          final actualPh =
              phRegex.allMatches(entry.value).map((m) => m.group(0)!).toSet();
          expect(
            actualPh,
            equals(expectedPh),
            reason: 'Placeholder mismatch for ${entry.key} in ${dialect.assetPath}',
          );
          if (entry.value != arMap[entry.key]) {
            adaptedCount++;
          }
        }

        expect(
          adaptedCount,
          greaterThanOrEqualTo(350),
          reason: '${dialect.assetPath} should customize broad regional vocabulary ($adaptedCount)',
        );

        final signature = dialectExpectedTerms[dialect.id]!;
        expect(
          overlay.values.any((v) => v.contains(signature)),
          isTrue,
          reason: '${dialect.assetPath} should contain regional term "$signature"',
        );
      }

      // Every pair of regional dialects differs meaningfully across modules
      final dialectIds = builtDialects.keys.toList();
      for (var i = 0; i < dialectIds.length; i++) {
        for (var j = i + 1; j < dialectIds.length; j++) {
          final a = builtDialects[dialectIds[i]]!;
          final b = builtDialects[dialectIds[j]]!;
          final diffCount = arMap.keys.where((k) => a[k] != b[k]).length;
          expect(
            diffCount,
            greaterThanOrEqualTo(250),
            reason: '${dialectIds[i]} vs ${dialectIds[j]} diffCount=$diffCount',
          );
        }
      }
    });

    test('LocaleBloc + LocalizationHelper switch Yemeni dialects live and fall back safely', () async {
      final localeBloc = LocaleBloc();
      addTearDown(localeBloc.close);

      localeBloc.add(const ChangeArabicDialect(ArabicDialect.yeSanaaId));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(localeBloc.state.arabicDialect, ArabicDialect.yeSanaaId);
      expect(PreferencesService.instance.getArabicDialect(), ArabicDialect.yeSanaaId);
      expect('nav_cashbox'.i18n(), contains('الزلط'));
      expect('audit_action_payment'.i18n(), contains('زلط'));
      expect('settings_title'.i18n(), 'الإعدادات');

      localeBloc.add(const ChangeArabicDialect(ArabicDialect.yeAdenId));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect('nav_cashbox'.i18n(), contains('البيس'));
      expect('audit_action_payment'.i18n(), contains('بيس'));

      localeBloc.add(const ChangeLocale(Locale('en')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect('nav_cashbox'.i18n(), 'Cash Box');

      localeBloc.add(const ChangeLocale(Locale('ar')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect('nav_cashbox'.i18n(), contains('البيس'));
    });
  });

  group('2) Supplier Purchase -> Atomic Stock Replenishment', () {
    test('Credit & Cash supplier purchases increment products and raw_materials stock atomically', () async {
      final supplierRepo = SupplierRepositoryImpl();
      final ledgerRepo = SupplierLedgerRepository();
      final productRepo = ProductRepositoryImpl();
      final materialRepo = RawMaterialRepository();
      final expenseRepo = ExpenseRepositoryImpl();

      const supplierId = 'sup-p7-1';
      await supplierRepo.createSupplier(
        Supplier(id: supplierId, name: 'تاجر الجملة'),
      );

      const prodId = 'prod-p7-1';
      await productRepo.createProduct(
        Product(
          id: prodId,
          name: 'عسل سدر',
          sellPrice: 12000,
          costPrice: 8000,
          stockQuantity: 5,
          trackStock: true,
        ),
      );

      const matId = 'mat-p7-1';
      await materialRepo.save(
        RawMaterial(
          id: matId,
          name: 'سكر ناعم',
          unit: 'كيلو',
          unitCost: 1200,
          stockQuantity: 10.0,
        ),
      );

      final domains = <DataDomain>[];
      final sub = DataSyncBus.instance.stream.listen(domains.add);
      addTearDown(sub.cancel);

      // 1. شراء آجل مع إضافة 7 وحدات من المنتج للمخزون
      await ledgerRepo.recordTransaction(
        SupplierTransaction(
          id: 'tx-credit-stock',
          supplierId: supplierId,
          type: AppConstants.supplierTxPurchaseCredit,
          amount: 56000,
          currency: AppConstants.currencyYer,
        ),
        supplierName: 'تاجر الجملة',
        stockItemType: 'product',
        stockItemId: prodId,
        stockQuantity: 7,
      );

      final updatedProd = await productRepo.getProductById(prodId);
      expect(updatedProd?.stockQuantity, 12);
      expect((await expenseRepo.getAllExpenses()), isEmpty);
      expect(domains, contains(DataDomain.products));

      // 2. شراء نقدي مع إضافة 4.5 كيلو مادة خام للمخزون
      await ledgerRepo.recordTransaction(
        SupplierTransaction(
          id: 'tx-cash-stock',
          supplierId: supplierId,
          type: AppConstants.supplierTxPurchaseCash,
          amount: 5400,
          currency: AppConstants.currencyYer,
        ),
        supplierName: 'تاجر الجملة',
        stockItemType: 'material',
        stockItemId: matId,
        stockQuantity: 4.5,
      );

      final updatedMat = await materialRepo.getById(matId);
      expect(updatedMat?.stockQuantity, closeTo(14.5, 0.001));
      expect((await expenseRepo.getAllExpenses()).length, 1);
      expect(domains, contains(DataDomain.materials));
      expect(domains, contains(DataDomain.expenses));
    });
  });

  group('3) Phase 7 UI Cohesion & 360x740 Overflow Checks', () {
    Future<List<FlutterErrorDetails>> trapFlutterErrors(
      Future<void> Function() body,
    ) async {
      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d);
      try {
        await body();
      } finally {
        FlutterError.onError = oldOnError;
      }
      return errors;
    }

    testWidgets('LanguageSelectorCard renders Yemeni dialect selector & switches live at 360x740', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(
        () => LocalizationHelper.load('ar', arabicDialect: ArabicDialect.standardId),
      );
      final localeBloc = LocaleBloc();
      addTearDown(localeBloc.close);

      final errors = await trapFlutterErrors(() async {
        await tester.pumpWidget(
          buildHarness(
            localeBloc: localeBloc,
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [LanguageSelectorCard()],
              ),
            ),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();

        expect(find.text('اللهجة والمسميات البلدية'), findsOneWidget);
        expect(find.text('العربية الفصحى المعاصرة'), findsOneWidget);

        await tester.tap(find.text('العربية الفصحى المعاصرة').last);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        await tester.tap(find.text('اليمنية — تعز والوسط').last);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));

        expect(localeBloc.state.arabicDialect, ArabicDialect.yeTaizId);
        expect('nav_cashbox'.i18n(), contains('القروش'));
      });
      expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
    });

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final modeLabel = themeMode == ThemeMode.dark ? 'Dark' : 'Light';

      testWidgets('HomeDashboardScreen simple_home_seller shows Action-First bar & collapsed analytics ($modeLabel 360x740)', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await PreferencesService.instance.setBusinessMode(
            AppConstants.businessModeSimpleSeller,
          );
          await PreferencesService.instance.setArabicDialect(
            ArabicDialect.yeSanaaId,
          );
          await LocalizationHelper.load('ar', arabicDialect: ArabicDialect.yeSanaaId);
        });
        final localeBloc = LocaleBloc()..add(const LoadPersistedLocale());
        addTearDown(localeBloc.close);

        final errors = await trapFlutterErrors(() async {
          await tester.pumpWidget(
            buildHarness(
              localeBloc: localeBloc,
              themeMode: themeMode,
              child: const HomeDashboardScreen(),
            ),
          );
          final saleLabel = 'home_quick_action_sale'.i18n();
          final expenseLabel = 'home_quick_action_expense'.i18n();
          final collectDebtLabel = 'home_quick_action_collect_debt'.i18n();
          final showAnalyticsLabel = 'home_analytics_show_btn'.i18n();

          for (var i = 0; i < 20; i++) {
            if (find.text(saleLabel).evaluate().isNotEmpty) break;
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
            await tester.pump(const Duration(milliseconds: 80));
          }

          expect(localeBloc.state.arabicDialect, ArabicDialect.yeSanaaId);
          expect(find.text(saleLabel), findsOneWidget);
          expect(find.text(expenseLabel), findsOneWidget);
          expect(find.text(collectDebtLabel), findsOneWidget);
          expect(find.text(showAnalyticsLabel), findsOneWidget);
        });

        expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
      });

      testWidgets('QuickOrderSheet Instant Cash Mode & SupplierTransactionSheet Stock Link render cleanly ($modeLabel 360x740)', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.runAsync(() async {
          await LocalizationHelper.load('ar', arabicDialect: ArabicDialect.standardId);
          await ProductRepositoryImpl().createProduct(
            Product(
              id: 'prod-ui-1',
              name: 'كعك منزلي',
              sellPrice: 2500,
              costPrice: 1200,
              stockQuantity: 10,
              trackStock: true,
            ),
          );
        });

        final errors = await trapFlutterErrors(() async {
          await tester.pumpWidget(
            buildHarness(
              themeMode: themeMode,
              child: const Scaffold(
                body: Column(
                  children: [
                    Expanded(
                      child: QuickOrderSheet(initialInstantCash: true),
                    ),
                  ],
                ),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
            await tester.pump(const Duration(milliseconds: 80));
          }

          expect(find.text('بيع كاش فوري'), findsOneWidget);
          expect(find.text('تأكيد البيع الكاش'), findsOneWidget);

          await tester.pumpWidget(
            buildHarness(
              themeMode: themeMode,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: const [
                      SupplierTransactionSheet(
                        supplierId: 'sup-ui',
                        supplierName: 'مورد الأمل',
                        isPayment: false,
                      ),
                      SizedBox(height: 16),
                      QuickDebtCollectionSheet(),
                    ],
                  ),
                ),
              ),
            ),
          );
          for (var i = 0; i < 5; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
            await tester.pump(const Duration(milliseconds: 80));
          }

          expect(find.text('+5,000'), findsOneWidget);
          expect(find.text('إضافة المشتريات للمخزون تلقائياً'), findsOneWidget);
          expect(find.text('لا توجد ديون معلقة'), findsOneWidget);
        });

        expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
      });
    }

    testWidgets('Live dialect switch updates MainNavigationShell, HomeDashboardScreen & SettingsScreen const cards immediately without freeze', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.runAsync(() async {
        await PreferencesService.instance.setBusinessMode(
          AppConstants.businessModeSimpleSeller,
        );
        await PreferencesService.instance.setArabicDialect(
          ArabicDialect.standardId,
        );
        await LocalizationHelper.load(
          'ar',
          arabicDialect: ArabicDialect.standardId,
          forceReload: true,
        );
      });

      final localeBloc = LocaleBloc();
      addTearDown(localeBloc.close);

      final errors = await trapFlutterErrors(() async {
        await tester.pumpWidget(
          buildHarness(
            localeBloc: localeBloc,
            child: const MainNavigationShell(),
          ),
        );
        for (var i = 0; i < 15; i++) {
          if (find.text('home_quick_action_sale'.i18n()).evaluate().isNotEmpty) {
            break;
          }
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump(const Duration(milliseconds: 60));
        }

        // Standard Arabic initial state
        expect(find.text('nav_cashbox'.i18n()), findsAtLeastNWidgets(1));
        expect(find.text('home_quick_action_sale'.i18n()), findsOneWidget);

        // Switch live across all 4 regional Yemeni dialects and verify both nav shell & HomeDashboardScreen update immediately
        for (final entry in const <MapEntry<String, String>>[
          MapEntry(ArabicDialect.yeSanaaId, 'الزلط'),
          MapEntry(ArabicDialect.yeAdenId, 'البيس'),
          MapEntry(ArabicDialect.yeTaizId, 'القروش'),
          MapEntry(ArabicDialect.yeHadramautId, 'الدراهم'),
        ]) {
          localeBloc.add(ChangeArabicDialect(entry.key));
          for (var i = 0; i < 30 && localeBloc.state.arabicDialect != entry.key; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
            await tester.pump();
          }
          await tester.pump(const Duration(milliseconds: 120));

          expect(localeBloc.state.arabicDialect, entry.key);
          expect('nav_cashbox'.i18n(), contains(entry.value));
          expect(find.text('nav_cashbox'.i18n()), findsAtLeastNWidgets(1));
          expect(find.text('home_quick_action_sale'.i18n()), findsOneWidget);
        }

        // Verify SettingsScreen (including const BusinessProfileCard, ThemeSelectorCard, DemoDataCard) updates live on dialect change
        await tester.pumpWidget(
          buildHarness(
            localeBloc: localeBloc,
            child: const SettingsScreen(),
          ),
        );
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await tester.pump();

        final hadramautProfileTitle = 'business_profile_title'.i18n();
        expect(find.text(hadramautProfileTitle), findsOneWidget);

        localeBloc.add(const ChangeArabicDialect(ArabicDialect.yeSanaaId));
        for (var i = 0; i < 30 && localeBloc.state.arabicDialect != ArabicDialect.yeSanaaId; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
          await tester.pump();
        }
        await tester.pump(const Duration(milliseconds: 100));

        expect(localeBloc.state.arabicDialect, ArabicDialect.yeSanaaId);
        expect(find.text('business_profile_title'.i18n()), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('theme_settings'.i18n()),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('theme_settings'.i18n()), findsOneWidget);

        // Unmount before tearDown to release any active BLoC DB operations cleanly
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      });

      expect(errors, isEmpty, reason: errors.map((e) => e.exceptionAsString()).join('\n'));
    });
  });
}
