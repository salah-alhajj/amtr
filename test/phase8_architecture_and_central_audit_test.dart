import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/audit/audit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/di/app_services.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/audit/presentation/screens/audit_log_screen.dart';
import 'package:mosaed/features/audit/presentation/widgets/audit_diff_comparison_sheet.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/domain/services/order_business_service.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/models/customer.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';

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
      'app_business_name': 'متجر التدقيق',
      'app_default_currency': AppConstants.currencyYer,
      'app_locale_code': 'ar',
      'app_arabic_dialect': ArabicDialect.standardId,
    });
    await PreferencesService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 13,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    AppServices.reset();
    CentralAuditService.instance.overrideRepositoryForTesting(null);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
    await CentralAuditService.instance.repository.deleteAll();
  });

  tearDown(() async {
    await CentralAuditService.instance.repository.deleteAll();
    for (final table in const [
      'payment_transactions',
      'order_items',
      'orders',
      'expenses',
      'products',
      'customers',
    ]) {
      await db.delete(table);
    }
  });

  Widget buildAuditHarness({
    required Widget child,
    ThemeMode themeMode = ThemeMode.light,
  }) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<LocaleBloc>(create: (_) => LocaleBloc()),
        BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeMode,
        locale: const Locale('ar'),
        supportedLocales: AppLocalizationsDelegate.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          AppLocalizationsDelegate(),
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: child,
        ),
      ),
    );
  }

  group('1) Architecture Layer Isolation Guardrails', () {
    test('Presentation layer has zero direct AppDatabase/sqflite imports; pure domain services have zero Flutter/SQLite imports', () async {
      final presentationFiles = Directory('lib/features')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('/presentation/') && f.path.endsWith('.dart'),
          )
          .toList();

      expect(presentationFiles, isNotEmpty);
      for (final file in presentationFiles) {
        final content = await file.readAsString();
        expect(
          content.contains('app_database.dart'),
          isFalse,
          reason: '${file.path} imports app_database.dart directly',
        );
        expect(
          RegExp(r'''import\s+['"]package:sqflite/''').hasMatch(content),
          isFalse,
          reason: '${file.path} imports sqflite directly',
        );
      }

      final pureDomainFiles = [
        ...Directory('lib/core/audit/models')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        ...Directory('lib/core/audit/domain')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        ...Directory('lib/features')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.contains('/domain/services/') &&
                  f.path.endsWith('.dart'),
            ),
      ];

      expect(pureDomainFiles.length, greaterThanOrEqualTo(6));
      for (final file in pureDomainFiles) {
        final content = await file.readAsString();
        expect(
          content.contains('package:flutter/'),
          isFalse,
          reason: '${file.path} must not depend on Flutter UI',
        );
        expect(
          content.contains('app_database.dart') || content.contains('package:sqflite/'),
          isFalse,
          reason: '${file.path} must not depend directly on SQLite',
        );
      }
    });
  });

  group('2) Pure Domain Diff Engine & OrderBusinessService Tests', () {
    test('AuditDiffEngine computes added, removed, modified diffs and numeric deltas accurately', () {
      final before = {
        'name': 'عسل سدر',
        'sellPrice': 10000.0,
        'stockQuantity': 15,
        'notes': 'دفعة أولى',
        'currency': 'YER',
      };
      final after = {
        'name': 'عسل سدر ملكي',
        'sellPrice': 12500.0,
        'stockQuantity': 12,
        'category': 'cat_food',
        'currency': 'YER',
      };

      final diffs = AuditDiffEngine.computeDiff(before, after);
      final byKey = {for (final d in diffs) d.fieldKey: d};

      expect(byKey.containsKey('currency'), isFalse);
      expect(byKey['name']?.changeType, DiffChangeType.modified);
      expect(byKey['sellPrice']?.numericDelta, closeTo(2500.0, 0.001));
      expect(byKey['stockQuantity']?.numericDelta, closeTo(-3.0, 0.001));
      expect(byKey['notes']?.changeType, DiffChangeType.removed);
      expect(byKey['category']?.changeType, DiffChangeType.added);

      expect(
        OrderBusinessService.calculateNetTotal(
          itemsTotal: 5000,
          deliveryFee: 1000,
          discount: 500,
        ),
        5500,
      );
      expect(
        OrderBusinessService.calculateNetTotal(
          itemsTotal: 1000,
          deliveryFee: 0,
          discount: 5000,
        ),
        0,
      );
    });
  });

  group('3) Centralized Audit Persistence, Tamper Detection, v13 Upgrade & Backup', () {
    test('CRUD operations write linked audit trail, detect SQL tampering, and survive v12->v13 upgrade & JSON round-trip', () async {
      // 1. اختبار الترقية v12 -> v13
      final legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 12,
          singleInstance: false,
          onCreate: (d, _) async {
            await AppDatabase.instance.createDBForTesting(d);
            await d.execute('DROP TABLE IF EXISTS audit_logs;');
          },
        ),
      );
      addTearDown(legacyDb.close);
      await AppDatabase.instance.upgradeDBForTesting(legacyDb, 12, 13);
      final tables = await legacyDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='audit_logs'",
      );
      expect(tables, hasLength(1));

      // 2. عمليات حقيقية عبر المستودعات
      final prodRepo = ProductRepositoryImpl();
      final custRepo = CustomerRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final expRepo = ExpenseRepositoryImpl();

      const prodId = 'prod-aud-1';
      final prod = Product(
        id: prodId,
        name: 'قهوة عربية',
        sellPrice: 4000,
        costPrice: 2500,
        stockQuantity: 10,
        trackStock: true,
      );
      await prodRepo.createProduct(prod);
      await prodRepo.updateProduct(
        prod.copyWith(name: 'قهوة عربية فاخرة', sellPrice: 4500),
      );

      final cust = Customer(id: 'cust-aud-1', name: 'سالم العامري');
      await custRepo.saveCustomer(cust);

      final order = IndividualOrder(
        id: 'ord-aud-1',
        orderNumber: '9001',
        customerId: cust.id,
        customerName: cust.name,
        paymentStatus: AppConstants.paymentDebt,
        paidAmount: 0,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi-aud-1',
            orderId: 'ord-aud-1',
            productId: prodId,
            name: 'قهوة عربية فاخرة',
            quantity: 2,
            costPrice: 2500,
            sellPrice: 4500,
            currency: AppConstants.currencyYer,
          ),
        ],
      );
      await orderRepo.saveOrder(order, order.items);
      await orderRepo.updatePaymentStatus(
        order.id,
        AppConstants.paymentPrepaid,
        9000,
      );

      final expense = Expense(
        id: 'exp-aud-1',
        title: 'علب تغليف',
        category: 'exp_cat_packaging',
        amount: 1200,
        currency: AppConstants.currencyYer,
      );
      await expRepo.createExpense(expense);
      await expRepo.deleteExpense(expense.id);

      final auditRepo = AppServices.instance.auditRepository;
      final logs = await auditRepo.queryLogs();
      expect(logs.length, greaterThanOrEqualTo(7));

      final prodHistory = await auditRepo.getEntityHistory(
        AuditEntityType.product,
        prodId,
      );
      expect(prodHistory.length, 2);
      expect(
        prodHistory.last.diffs.any((d) => d.fieldKey == 'sellPrice' && d.numericDelta == 500),
        isTrue,
      );

      final intactReport = await auditRepo.verifyIntegrityChain();
      expect(intactReport.isIntact, isTrue);
      expect(intactReport.verifiedEntries, intactReport.totalEntries);

      // 3. التصدير والاستيراد عبر JSON يحافظان على audit_logs وسلامتها
      final exported = await AppDatabase.instance.exportAllDataToJson();
      expect((exported['audit_logs'] as List).length, logs.length);
      await auditRepo.deleteAll();
      expect(await auditRepo.queryLogs(), isEmpty);
      await AppDatabase.instance.importAllDataFromJson(exported);
      final restoredReport = await auditRepo.verifyIntegrityChain();
      expect(restoredReport.totalEntries, logs.length);
      expect(restoredReport.isIntact, isTrue);

      // 4. كشف التلاعب المتعمد في سجل واحد
      final firstEntry = prodHistory.first;
      await db.update(
        'audit_logs',
        {'afterJson': '{"name":"تم التزوير"}'},
        where: 'id = ?',
        whereArgs: [firstEntry.id],
      );
      final tamperedReport = await auditRepo.verifyIntegrityChain();
      expect(tamperedReport.isIntact, isFalse);
      expect(tamperedReport.tamperedEntryIds, contains(firstEntry.id));
    });
  });

  group('4) Visual Diff & Audit Center UI at 360x740 (Light & Dark)', () {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final modeLabel = themeMode == ThemeMode.dark ? 'Dark' : 'Light';

      testWidgets('AuditLogScreen & AuditDiffComparisonSheet 3 tabs render with ZERO overflow ($modeLabel 360x740)', (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final prodRepo = ProductRepositoryImpl();
        late AuditEntry sampleEntry;

        await tester.runAsync(() async {
          await LocalizationHelper.load('ar', arabicDialect: ArabicDialect.standardId);
          final p = Product(
            id: 'prod-ui-aud',
            name: 'بخور عدني',
            sellPrice: 6000,
            costPrice: 3500,
            stockQuantity: 8,
            trackStock: true,
          );
          await prodRepo.createProduct(p);
          await prodRepo.updateProduct(
            p.copyWith(name: 'بخور عدني أصلي', sellPrice: 7500, stockQuantity: 12),
          );
          final hist = await AppServices.instance.auditRepository
              .getEntityHistory(AuditEntityType.product, 'prod-ui-aud');
          sampleEntry = hist.last;
        });

        final errors = <FlutterErrorDetails>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (d) => errors.add(d);

        try {
          await tester.pumpWidget(
            buildAuditHarness(
              themeMode: themeMode,
              child: const AuditLogScreen(),
            ),
          );
          for (var i = 0; i < 12; i++) {
            if (find.textContaining('بخور عدني أصلي').evaluate().isNotEmpty) {
              break;
            }
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 30)),
            );
            await tester.pump(const Duration(milliseconds: 50));
          }

          expect(find.text('سجل التدقيق المركزي'), findsOneWidget);
          expect(find.textContaining('بخور عدني أصلي'), findsWidgets);

          // الضغط على زر فحص سلامة السجل
          await tester.tap(find.byIcon(Icons.verified_user_outlined));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 4));

          // فتح ورقة مقارنة الفوارق البصرية بكل تبويباتها الثلاثة
          await tester.pumpWidget(
            buildAuditHarness(
              themeMode: themeMode,
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: AuditDiffComparisonSheet(entry: sampleEntry),
                ),
              ),
            ),
          );
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.text('الفوارق البصرية'), findsOneWidget);
          expect(find.text('قبل / بعد'), findsOneWidget);
          expect(find.text('مقارنة نسختين'), findsOneWidget);

          await tester.tap(find.text('قبل / بعد'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('إظهار الحقول المتغيرة فقط'), findsOneWidget);

          await tester.tap(find.text('مقارنة نسختين'));
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('النسخة الأقدم (قبل)'), findsOneWidget);
        } finally {
          FlutterError.onError = oldOnError;
        }

        expect(
          errors,
          isEmpty,
          reason: errors.map((e) => e.exceptionAsString()).join('\n'),
        );
      });
    }
  });
}
