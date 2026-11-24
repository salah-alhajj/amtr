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
import 'package:mosaed/core/services/demo_data_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/core/widgets/business_drawer.dart';
import 'package:mosaed/features/cashbox/data/repositories/cashbox_repository_impl.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/cashbox/presentation/screens/cashbox_screen.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/manufacturing/data/repositories/production_batch_repository.dart';
import 'package:mosaed/features/manufacturing/data/repositories/raw_material_repository.dart';
import 'package:mosaed/features/manufacturing/domain/daily_prep_shopping_service.dart';
import 'package:mosaed/features/manufacturing/domain/manufacturing_cost_service.dart';
import 'package:mosaed/features/manufacturing/presentation/screens/daily_prep_shopping_screen.dart';
import 'package:mosaed/features/manufacturing/presentation/screens/materials_and_templates_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/widgets/quick_order_sheet.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/reports/domain/monthly_insights_service.dart';
import 'package:mosaed/features/reports/presentation/screens/monthly_report_screen.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/bloc/suppliers_bloc.dart';
import 'package:mosaed/models/consolidated_shipment.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/product_ingredient.dart';
import 'package:mosaed/models/production_batch.dart';
import 'package:mosaed/models/raw_material.dart';
import 'package:mosaed/models/supplier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  Future<void> clearAllTables() async {
    const tables = [
      'production_batches',
      'product_ingredients',
      'manufacturing_template_items',
      'manufacturing_templates',
      'raw_materials',
      'whatsapp_templates',
      'daily_closings',
      'payment_transactions',
      'order_items',
      'orders',
      'shipments',
      'customers',
      'products',
      'expenses',
      'suppliers',
    ];
    for (final t in tables) {
      await db.delete(t);
    }
  }

  setUpAll(() async {
    await initializeDateFormatting('ar');

    final rawJson = File('i18n/ar.json').readAsStringSync();
    final decoded = json.decode(rawJson) as Map<String, dynamic>;
    LocalizationHelper.setStrings(
      decoded.map((k, v) => MapEntry(k, v.toString())),
      'ar',
    );

    SharedPreferences.setMockInitialValues({
      'app_onboarding_completed': true,
      'app_business_mode': AppConstants.businessModeProductiveFamily,
      'app_business_name': 'مطبخ أم محمد',
      'app_default_currency': AppConstants.currencyYer,
      'app_multi_currency_enabled': false,
    });
    await PreferencesService.instance.init();

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 10,
      onCreate: (database, version) =>
          AppDatabase.instance.createDBForTesting(database),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    await clearAllTables();
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  group('a) DB v10 Schema, production_batches & Backup/Restore Round-Trip', () {
    test('v10 schema columns & tables exist and survive JSON export/import',
        () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='production_batches'",
      );
      expect(tables, hasLength(1));

      final rmCols = (await db.rawQuery('PRAGMA table_info(raw_materials)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(rmCols, containsAll(['stockQuantity', 'lowStockThreshold']));

      final expCols = (await db.rawQuery('PRAGMA table_info(expenses)'))
          .map((r) => r['name'] as String)
          .toSet();
      expect(expCols, containsAll(['receiptPhotoPath', 'parentRuleId']));

      final supRepo = SupplierRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final prodRepo = ProductRepositoryImpl();
      final expRepo = ExpenseRepositoryImpl();
      final batchRepo = ProductionBatchRepository();

      await supRepo.createSupplier(Supplier(
        id: 'sup_rt_1',
        name: 'مطحنة الخير',
        phone: '777111222',
      ));
      await matRepo.save(RawMaterial(
        id: 'mat_rt_1',
        name: 'دقيق فاخر',
        unit: 'كجم',
        unitCost: 1500,
        currency: AppConstants.currencyYer,
        supplierId: 'sup_rt_1',
        stockQuantity: 12.5,
        lowStockThreshold: 3.0,
      ));
      await prodRepo.createProduct(Product(
        id: 'prod_rt_1',
        name: 'فطائر محشوة',
        productType: AppConstants.productTypeManufactured,
        costPrice: 500,
        sellPrice: 1200,
        currency: AppConstants.currencyYer,
        stockQuantity: 25,
        batchYield: 10,
      ));
      await expRepo.createExpense(Expense(
        id: 'exp_rt_rule',
        title: 'إيجار المطبخ',
        category: 'exp_cat_rent',
        amount: 30000,
        currency: AppConstants.currencyYer,
        recurrence: AppConstants.expenseRecurrenceMonthly,
        receiptPhotoPath: '/tmp/receipt_1.jpg',
      ));
      await expRepo.createExpense(Expense(
        id: 'exp_rt_child',
        title: 'إيجار المطبخ',
        category: 'exp_cat_rent',
        amount: 30000,
        currency: AppConstants.currencyYer,
        recurrence: AppConstants.expenseRecurrenceOnce,
        parentRuleId: 'exp_rt_rule',
      ));
      await batchRepo.recordBatch(ProductionBatch(
        id: 'batch_rt_1',
        productId: 'prod_rt_1',
        productName: 'فطائر محشوة',
        yieldCount: 10,
        totalCost: 5000,
        currency: AppConstants.currencyYer,
        notes: 'دفعة صباحية',
      ));

      final exported = await AppDatabase.instance.exportAllDataToJson();
      expect(exported['production_batches'], isA<List>());
      expect((exported['production_batches'] as List).length, 1);

      await clearAllTables();
      expect(await batchRepo.getRecentBatches(), isEmpty);

      await AppDatabase.instance.importAllDataFromJson(exported);

      final restoredBatches = await batchRepo.getRecentBatches();
      expect(restoredBatches, hasLength(1));
      expect(restoredBatches.first.id, 'batch_rt_1');
      expect(restoredBatches.first.yieldCount, 10);
      expect(restoredBatches.first.totalCost, 5000);

      final restoredMaterials = await matRepo.getAll();
      expect(restoredMaterials, hasLength(1));
      expect(restoredMaterials.first.stockQuantity, 12.5);
      expect(restoredMaterials.first.lowStockThreshold, 3.0);

      final restoredExpenses = await expRepo.getAllExpenses();
      expect(restoredExpenses, hasLength(2));
      final restoredRule =
          restoredExpenses.firstWhere((e) => e.id == 'exp_rt_rule');
      final restoredChild =
          restoredExpenses.firstWhere((e) => e.id == 'exp_rt_child');
      expect(restoredRule.receiptPhotoPath, '/tmp/receipt_1.jpg');
      expect(restoredChild.parentRuleId, 'exp_rt_rule');
    });
  });

  group('b) Atomic OrderRepositoryImpl Stock, ReorderEvent & Payment Deltas',
      () {
    test(
        'saveOrder deducts stock, updateOrder applies delta, payment delta records negative refunds, ReorderEvent refreshes prices, deleteOrder restores stock',
        () async {
      final prodRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();

      await prodRepo.createProduct(Product(
        id: 'prod_atom_1',
        name: 'عسل سدر',
        costPrice: 4000,
        sellPrice: 6000,
        currency: AppConstants.currencyYer,
        trackStock: true,
        stockQuantity: 20,
      ));

      final item1 = OrderItem(
        id: 'oi_atom_1',
        orderId: 'ord_atom_1',
        productId: 'prod_atom_1',
        name: 'عسل سدر',
        quantity: 5,
        costPrice: 4000,
        sellPrice: 6000,
        currency: AppConstants.currencyYer,
      );
      final order1 = IndividualOrder(
        id: 'ord_atom_1',
        orderNumber: 'ATOM-01',
        customerName: 'خالد',
        paymentStatus: AppConstants.paymentPartial,
        paidAmount: 10000,
        currency: AppConstants.currencyYer,
        items: [item1],
      );

      // 1) saveOrder deducts 5 -> stock 15
      await orderRepo.saveOrder(order1, [item1]);
      var prod = await prodRepo.getProductById('prod_atom_1');
      expect(prod!.stockQuantity, 15);

      // 2) updateOrder increases qty 5 -> 8 (delta -3 -> stock 12)
      final itemIncreased = item1.copyWith(quantity: 8);
      await orderRepo.updateOrder(
        order1.copyWith(items: [itemIncreased]),
        [itemIncreased],
      );
      prod = await prodRepo.getProductById('prod_atom_1');
      expect(prod!.stockQuantity, 12);

      // 3) updateOrder decreases qty 8 -> 3 (delta +5 -> stock 17)
      final itemDecreased = item1.copyWith(quantity: 3);
      await orderRepo.updateOrder(
        order1.copyWith(items: [itemDecreased]),
        [itemDecreased],
      );
      prod = await prodRepo.getProductById('prod_atom_1');
      expect(prod!.stockQuantity, 17);

      // 4) Payment increase & negative refund delta recorded in payment_transactions
      await orderRepo.updatePaymentStatus(
        'ord_atom_1',
        AppConstants.paymentPartial,
        15000,
      );
      await orderRepo.updatePaymentStatus(
        'ord_atom_1',
        AppConstants.paymentPartial,
        12000,
      );
      final txRows = await db.query(
        'payment_transactions',
        where: 'orderId = ?',
        whereArgs: ['ord_atom_1'],
        orderBy: 'paidAt ASC',
      );
      final amounts =
          txRows.map((r) => (r['amount'] as num).toDouble()).toList();
      expect(amounts, containsAllInOrder([10000.0, 5000.0, -3000.0]));

      // 5) ReorderEvent refreshes product price (update product sellPrice to 7500 first)
      await prodRepo.updateProduct(prod.copyWith(sellPrice: 7500));
      final ordersBloc = OrdersBloc(repository: orderRepo);
      ordersBloc.add(const LoadOrders());
      await ordersBloc.stream.firstWhere((s) => s is OrdersLoaded);

      final loadedOrder1 = (await orderRepo.getOrderById('ord_atom_1'))!;
      ordersBloc.add(ReorderEvent(loadedOrder1));
      await ordersBloc.stream.firstWhere(
        (s) => s is OrdersLoaded && s.allOrders.length == 2,
      );
      final allOrders = await orderRepo.getAllOrders();
      final reordered = allOrders.firstWhere((o) => o.id != 'ord_atom_1');
      expect(reordered.paidAmount, 0.0);
      expect(reordered.orderStatus, AppConstants.orderStatusPending);
      expect(reordered.items.first.sellPrice, 7500.0);
      // Stock deducted by 3 again (17 -> 14)
      prod = await prodRepo.getProductById('prod_atom_1');
      expect(prod!.stockQuantity, 14);

      await ordersBloc.close();

      // 6) deleteOrder restores stock cleanly (14 + 3 = 17)
      await orderRepo.deleteOrder('ord_atom_1');
      prod = await prodRepo.getProductById('prod_atom_1');
      expect(prod!.stockQuantity, 17);
    });
  });

  group(
      'c) Recurring Expenses Non-Multiplication & CashBox Due Recurring / Petty Cash',
      () {
    test(
        'parentRuleId entries do not inflate estimatedMonthlyRecurringInYer & CashBox tracks due recurring + petty cash',
        () async {
      final expRepo = ExpenseRepositoryImpl();
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));
      final lastMonth = DateTime(today.year, today.month - 1, 1);

      // Monthly rule created last month: 12,000 YER/mo (due this month)
      await expRepo.createExpense(Expense(
        id: 'rule_monthly_1',
        title: 'إيجار المحل',
        category: 'exp_cat_rent',
        amount: 12000,
        currency: AppConstants.currencyYer,
        expenseDate: lastMonth,
        recurrence: AppConstants.expenseRecurrenceMonthly,
      ));
      // Daily rule: 500 YER/day -> 15,000 YER/mo
      await expRepo.createExpense(Expense(
        id: 'rule_daily_1',
        title: 'مواصلات يومية',
        category: 'exp_cat_delivery',
        amount: 500,
        currency: AppConstants.currencyYer,
        expenseDate: yesterday,
        recurrence: AppConstants.expenseRecurrenceDaily,
      ));
      // Child logged entry referencing daily rule (should NOT multiply monthly estimate)
      await expRepo.createExpense(Expense(
        id: 'child_daily_1',
        title: 'مواصلات يومية',
        category: 'exp_cat_delivery',
        amount: 500,
        currency: AppConstants.currencyYer,
        expenseDate: today,
        recurrence: AppConstants.expenseRecurrenceDaily,
        parentRuleId: 'rule_daily_1',
      ));
      // Petty cash expense today
      await expRepo.createExpense(Expense(
        id: 'petty_today_1',
        title: 'أكياس تغليف صغيرة',
        category: 'exp_cat_packaging',
        amount: 1800,
        currency: AppConstants.currencyYer,
        expenseDate: today,
        isPettyCash: true,
      ));

      final expBloc = ExpensesBloc(repository: expRepo);
      expBloc.add(const LoadExpenses());
      final loaded =
          await expBloc.stream.firstWhere((s) => s is ExpensesLoaded)
              as ExpensesLoaded;
      // 12,000 + (500 * 30) = 27,000 (child_daily_1 is ignored)
      expect(loaded.estimatedMonthlyRecurringInYer, closeTo(27000.0, 0.01));
      await expBloc.close();

      // CashBox summary for today
      final cashboxRepo = CashBoxRepositoryImpl();
      final summary = await cashboxRepo.getDailySummary(today);
      expect(summary.pettyCashExpensesYer, closeTo(1800.0, 0.01));
      // rule_daily_1 is already logged today via child_daily_1,
      // while rule_monthly_1 has NOT been logged this month yet -> should be due!
      final dueIds = summary.dueRecurringExpenses.map((e) => e.id).toList();
      expect(dueIds, contains('rule_monthly_1'));
      expect(dueIds, isNot(contains('rule_daily_1')));
    });
  });

  group(
      'd) ManufacturingCostService, ProductionBatchRepository & DailyPrepShoppingService',
      () {
    test(
        'material price change converts currency & detects margin erosion, batch production updates both stocks, daily prep builds supplier-grouped shopping list',
        () async {
      final supRepo = SupplierRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final prodRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();

      await supRepo.createSupplier(Supplier(
        id: 'sup_mfg_1',
        name: 'تاجر البهارات',
        phone: '777888999',
      ));

      final spice = RawMaterial(
        id: 'mat_spice_1',
        name: 'زعفران فاخر',
        unit: 'كجم',
        unitCost: 10.0, // 10 SAR = 5,350 YER
        currency: AppConstants.currencySar,
        supplierId: 'sup_mfg_1',
        stockQuantity: 3.0,
        lowStockThreshold: 2.0,
      );
      await matRepo.save(spice);

      final cake = Product(
        id: 'prod_cake_1',
        name: 'كيك زعفران',
        productType: AppConstants.productTypeManufactured,
        costPrice: 1070.0, // 2kg * 5350 / 10 units = 1070 YER/unit
        sellPrice: 2000.0,
        currency: AppConstants.currencyYer,
        stockQuantity: 2,
        batchYield: 10,
      );
      await prodRepo.createProduct(cake);

      final ing = ProductIngredient(
        id: 'ing_cake_1',
        productId: 'prod_cake_1',
        materialId: 'mat_spice_1',
        name: 'زعفران فاخر',
        quantity: 2.0,
        unit: 'كجم',
        unitCost: 5350.0,
        cost: 10700.0,
        currency: AppConstants.currencyYer,
      );
      await db.insert('product_ingredients', ing.toMap());

      // 1) Material price hike: 10 SAR -> 18 SAR (= 9,630 YER/kg)
      final hikedSpice = spice.copyWith(unitCost: 18.0);
      await matRepo.save(hikedSpice);

      final impacts = await ManufacturingCostService()
          .recalculateOnMaterialPriceChange(hikedSpice);
      expect(impacts, hasLength(1));
      final impact = impacts.first;
      // 2kg * 18 SAR * 535 / 10 units = 1,926 YER/unit
      expect(impact.newCost, closeTo(1926.0, 0.5));
      expect(impact.isMarginEroded, isTrue);
      expect(impact.suggestedSellPrice, greaterThan(cake.sellPrice));

      final updatedCake = (await prodRepo.getProductById('prod_cake_1'))!;
      expect(updatedCake.costPrice, closeTo(1926.0, 0.5));

      // 2) Batch production: yield 10 -> cake stock 2->12, spice stock 3.0->1.0 + expense logged
      final batchRepo = ProductionBatchRepository();
      final batch = await batchRepo.produceBatch(
        product: updatedCake,
        customYield: 10,
        deductMaterials: true,
        logExpense: true,
        notes: 'دفعة اختبار',
      );
      expect(batch.yieldCount, 10);
      expect(batch.totalCost, closeTo(19260.0, 1.0));

      final afterCake = (await prodRepo.getProductById('prod_cake_1'))!;
      expect(afterCake.stockQuantity, 12);

      final afterSpice = (await matRepo.getAll())
          .firstWhere((m) => m.id == 'mat_spice_1');
      expect(afterSpice.stockQuantity, closeTo(1.0, 0.01));
      expect(afterSpice.isLowStock, isTrue); // 1.0 <= 2.0

      final loggedBatches = await batchRepo.getByProductId('prod_cake_1');
      expect(loggedBatches, hasLength(1));

      // 3) DailyPrepShoppingService for today's undelivered orders (qty 15 -> 2 batches -> 3.0kg needed - 1.0kg in stock = 2.0kg to buy)
      final today = DateTime.now();
      final orderItem = OrderItem(
        id: 'oi_prep_1',
        orderId: 'ord_prep_1',
        productId: 'prod_cake_1',
        name: 'كيك زعفران',
        quantity: 15,
        costPrice: 1926,
        sellPrice: 2500,
        currency: AppConstants.currencyYer,
        description: 'بدون مكسرات',
      );
      await orderRepo.saveOrder(
        IndividualOrder(
          id: 'ord_prep_1',
          orderNumber: 'PREP-1',
          customerName: 'سارة',
          orderStatus: AppConstants.orderStatusPending,
          expectedDeliveryDate: today,
          notes: 'التسليم عصراً',
          currency: AppConstants.currencyYer,
          items: [orderItem],
        ),
        [orderItem],
      );

      final plan = await DailyPrepShoppingService().buildPlanForDate(today);
      expect(plan.prepItems, hasLength(1));
      expect(plan.prepItems.first.totalQty, 15);
      expect(plan.prepItems.first.batchCount, 2);
      expect(
        plan.prepItems.first.customerNotes.join(' '),
        contains('بدون مكسرات'),
      );

      expect(plan.shoppingLines, hasLength(1));
      final line = plan.shoppingLines.first;
      expect(line.supplierName, 'تاجر البهارات');
      expect(line.requiredQty, closeTo(3.0, 0.01));
      expect(line.inStockQty, closeTo(1.0, 0.01));
      expect(line.toBuyQty, closeTo(2.0, 0.01));
      expect(plan.shoppingBySupplier.keys, contains('تاجر البهارات'));
    });
  });

  group('e) MonthlyInsightsService v10 Metrics & DemoDataService v10 Lifecycle',
      () {
    test(
        'MonthlyInsightsService separates Resale vs Manufactured, Petty vs Recurring, Top Suppliers, and deducts transportCost',
        () async {
      final now = DateTime.now();
      final supRepo = SupplierRepositoryImpl();
      final prodRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final expRepo = ExpenseRepositoryImpl();
      final shipRepo = ShipmentRepositoryImpl();

      await supRepo.createSupplier(Supplier(
        id: 'sup_rep_1',
        name: 'مؤسسة الإمداد',
      ));

      await prodRepo.createProduct(Product(
        id: 'prod_resale_1',
        name: 'عطر جاهز',
        productType: AppConstants.productTypeResale,
        costPrice: 2000,
        sellPrice: 3500,
        currency: AppConstants.currencyYer,
        stockQuantity: 10,
      ));
      await prodRepo.createProduct(Product(
        id: 'prod_mfg_1',
        name: 'بخور منزلي',
        productType: AppConstants.productTypeManufactured,
        costPrice: 1500,
        sellPrice: 4000,
        currency: AppConstants.currencyYer,
        stockQuantity: 10,
      ));

      final oiResale = OrderItem(
        id: 'oi_r1',
        orderId: 'ord_rep_1',
        productId: 'prod_resale_1',
        name: 'عطر جاهز',
        quantity: 2,
        costPrice: 2000,
        sellPrice: 3500,
        currency: AppConstants.currencyYer,
      );
      final oiMfg = OrderItem(
        id: 'oi_m1',
        orderId: 'ord_rep_1',
        productId: 'prod_mfg_1',
        name: 'بخور منزلي',
        quantity: 3,
        costPrice: 1500,
        sellPrice: 4000,
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(
        IndividualOrder(
          id: 'ord_rep_1',
          orderNumber: 'REP-1',
          customerName: 'عميل التقرير',
          paymentStatus: AppConstants.paymentPrepaid,
          paidAmount: 19000,
          createdAt: now,
          currency: AppConstants.currencyYer,
          items: [oiResale, oiMfg],
        ),
        [oiResale, oiMfg],
      );

      // Shipment with transportCost = 1000 YER
      await shipRepo.saveShipment(
        ConsolidatedShipment(
          id: 'ship_rep_1',
          shipmentNumber: 'SHP-REP-1',
          title: 'شحنة اختبار الشهر',
          trackingNumber: 'TRK-REP-1',
          transportCost: 1000,
          transportCostCurrency: AppConstants.currencyYer,
          createdAt: now,
        ),
        const [],
      );

      // Expenses: petty cash (500) + recurring (2000, linked to supplier) + one-time (1500, linked to supplier)
      await expRepo.createExpense(Expense(
        id: 'exp_rep_petty',
        title: 'نثريات مكتب',
        amount: 500,
        currency: AppConstants.currencyYer,
        expenseDate: now,
        isPettyCash: true,
      ));
      await expRepo.createExpense(Expense(
        id: 'exp_rep_rec',
        title: 'اشتراك شهري',
        amount: 2000,
        currency: AppConstants.currencyYer,
        expenseDate: now,
        recurrence: AppConstants.expenseRecurrenceMonthly,
        supplierId: 'sup_rep_1',
      ));
      await expRepo.createExpense(Expense(
        id: 'exp_rep_once',
        title: 'شراء خامات',
        amount: 1500,
        currency: AppConstants.currencyYer,
        expenseDate: now,
        supplierId: 'sup_rep_1',
      ));

      final report = await MonthlyInsightsService.instance
          .generateForMonth(now.year, now.month);

      expect(report.resaleSalesYer, closeTo(7000.0, 0.01));
      expect(report.resaleProfitYer, closeTo(3000.0, 0.01));
      expect(report.manufacturedSalesYer, closeTo(12000.0, 0.01));
      expect(report.manufacturedProfitYer, closeTo(7500.0, 0.01));
      expect(report.pettyCashExpensesYer, closeTo(500.0, 0.01));
      expect(report.recurringExpensesYer, closeTo(2000.0, 0.01));
      // Both petty cash (500, recurrence=once) and regular one-time (1500) count in oneTimeExpensesYer
      expect(report.oneTimeExpensesYer, closeTo(2000.0, 0.01));
      expect(report.shipmentsTransportCostYer, closeTo(1000.0, 0.01));
      // Net profit = (3000 + 7500) - 4000 expenses - 1000 transport = 5500
      expect(report.netProfitYer, closeTo(5500.0, 0.01));

      expect(report.topSuppliers, hasLength(1));
      expect(report.topSuppliers.first.name, 'مؤسسة الإمداد');
      expect(report.topSuppliers.first.totalSpendYer, closeTo(3500.0, 0.01));
      expect(report.topSuppliers.first.entriesCount, 2);
    });

    test(
        'DemoDataService seeds all v10 tables and removes ONLY demo_ records',
        () async {
      final prodRepo = ProductRepositoryImpl();
      await prodRepo.createProduct(Product(
        id: 'real_user_prod_1',
        name: 'منتج حقيقي محفوظ',
        costPrice: 1000,
        sellPrice: 2000,
        currency: AppConstants.currencyYer,
      ));

      await DemoDataService.instance.generateDemoData();
      final stats = await DemoDataService.instance.getDemoDataStats();
      expect(stats.hasDemoData, isTrue);
      expect(stats.suppliersCount, greaterThan(0));
      expect(stats.rawMaterialsCount, greaterThan(0));
      expect(stats.templatesCount, greaterThan(0));
      expect(stats.productsCount, greaterThan(0));
      expect(stats.expensesCount, greaterThan(0));
      expect(stats.paymentsCount, greaterThan(0));
      expect(stats.closingsCount, greaterThan(0));

      await DemoDataService.instance.removeDemoData();
      final afterStats = await DemoDataService.instance.getDemoDataStats();
      expect(afterStats.hasDemoData, isFalse);
      expect(afterStats.totalRecords, 0);

      // Real user data must remain completely untouched
      final surviving = await prodRepo.getProductById('real_user_prod_1');
      expect(surviving, isNotNull);
      expect(surviving!.name, 'منتج حقيقي محفوظ');
    });
  });

  group('f) Narrow-Screen (360x740) Light & Dark Overflow Tests (v10 UI)', () {
    Widget buildApp({required Widget home, required ThemeMode themeMode}) {
      final orderRepo = OrderRepositoryImpl();
      final shipmentRepo = ShipmentRepositoryImpl();
      final customerRepo = CustomerRepositoryImpl();
      final productRepo = ProductRepositoryImpl();
      final expenseRepo = ExpenseRepositoryImpl();
      final supplierRepo = SupplierRepositoryImpl();

      return MultiBlocProvider(
        providers: [
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
            create: (_) =>
                OrdersBloc(repository: orderRepo)..add(const LoadOrders()),
          ),
          BlocProvider<ShipmentsBloc>(
            create: (_) => ShipmentsBloc(repository: shipmentRepo)
              ..add(const LoadShipments()),
          ),
          BlocProvider<CustomersBloc>(
            create: (_) => CustomersBloc(
              repository: customerRepo,
              orderRepository: orderRepo,
            )..add(const LoadCustomers()),
          ),
          BlocProvider<ProductsBloc>(
            create: (_) => ProductsBloc(repository: productRepo)
              ..add(const LoadProducts()),
          ),
          BlocProvider<ExpensesBloc>(
            create: (_) => ExpensesBloc(repository: expenseRepo)
              ..add(const LoadExpenses()),
          ),
          BlocProvider<SuppliersBloc>(
            create: (_) => SuppliersBloc(repository: supplierRepo)
              ..add(const LoadSuppliers()),
          ),
        ],
        child: MaterialApp(
          key: UniqueKey(),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
          home: home,
        ),
      );
    }

    Future<void> pumpAndSettleSafe(WidgetTester tester) async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 250)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    Future<void> pumpUntilFound(
      WidgetTester tester,
      Finder finder, {
      int maxAttempts = 12,
    }) async {
      for (var i = 0; i < maxAttempts; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await pumpAndSettleSafe(tester);
      }
    }

    Future<void> runNarrowWithErrorTrap(
      WidgetTester tester,
      Future<void> Function() body,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;

      final capturedErrors = <FlutterErrorDetails>[];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (FlutterErrorDetails details) {
        capturedErrors.add(details);
        prevOnError?.call(details);
      };

      try {
        await body();
        await tester.pump(const Duration(seconds: 2));
        if (capturedErrors.isNotEmpty) {
          final msg = capturedErrors
              .map((e) => e.exceptionAsString())
              .join('\n---\n');
          fail('Captured ${capturedErrors.length} FlutterError(s):\n$msg');
        }
      } finally {
        FlutterError.onError = prevOnError;
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      }
    }

    Future<void> seedRichV10Data() async {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final supRepo = SupplierRepositoryImpl();
      final matRepo = RawMaterialRepository();
      final prodRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final expRepo = ExpenseRepositoryImpl();

      await supRepo.createSupplier(Supplier(
        id: 'sup_ui_1',
        name: 'سوق الجملة المركزي للخامات',
        phone: '777000111',
      ));
      await matRepo.save(RawMaterial(
        id: 'mat_ui_1',
        name: 'سمن بلدي فاخر',
        unit: 'كجم',
        unitCost: 8500,
        currency: AppConstants.currencyYer,
        supplierId: 'sup_ui_1',
        stockQuantity: 1.5,
        lowStockThreshold: 2.0,
      ));
      await matRepo.save(RawMaterial(
        id: 'mat_ui_2',
        name: 'دقيق أبيض ناعم',
        unit: 'كجم',
        unitCost: 1200,
        currency: AppConstants.currencyYer,
        supplierId: 'sup_ui_1',
        stockQuantity: 10.0,
        lowStockThreshold: 2.0,
      ));
      await prodRepo.createProduct(Product(
        id: 'prod_ui_mfg',
        name: 'بنت الصحن ملكي بالعسل',
        productType: AppConstants.productTypeManufactured,
        costPrice: 3000,
        sellPrice: 6500,
        currency: AppConstants.currencyYer,
        stockQuantity: 4,
        batchYield: 5,
      ));
      await prodRepo.createProduct(Product(
        id: 'prod_ui_resale',
        name: 'عبوة عسل سدر جاهزة',
        productType: AppConstants.productTypeResale,
        costPrice: 5000,
        sellPrice: 8000,
        currency: AppConstants.currencyYer,
        stockQuantity: 8,
      ));
      await db.insert(
        'product_ingredients',
        ProductIngredient(
          id: 'ing_ui_1',
          productId: 'prod_ui_mfg',
          materialId: 'mat_ui_1',
          name: 'سمن بلدي فاخر',
          quantity: 2.0,
          unit: 'كجم',
          unitCost: 8500,
          cost: 17000,
          currency: AppConstants.currencyYer,
        ).toMap(),
      );

      final items = [
        OrderItem(
          id: 'oi_ui_1',
          orderId: 'ord_ui_1',
          productId: 'prod_ui_mfg',
          name: 'بنت الصحن ملكي بالعسل',
          quantity: 6,
          costPrice: 3000,
          sellPrice: 6500,
          currency: AppConstants.currencyYer,
          description: 'حار ومقرمش',
        ),
        OrderItem(
          id: 'oi_ui_2',
          orderId: 'ord_ui_1',
          productId: 'prod_ui_resale',
          name: 'عبوة عسل سدر جاهزة',
          quantity: 2,
          costPrice: 5000,
          sellPrice: 8000,
          currency: AppConstants.currencyYer,
        ),
      ];
      await orderRepo.saveOrder(
        IndividualOrder(
          id: 'ord_ui_1',
          orderNumber: 'UI-100',
          customerName: 'أم عبد الله',
          paymentStatus: AppConstants.paymentPrepaid,
          paidAmount: 55000,
          expectedDeliveryDate: now,
          createdAt: now,
          notes: 'التوصيل قبل المغرب',
          currency: AppConstants.currencyYer,
          items: items,
        ),
        items,
      );

      // Due recurring expense (created yesterday, not logged today)
      await expRepo.createExpense(Expense(
        id: 'exp_ui_rec',
        title: 'أجرة التوصيل اليومية',
        category: 'exp_cat_delivery',
        amount: 2500,
        currency: AppConstants.currencyYer,
        expenseDate: yesterday,
        recurrence: AppConstants.expenseRecurrenceDaily,
        supplierId: 'sup_ui_1',
      ));
      // Petty cash expense today
      await expRepo.createExpense(Expense(
        id: 'exp_ui_petty',
        title: 'نثريات أكياس وقصدير',
        category: 'exp_cat_packaging',
        amount: 1200,
        currency: AppConstants.currencyYer,
        expenseDate: now,
        isPettyCash: true,
        supplierId: 'sup_ui_1',
      ));
    }

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final modeName = themeMode == ThemeMode.light ? 'Light' : 'Dark';

      testWidgets('DailyPrepAndShoppingScreen [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          await tester.pumpWidget(buildApp(
            home: const DailyPrepAndShoppingScreen(),
            themeMode: themeMode,
          ));
          await pumpUntilFound(tester, find.text('بنت الصحن ملكي بالعسل'));
          expect(find.text('prep_screen_title'.i18n()), findsOneWidget);
          expect(find.text('بنت الصحن ملكي بالعسل'), findsWidgets);

          final shoppingTab = find.text('prep_tab_shopping'.i18n());
          expect(shoppingTab, findsOneWidget);
          await tester.tap(shoppingTab);
          await pumpUntilFound(tester, find.text('سمن بلدي فاخر'));
          expect(find.text('سمن بلدي فاخر'), findsWidgets);
        });
      });

      testWidgets('MonthlyReportScreen v10 [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          await tester.pumpWidget(buildApp(
            home: const MonthlyReportScreen(),
            themeMode: themeMode,
          ));
          await pumpUntilFound(
            tester,
            find.text('monthly_resale_vs_mfg_title'.i18n()),
          );
          expect(find.text('monthly_report_title'.i18n()), findsOneWidget);
          expect(
            find.text('monthly_resale_vs_mfg_title'.i18n()),
            findsOneWidget,
          );
        });
      });

      testWidgets('CashBoxScreen due recurring [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          await tester.pumpWidget(buildApp(
            home: const CashBoxScreen(),
            themeMode: themeMode,
          ));
          await pumpUntilFound(
            tester,
            find.text('cashbox_due_recurring_title'.i18n()),
          );
          expect(
            find.text('cashbox_due_recurring_title'.i18n()),
            findsOneWidget,
          );
        });
      });

      testWidgets('QuickOrderSheet WhatsApp paste [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          await tester.pumpWidget(buildApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => QuickOrderSheet.show(ctx),
                  child: const Text('OPEN_QUICK_ORDER'),
                ),
              ),
            ),
            themeMode: themeMode,
          ));
          await pumpAndSettleSafe(tester);
          await tester.tap(find.text('OPEN_QUICK_ORDER'));
          await pumpUntilFound(
            tester,
            find.text('quick_order_paste_whatsapp'.i18n()),
          );
          expect(
            find.text('quick_order_paste_whatsapp'.i18n()),
            findsOneWidget,
          );
        });
      });

      testWidgets('MaterialsAndTemplatesScreen stock badges [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          await tester.pumpWidget(buildApp(
            home: const MaterialsAndTemplatesScreen(),
            themeMode: themeMode,
          ));
          await pumpUntilFound(tester, find.text('سمن بلدي فاخر'));
          expect(find.text('سمن بلدي فاخر'), findsWidgets);
        });
      });

      testWidgets('HomeDashboardScreen & BusinessDrawer Wave 3 [$modeName 360x740]',
          (tester) async {
        await tester.runAsync(() => seedRichV10Data());
        await runNarrowWithErrorTrap(tester, () async {
          final scaffoldKey = GlobalKey<ScaffoldState>();
          await tester.pumpWidget(buildApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const BusinessDrawer(),
              body: const HomeDashboardScreen(),
            ),
            themeMode: themeMode,
          ));
          await pumpUntilFound(
            tester,
            find.text('pf_home_today_sales'.i18n()),
          );
          await tester.scrollUntilVisible(
            find.text('prep_screen_title'.i18n()),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await pumpAndSettleSafe(tester);
          expect(find.text('prep_screen_title'.i18n()), findsOneWidget);

          // Open BusinessDrawer and verify the DailyPrepAndShoppingScreen entry renders cleanly
          scaffoldKey.currentState!.openDrawer();
          await pumpAndSettleSafe(tester);
          final drawerPrepSub = find.descendant(
            of: find.byType(Drawer),
            matching: find.text('drawer_prep_shopping_sub'.i18n()),
          );
          await tester.scrollUntilVisible(
            drawerPrepSub,
            200,
            scrollable: find.descendant(
              of: find.byType(Drawer),
              matching: find.byType(Scrollable),
            ),
          );
          await pumpAndSettleSafe(tester);
          expect(drawerPrepSub, findsOneWidget);
        });
      });
    }
  });
}
