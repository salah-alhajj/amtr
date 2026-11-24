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
import 'package:mosaed/core/services/demo_data_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/couriers/data/repositories/courier_repository_impl.dart';
import 'package:mosaed/features/couriers/presentation/bloc/couriers_bloc.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/manufacturing/data/repositories/production_batch_repository.dart';
import 'package:mosaed/features/manufacturing/data/repositories/raw_material_repository.dart';
import 'package:mosaed/features/manufacturing/data/repositories/waste_log_repository.dart';
import 'package:mosaed/features/manufacturing/domain/daily_prep_shopping_service.dart';
import 'package:mosaed/features/manufacturing/presentation/screens/production_batches_screen.dart';
import 'package:mosaed/features/manufacturing/presentation/widgets/record_waste_sheet.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/screens/order_details_screen.dart';
import 'package:mosaed/features/orders/presentation/screens/orders_list_screen.dart';
import 'package:mosaed/features/orders/presentation/widgets/quick_order_sheet.dart';
import 'package:mosaed/features/printing/services/monthly_report_pdf_generator.dart';
import 'package:mosaed/features/products/data/product_bundle_repository.dart';
import 'package:mosaed/features/products/data/product_ingredient_repository.dart';
import 'package:mosaed/features/products/data/product_variant_repository.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/products/presentation/widgets/add_edit_product_sheet.dart';
import 'package:mosaed/features/reports/domain/monthly_insights_service.dart';
import 'package:mosaed/features/reports/presentation/screens/monthly_report_screen.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/bloc/suppliers_bloc.dart';
import 'package:mosaed/features/whatsapp/domain/whatsapp_template_engine.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/product_bundle_item.dart';
import 'package:mosaed/models/product_ingredient.dart';
import 'package:mosaed/models/product_variant.dart';
import 'package:mosaed/models/raw_material.dart';
import 'package:mosaed/models/waste_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _buildPhase6Harness({
  required Widget child,
  ThemeMode themeMode = ThemeMode.light,
  Locale locale = const Locale('ar'),
}) {
  final orderRepo = OrderRepositoryImpl();
  final shipmentRepo = ShipmentRepositoryImpl();
  final customerRepo = CustomerRepositoryImpl();
  final productRepo = ProductRepositoryImpl();
  final expenseRepo = ExpenseRepositoryImpl();
  final supplierRepo = SupplierRepositoryImpl();
  final courierRepo = CourierRepositoryImpl();

  final localeBloc = LocaleBloc()..add(ChangeLocale(locale));
  final themeBloc = ThemeBloc();
  final businessCubit = BusinessModeCubit()..loadFromPreferences();

  return MultiBlocProvider(
    providers: [
      BlocProvider<LocaleBloc>.value(value: localeBloc),
      BlocProvider<ThemeBloc>.value(value: themeBloc),
      BlocProvider<BusinessModeCubit>.value(value: businessCubit),
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
        create: (_) =>
            OrdersBloc(repository: orderRepo)..add(const LoadOrders()),
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
      BlocProvider<SuppliersBloc>(
        create: (_) =>
            SuppliersBloc(repository: supplierRepo)..add(const LoadSuppliers()),
      ),
      BlocProvider<CouriersBloc>(
        create: (_) =>
            CouriersBloc(repository: courierRepo)..add(const LoadCouriers()),
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
          supportedLocales: const [
            Locale('ar'),
            Locale('en'),
            Locale('tr'),
            Locale('fr'),
            Locale('es'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Directionality(
            textDirection: localeState.locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child,
          ),
        );
      },
    ),
  );
}

Future<void> _clearDatabase() async {
  final db = await AppDatabase.instance.database;
  for (final table in const [
    'waste_logs',
    'product_bundle_items',
    'product_variants',
    'production_batches',
    'product_ingredients',
    'manufacturing_template_items',
    'manufacturing_templates',
    'raw_materials',
    'courier_settlements',
    'couriers',
    'supplier_transactions',
    'payment_transactions',
    'order_items',
    'orders',
    'shipments',
    'products',
    'expenses',
    'suppliers',
    'customers',
    'daily_closings',
  ]) {
    await db.delete(table);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    LocalJsonLocalization.delegate.directories = ['i18n'];
    SharedPreferences.setMockInitialValues({
      'app_locale': 'ar',
      'locale_code': 'ar',
      'business_mode': AppConstants.businessModeProductiveFamily,
      'business_name': 'متجر النخبة للأسر المنتجة',
      'business_phone': '+967 777000111',
    });
    await PreferencesService.instance.init();
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    await LocalizationHelper.load('ar');
    await CurrencyService.instance.init();
    await AppDatabase.instance.database;
  });

  tearDown(() async {
    await PreferencesService.instance.setDailyOrderCap(0);
    await _clearDatabase();
  });

  group('Phase 6 — DB v12, Backup Round-Trip & DemoData v12', () {
    test('DB v12 tables/columns exist, JSON round-trips, DemoData seeds & cleans',
        () async {
      final db = await AppDatabase.instance.database;

      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );
      final tableNames = tables.map((r) => r['name'] as String).toSet();
      expect(tableNames, contains('product_variants'));
      expect(tableNames, contains('product_bundle_items'));
      expect(tableNames, contains('waste_logs'));
      expect(tableNames, contains('production_batches'));

      Future<Set<String>> colsOf(String table) async {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        return info.map((r) => r['name'] as String).toSet();
      }

      expect(await colsOf('products'), contains('isBundle'));
      expect(
        await colsOf('order_items'),
        containsAll(['variantId', 'variantName']),
      );
      expect(
        await colsOf('orders'),
        containsAll(['requiresDeposit', 'depositAmount']),
      );
      expect(
        await colsOf('production_batches'),
        containsAll(['batchStatus', 'readyAt', 'expiresAt']),
      );

      // Seed DemoData v12
      final stats = await DemoDataService.instance.generateDemoData();
      expect(stats.hasDemoData, isTrue);

      final demoBundle = await ProductRepositoryImpl().getProductById(
        'demo_prod_bundle_1',
      );
      expect(demoBundle, isNotNull);
      expect(demoBundle!.isBundle, isTrue);

      final demoBundleItems = await ProductBundleRepository().getByBundleId(
        'demo_prod_bundle_1',
      );
      expect(demoBundleItems.length, 2);

      final demoVariants = await ProductVariantRepository().getByProductId(
        'demo_prod_3',
      );
      expect(demoVariants.length, 2);

      final curingBatches = await ProductionBatchRepository().getCuringBatches();
      expect(
        curingBatches.any((b) => b.id == 'demo_batch_curing_1'),
        isTrue,
      );

      final wasteLogs = await WasteLogRepository().getAll();
      expect(wasteLogs.any((w) => w.id == 'demo_waste_1'), isTrue);

      // JSON export / wipe / import round-trip
      final exported = await AppDatabase.instance.exportAllDataToJson();
      expect((exported['product_variants'] as List).length, greaterThanOrEqualTo(2));
      expect(
        (exported['product_bundle_items'] as List).length,
        greaterThanOrEqualTo(2),
      );
      expect((exported['waste_logs'] as List).length, greaterThanOrEqualTo(1));

      await _clearDatabase();
      expect(await ProductVariantRepository().getByProductId('demo_prod_3'), isEmpty);

      await AppDatabase.instance.importAllDataFromJson(exported);
      expect(
        (await ProductVariantRepository().getByProductId('demo_prod_3')).length,
        2,
      );
      expect(
        (await ProductBundleRepository().getByBundleId('demo_prod_bundle_1'))
            .length,
        2,
      );
      expect((await WasteLogRepository().getAll()).length, 1);

      // Clean DemoData v12
      await DemoDataService.instance.removeDemoData();
      expect(await ProductVariantRepository().getByProductId('demo_prod_3'), isEmpty);
      expect(
        await ProductBundleRepository().getByBundleId('demo_prod_bundle_1'),
        isEmpty,
      );
      expect(await WasteLogRepository().getAll(), isEmpty);
      expect(await ProductionBatchRepository().getAllBatches(), isEmpty);
    });
  });

  group('Phase 6 — Variants & Bundles Atomic Stock Lifecycle', () {
    test(
        'Order insert, update delta, and delete atomically adjust variant & bundle component stock',
        () async {
      final prodRepo = ProductRepositoryImpl();
      final varRepo = ProductVariantRepository();
      final bundleRepo = ProductBundleRepository();
      final orderRepo = OrderRepositoryImpl();

      // Product with 2 variants
      final baseProd = Product(
        id: 'p_var_host',
        name: 'عطر مخلط',
        costPrice: 5000,
        sellPrice: 10000,
        stockQuantity: 20,
        trackStock: true,
      );
      await prodRepo.createProduct(baseProd);
      await varRepo.replaceForProduct('p_var_host', [
        const ProductVariant(
          id: 'v_small',
          productId: 'p_var_host',
          variantName: '50 مل',
          sellPrice: 10000,
          stockQuantity: 10,
        ),
        const ProductVariant(
          id: 'v_large',
          productId: 'p_var_host',
          variantName: '100 مل',
          sellPrice: 18000,
          stockQuantity: 5,
        ),
      ]);

      // Bundle with 2 component products
      final compA = Product(
        id: 'p_comp_a',
        name: 'بخور عدني',
        costPrice: 3000,
        sellPrice: 6000,
        stockQuantity: 12,
        trackStock: true,
      );
      final compB = Product(
        id: 'p_comp_b',
        name: 'مبخرة',
        costPrice: 4000,
        sellPrice: 8000,
        stockQuantity: 8,
        trackStock: true,
      );
      final bundleProd = Product(
        id: 'p_bundle_1',
        name: 'باقة الضيافة',
        costPrice: 7000,
        sellPrice: 12000,
        stockQuantity: 0,
        trackStock: false,
        isBundle: true,
      );
      await prodRepo.createProduct(compA);
      await prodRepo.createProduct(compB);
      await prodRepo.createProduct(bundleProd);
      await bundleRepo.replaceForBundle('p_bundle_1', const [
        ProductBundleItem(
          id: 'bi_1',
          bundleProductId: 'p_bundle_1',
          componentProductId: 'p_comp_a',
          componentName: 'بخور عدني',
          quantity: 2,
        ),
        ProductBundleItem(
          id: 'bi_2',
          bundleProductId: 'p_bundle_1',
          componentProductId: 'p_comp_b',
          componentName: 'مبخرة',
          quantity: 1,
        ),
      ]);

      // 1. Insert order: 3x v_small + 2x p_bundle_1
      final order = IndividualOrder(
        id: 'ord_p6_1',
        orderNumber: 'ORD-P6-1',
        customerName: 'عميل تجريبي',
        items: [
          OrderItem(
            id: 'oi_1',
            orderId: 'ord_p6_1',
            productId: 'p_var_host',
            variantId: 'v_small',
            variantName: '50 مل',
            name: 'عطر مخلط',
            quantity: 3,
            costPrice: 5000,
            sellPrice: 10000,
          ),
          OrderItem(
            id: 'oi_2',
            orderId: 'ord_p6_1',
            productId: 'p_bundle_1',
            name: 'باقة الضيافة',
            quantity: 2,
            costPrice: 7000,
            sellPrice: 12000,
          ),
        ],
      );
      await orderRepo.saveOrder(order, order.items);

      var variantsAfterInsert = await varRepo.getByProductId('p_var_host');
      expect(
        variantsAfterInsert.firstWhere((v) => v.id == 'v_small').stockQuantity,
        7, // 10 - 3
      );
      expect(
        (await prodRepo.getProductById('p_comp_a'))!.stockQuantity,
        8, // 12 - (2 * 2)
      );
      expect(
        (await prodRepo.getProductById('p_comp_b'))!.stockQuantity,
        6, // 8 - (2 * 1)
      );

      // 2. Update order: 5x v_small (delta -2) + 1x p_bundle_1 (delta +1 comp)
      final updatedOrder = order.copyWith(
        items: [
          order.items[0].copyWith(quantity: 5),
          order.items[1].copyWith(quantity: 1),
        ],
      );
      await orderRepo.updateOrder(updatedOrder, updatedOrder.items);

      variantsAfterInsert = await varRepo.getByProductId('p_var_host');
      expect(
        variantsAfterInsert.firstWhere((v) => v.id == 'v_small').stockQuantity,
        5, // 10 - 5
      );
      expect(
        (await prodRepo.getProductById('p_comp_a'))!.stockQuantity,
        10, // 12 - (1 * 2)
      );
      expect(
        (await prodRepo.getProductById('p_comp_b'))!.stockQuantity,
        7, // 8 - (1 * 1)
      );

      // 3. Delete order -> restores remaining deducted stock
      await orderRepo.deleteOrder('ord_p6_1');
      final variantsAfterDelete = await varRepo.getByProductId('p_var_host');
      expect(
        variantsAfterDelete.firstWhere((v) => v.id == 'v_small').stockQuantity,
        10,
      );
      expect((await prodRepo.getProductById('p_comp_a'))!.stockQuantity, 12);
      expect((await prodRepo.getProductById('p_comp_b'))!.stockQuantity, 8);
    });
  });

  group('Phase 6 — DailyPrepShoppingService Bundle Explosion & Deposit Gate',
      () {
    test(
        'explodes bundles into components & raw materials and counts awaitingDepositCount',
        () async {
      final prodRepo = ProductRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final ingRepo = ProductIngredientRepository();
      final bundleRepo = ProductBundleRepository();
      final orderRepo = OrderRepositoryImpl();

      final rawMat = RawMaterial(
        id: 'rm_oud',
        name: 'خشب عود',
        unit: 'جم',
        unitCost: 100,
        stockQuantity: 10,
      );
      await matRepo.save(rawMat);

      final compProd = Product(
        id: 'p_mfg_comp',
        name: 'بخور فاخر',
        productType: AppConstants.productTypeManufactured,
        batchYield: 1,
        costPrice: 1000,
        sellPrice: 2500,
        stockQuantity: 0,
      );
      final bundleProd = Product(
        id: 'p_gift_bundle',
        name: 'بوكس الهدية',
        costPrice: 2000,
        sellPrice: 5000,
        isBundle: true,
        trackStock: false,
      );
      await prodRepo.createProduct(compProd);
      await prodRepo.createProduct(bundleProd);

      await ingRepo.replaceForProduct('p_mfg_comp', [
        ProductIngredient(
          id: 'ing_oud',
          productId: 'p_mfg_comp',
          name: 'خشب عود',
          cost: 500,
          yieldCount: 1,
          materialId: 'rm_oud',
          quantity: 20,
          unit: 'جم',
          unitCost: 100,
        ),
      ]);

      await bundleRepo.replaceForBundle('p_gift_bundle', const [
        ProductBundleItem(
          id: 'bi_gift_1',
          bundleProductId: 'p_gift_bundle',
          componentProductId: 'p_mfg_comp',
          componentName: 'بخور فاخر',
          quantity: 3,
        ),
      ]);

      final today = DateTime.now();

      // Active order (deposit paid / not required)
      final activeOrder = IndividualOrder(
        id: 'ord_prep_active',
        orderNumber: 'ORD-PREP-1',
        expectedDeliveryDate: today,
        requiresDeposit: false,
        items: [
          OrderItem(
            id: 'oi_prep_1',
            orderId: 'ord_prep_active',
            productId: 'p_gift_bundle',
            name: 'بوكس الهدية',
            quantity: 2, // explodes to 2 * 3 = 6 units of p_mfg_comp
            costPrice: 2000,
            sellPrice: 5000,
          ),
        ],
      );
      await orderRepo.saveOrder(activeOrder, activeOrder.items);

      // Awaiting deposit order (should NOT enter raw-material shoppingLines; tracked via awaitingDepositCount)
      final depositOrder = IndividualOrder(
        id: 'ord_prep_deposit',
        orderNumber: 'ORD-PREP-2',
        expectedDeliveryDate: today,
        requiresDeposit: true,
        depositAmount: 2000,
        paidAmount: 500,
        items: [
          OrderItem(
            id: 'oi_prep_2',
            orderId: 'ord_prep_deposit',
            productId: 'p_gift_bundle',
            name: 'بوكس الهدية',
            quantity: 1,
            costPrice: 2000,
            sellPrice: 5000,
          ),
        ],
      );
      await orderRepo.saveOrder(depositOrder, depositOrder.items);

      final plan = await DailyPrepShoppingService().buildPlanForDate(today);
      expect(plan.prepItems.length, 1);
      expect(plan.prepItems.first.productId, 'p_mfg_comp');
      expect(plan.prepItems.first.totalQty, 9); // 6 active + 3 awaiting deposit
      expect(plan.prepItems.first.awaitingDepositCount, 1);
      expect(plan.shoppingLines.length, 1);
      expect(plan.shoppingLines.first.materialId, 'rm_oud');
      expect(plan.shoppingLines.first.requiredQty, 180.0); // 9 * 20
      expect(plan.shoppingLines.first.toBuyQty, 170.0); // 180 - 10 in stock
    });
  });

  group('Phase 6 — ProductionBatch Curing Lifecycle', () {
    test('curing batch holds stock until markBatchReady, which is idempotent',
        () async {
      final prodRepo = ProductRepositoryImpl();
      final batchRepo = ProductionBatchRepository();

      final prod = Product(
        id: 'p_curing',
        name: 'مسقى عود معتق',
        productType: AppConstants.productTypeManufactured,
        batchYield: 5,
        costPrice: 10000,
        sellPrice: 20000,
        stockQuantity: 2,
      );
      await prodRepo.createProduct(prod);

      final curingBatch = await batchRepo.produceBatch(
        product: prod,
        customYield: 5,
        deductMaterials: false,
        curingDays: 7,
        shelfLifeDays: 60,
      );

      expect(curingBatch.isCuring, isTrue);
      expect(curingBatch.batchStatus, AppConstants.batchStatusCuring);
      // Stock must still be 2 while curing
      expect((await prodRepo.getProductById('p_curing'))!.stockQuantity, 2);

      // Mark ready -> adds 5 -> stock becomes 7
      final readyBatch = await batchRepo.markBatchReady(curingBatch);
      expect(readyBatch.isReady, isTrue);
      expect((await prodRepo.getProductById('p_curing'))!.stockQuantity, 7);

      // Idempotent repeat call -> stock stays 7
      final repeatReady = await batchRepo.markBatchReady(readyBatch);
      expect(repeatReady.isReady, isTrue);
      expect((await prodRepo.getProductById('p_curing'))!.stockQuantity, 7);
    });
  });

  group('Phase 6 — Waste Logs, Monthly Insights & PDF', () {
    test(
        'recordWaste deducts & clamps stock, MonthlyInsightsService aggregates & PDF generates',
        () async {
      final prodRepo = ProductRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final wasteRepo = WasteLogRepository();

      await prodRepo.createProduct(
        Product(
          id: 'p_w1',
          name: 'معمول تمر',
          costPrice: 2000,
          sellPrice: 4000,
          stockQuantity: 3,
        ),
      );
      await matRepo.save(
        RawMaterial(
          id: 'm_w1',
          name: 'سمن بلدي',
          unit: 'لتر',
          unitCost: 5000,
          stockQuantity: 1.5,
        ),
      );

      final now = DateTime.now();
      await wasteRepo.recordWaste(
        WasteLog(
          id: 'w_prod_1',
          itemType: 'product',
          itemId: 'p_w1',
          itemName: 'معمول تمر',
          quantity: 5, // exceeds 3 -> clamped to 0
          unit: 'علبة',
          estimatedLossYer: 10000,
          reason: AppConstants.wasteReasonSpoiled,
          loggedAt: now,
        ),
      );
      await wasteRepo.recordWaste(
        WasteLog(
          id: 'w_mat_1',
          itemType: 'material',
          itemId: 'm_w1',
          itemName: 'سمن بلدي',
          quantity: 0.5,
          unit: 'لتر',
          estimatedLossYer: 2500,
          reason: AppConstants.wasteReasonDamaged,
          loggedAt: now,
        ),
      );

      expect((await prodRepo.getProductById('p_w1'))!.stockQuantity, 0);
      expect((await matRepo.getById('m_w1'))!.stockQuantity, 1.0);

      final report = await MonthlyInsightsService.instance.generateForMonth(
        now.year,
        now.month,
      );
      expect(report.wasteLogsCount, 2);
      expect(report.totalWasteLossYer, 12500.0);

      final pdfBytes = await MonthlyReportPdfGenerator.generateMonthlyPdf(
        report: report,
        currencyCode: AppConstants.currencyYer,
      );
      expect(pdfBytes.length, greaterThan(500));
    });
  });

  group('Phase 6 — Preferences Cap, Awaiting Deposit & WhatsApp Helpers', () {
    test('dailyOrderCap, isAwaitingDeposit & WhatsApp Phase 6 helpers', () async {
      final prefs = PreferencesService.instance;
      await prefs.setDailyOrderCap(12);
      expect(prefs.getDailyOrderCap(), 12);

      final awaiting = IndividualOrder(
        id: 'ord_dep_1',
        orderNumber: 'ORD-DEP-1',
        customerName: 'سارة',
        requiresDeposit: true,
        depositAmount: 5000,
        paidAmount: 2000,
      );
      expect(awaiting.isAwaitingDeposit, isTrue);

      final met = awaiting.copyWith(paidAmount: 5000);
      expect(met.isAwaitingDeposit, isFalse);

      final apology = WhatsAppTemplateEngine.buildCapacityFullApologyMessage(
        fullDate: DateTime(2026, 11, 24),
        nextAvailableDate: DateTime(2026, 11, 25),
      );
      expect(apology, contains('2026-11-24'));
      expect(apology, contains('2026-11-25'));

      final reminder = WhatsAppTemplateEngine.buildDepositReminderMessage(awaiting);
      expect(reminder, contains('ORD-DEP-1'));
      expect(reminder, contains('سارة'));
    });
  });

  group('Phase 6 — 360x740 Light & Dark Widget Overflow & Render QA', () {
    Future<void> pumpAt360x740(
      WidgetTester tester, {
      required Widget child,
      required ThemeMode themeMode,
      bool touchSqlite = true,
    }) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final oldOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      try {
        await tester.pumpWidget(
          _buildPhase6Harness(child: child, themeMode: themeMode),
        );
        if (touchSqlite) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 150)),
          );
          await tester.pump(const Duration(seconds: 10));
        } else {
          await tester.pumpAndSettle();
        }
        await tester.pump();
      } finally {
        FlutterError.onError = oldOnError;
      }

      final overflowErrors = errors
          .where((e) => e.toString().contains('RenderFlex overflowed'))
          .toList();
      expect(
        overflowErrors,
        isEmpty,
        reason: 'RenderFlex overflow in $themeMode: $overflowErrors',
      );
      expect(errors, isEmpty, reason: 'Unexpected Flutter errors: $errors');
    }

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('ProductionBatchesScreen renders cleanly ($mode)',
          (tester) async {
        await tester.runAsync(() => DemoDataService.instance.generateDemoData());
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const ProductionBatchesScreen(),
        );
        expect(find.byType(ProductionBatchesScreen), findsOneWidget);
      });

      testWidgets('RecordWasteSheet renders cleanly ($mode)', (tester) async {
        await tester.runAsync(() => DemoDataService.instance.generateDemoData());
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const Scaffold(body: RecordWasteSheet()),
        );
        expect(find.byType(RecordWasteSheet), findsOneWidget);
      });

      testWidgets('AddEditProductSheet bundle & variants renders cleanly ($mode)',
          (tester) async {
        Product? bundle;
        await tester.runAsync(() async {
          await DemoDataService.instance.generateDemoData();
          bundle = await ProductRepositoryImpl().getProductById(
            'demo_prod_bundle_1',
          );
        });
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: Scaffold(
            body: SingleChildScrollView(
              child: AddEditProductSheet(
                productToEdit: bundle,
                onSave: (_) {},
              ),
            ),
          ),
        );
        expect(find.byType(AddEditProductSheet), findsOneWidget);
      });

      testWidgets('QuickOrderSheet with daily cap & deposit renders cleanly ($mode)',
          (tester) async {
        await tester.runAsync(() async {
          await PreferencesService.instance.setDailyOrderCap(1);
          await DemoDataService.instance.generateDemoData();
        });
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const Scaffold(body: QuickOrderSheet()),
        );
        expect(find.byType(QuickOrderSheet), findsOneWidget);
      });

      testWidgets('OrderDetailsScreen awaiting deposit renders cleanly ($mode)',
          (tester) async {
        await tester.runAsync(() async {
          final uiDepOrder = IndividualOrder(
            id: 'ord_ui_dep',
            orderNumber: 'ORD-UI-DEP',
            customerName: 'أمينة',
            requiresDeposit: true,
            depositAmount: 10000,
            paidAmount: 2000,
            items: [
              OrderItem(
                id: 'oi_ui_1',
                orderId: 'ord_ui_dep',
                name: 'بخور عدني',
                quantity: 1,
                costPrice: 5000,
                sellPrice: 20000,
              ),
            ],
          );
          await OrderRepositoryImpl().saveOrder(uiDepOrder, uiDepOrder.items);
        });
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const OrderDetailsScreen(orderId: 'ord_ui_dep'),
        );
        expect(find.byType(OrderDetailsScreen), findsOneWidget);
      });

      testWidgets('MonthlyReportScreen waste section renders cleanly ($mode)',
          (tester) async {
        await tester.runAsync(() => DemoDataService.instance.generateDemoData());
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const MonthlyReportScreen(),
        );
        expect(find.byType(MonthlyReportScreen), findsOneWidget);
      });

      testWidgets('OrdersListScreen daily cap bar renders cleanly ($mode)',
          (tester) async {
        await tester.runAsync(() async {
          await PreferencesService.instance.setDailyOrderCap(5);
          await DemoDataService.instance.generateDemoData();
        });
        await pumpAt360x740(
          tester,
          themeMode: mode,
          child: const OrdersListScreen(),
        );
        expect(find.byType(OrdersListScreen), findsOneWidget);
      });
    }
  });
}
