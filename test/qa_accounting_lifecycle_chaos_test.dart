import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/cashbox/data/repositories/cashbox_repository_impl.dart';
import 'package:mosaed/features/cashbox/data/repositories/daily_closing_repository.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/printing/models/print_options.dart';
import 'package:mosaed/features/printing/services/catalog_pdf_generator.dart';
import 'package:mosaed/features/printing/services/excel_invoice_generator.dart';
import 'package:mosaed/features/printing/services/monthly_report_pdf_generator.dart';
import 'package:mosaed/features/printing/services/pdf_invoice_generator.dart';
import 'package:mosaed/features/products/data/product_ingredient_repository.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/domain/pricing_calculator_service.dart';
import 'package:mosaed/features/reports/domain/monthly_insights_service.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/models/consolidated_shipment.dart';
import 'package:mosaed/models/customer.dart';
import 'package:mosaed/models/daily_closing.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/product_ingredient.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  Future<void> clearAllTables(Database database) async {
    await database.delete('payment_transactions');
    await database.delete('order_items');
    await database.delete('orders');
    await database.delete('shipments');
    await database.delete('customers');
    await database.delete('product_ingredients');
    await database.delete('products');
    await database.delete('expenses');
    await database.delete('daily_closings');
    await database.delete('whatsapp_templates');
  }

  setUpAll(() async {
    await initializeDateFormatting('ar');
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    await PreferencesService.instance.setBusinessMode(
      AppConstants.businessModeProductiveFamily,
    );
    await PreferencesService.instance.setBusinessName('مطبخ ومشغل الأصالة');
    await PreferencesService.instance.setBusinessPhone('771234567');

    // Load real Arabic localization strings for PDF/Excel/Reports
    final arFile = File('i18n/ar.json');
    if (arFile.existsSync()) {
      final decoded = jsonDecode(await arFile.readAsString()) as Map<String, dynamic>;
      final strings = decoded.map((k, v) => MapEntry(k, v.toString()));
      LocalizationHelper.setStrings(strings, 'ar');
    }

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 8,
      onCreate: (database, version) => AppDatabase.instance.createDBForTesting(database),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    AppDatabase.setTestDatabase(db);
    await clearAllTables(db);
  });

  tearDownAll(() async {
    await db.close();
  });

  group('1. Productive Family End-to-End Accounting & Operational Lifecycle', () {
    test('PricingCalculatorService + ProductIngredientRepository across YER, SAR, USD', () async {
      const calculator = PricingCalculatorService();
      final ingredientRepo = ProductIngredientRepository();
      final productRepo = ProductRepositoryImpl();

      // YER product (tracked stock)
      final pYer = Product(
        id: 'prod_yer',
        name: 'كيكة الزعفران',
        category: 'cat_food_sweets',
        unit: 'حبة',
        costPrice: 0,
        sellPrice: 0,
        currency: AppConstants.currencyYer,
        stockQuantity: 5,
        trackStock: true,
        lowStockThreshold: 2,
      );
      await productRepo.createProduct(pYer);
      await ingredientRepo.replaceForProduct(pYer.id, [
        const ProductIngredient(
          id: 'ing_1',
          productId: 'prod_yer',
          name: 'دقيق وزبدة',
          cost: 3200,
          currency: 'YER',
          yieldCount: 4,
        ),
        const ProductIngredient(
          id: 'ing_2',
          productId: 'prod_yer',
          name: 'زعفران وعلبة',
          cost: 1850,
          currency: 'YER',
          yieldCount: 4,
        ),
      ]);
      final fetchedIngs = await ingredientRepo.getByProductId(pYer.id);
      expect(fetchedIngs.length, 2);

      final resYer = calculator.calculate(
        ingredientCosts: fetchedIngs.map((e) => e.cost).toList(),
        yieldCount: 4,
        marginPercent: 50,
        currency: 'YER',
      );
      // batch = 5050, unitCost = 1262.5, rawSell = 1893.75 -> YER rounds to nearest 50 = 1900
      expect(resYer.batchTotalCost, closeTo(5050.0, 0.01));
      expect(resYer.unitCost, closeTo(1262.5, 0.01));
      expect(resYer.suggestedSellPrice, closeTo(1900.0, 0.01));
      expect(resYer.unitProfit, closeTo(637.5, 0.01));

      // SAR product (made-to-order)
      final resSar = calculator.calculate(
        ingredientCosts: [30.0, 15.0],
        yieldCount: 4,
        marginPercent: 35,
        currency: 'SAR',
      );
      // unitCost = 11.25, rawSell = 15.1875 -> SAR rounds to nearest 1 = 15.0
      expect(resSar.suggestedSellPrice, 15.0);

      // USD product
      final resUsd = calculator.calculate(
        ingredientCosts: [10.0, 5.0],
        yieldCount: 4,
        marginPercent: 25,
        currency: 'USD',
      );
      // unitCost = 3.75, rawSell = 4.6875 -> USD rounds to nearest 0.5 = 4.5
      expect(resUsd.suggestedSellPrice, 4.5);
    });

    test('Orders (prepaid/partial/debt/cod), stock clamp, status progression/revert, payments, CashBox vs Dashboard profit', () async {
      final customerRepo = CustomerRepositoryImpl();
      final productRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final expenseRepo = ExpenseRepositoryImpl();
      final shipmentRepo = ShipmentRepositoryImpl();
      final closingRepo = DailyClosingRepository();

      await PreferencesService.instance.setBusinessMode(
        AppConstants.businessModeProductiveFamily,
      );

      final now = DateTime.now();
      final todayMidday = DateTime(now.year, now.month, now.day, 12, 0);
      final yesterday = todayMidday.subtract(const Duration(days: 1));

      // Customers
      final c1 = Customer(id: 'cust_1', name: 'أم محمد', phone: '771000001');
      final c2 = Customer(id: 'cust_2', name: 'أم خالد', phone: '771000002');
      await customerRepo.saveCustomer(c1);
      await customerRepo.saveCustomer(c2);

      // Products: 1 tracked stock (qty=5), 1 made-to-order (trackStock=false)
      final trackedProd = Product(
        id: 'p_tracked',
        name: 'بخور ملكي',
        category: 'cat_perfume_bakhoor',
        unit: 'علبة',
        costPrice: 1000,
        sellPrice: 2000,
        currency: AppConstants.currencyYer,
        stockQuantity: 5,
        trackStock: true,
        lowStockThreshold: 2,
      );
      final mtoProd = Product(
        id: 'p_mto',
        name: 'صينية بسبوسة',
        category: 'cat_food_sweets',
        unit: 'صينية',
        costPrice: 1500,
        sellPrice: 3000,
        currency: AppConstants.currencyYer,
        stockQuantity: 0,
        trackStock: false,
      );
      await productRepo.createProduct(trackedProd);
      await productRepo.createProduct(mtoProd);

      // Order 1: prepaid (2x trackedProd @2000 + deliveryFee 500 - discount 200 = 4300, cost = 2000 + addCost 100 = 2100)
      final o1 = IndividualOrder(
        id: 'ord_1',
        orderNumber: 'PF-001',
        customerId: c1.id,
        customerName: c1.name,
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusPending,
        createdAt: todayMidday,
        paidAmount: 4300,
        additionalCost: 100,
        discount: 200,
        deliveryFee: 500,
        currency: AppConstants.currencyYer,
      );
      final o1Items = [
        OrderItem(
          id: 'oi_1',
          orderId: o1.id,
          productId: trackedProd.id,
          name: trackedProd.name,
          quantity: 2,
          costPrice: 1000,
          sellPrice: 2000,
          currency: AppConstants.currencyYer,
        ),
      ];

      // Order 2: partial (عربون) (1x mtoProd @3000 + 1x trackedProd @2000 = 5000, paid 1500)
      final o2 = IndividualOrder(
        id: 'ord_2',
        orderNumber: 'PF-002',
        customerId: c2.id,
        customerName: c2.name,
        paymentStatus: AppConstants.paymentPartial,
        orderStatus: AppConstants.orderStatusPending,
        createdAt: todayMidday,
        paidAmount: 1500,
        currency: AppConstants.currencyYer,
      );
      final o2Items = [
        OrderItem(
          id: 'oi_2',
          orderId: o2.id,
          productId: mtoProd.id,
          name: mtoProd.name,
          quantity: 1,
          costPrice: 1500,
          sellPrice: 3000,
          currency: AppConstants.currencyYer,
        ),
        OrderItem(
          id: 'oi_3',
          orderId: o2.id,
          productId: trackedProd.id,
          name: trackedProd.name,
          quantity: 1,
          costPrice: 1000,
          sellPrice: 2000,
          currency: AppConstants.currencyYer,
        ),
      ];

      // Order 3: debt (1x mtoProd @3000, paid 0)
      final o3 = IndividualOrder(
        id: 'ord_3',
        orderNumber: 'PF-003',
        customerId: c1.id,
        customerName: c1.name,
        paymentStatus: AppConstants.paymentDebt,
        orderStatus: AppConstants.orderStatusPending,
        createdAt: todayMidday,
        paidAmount: 0,
        currency: AppConstants.currencyYer,
      );
      final o3Items = [
        OrderItem(
          id: 'oi_4',
          orderId: o3.id,
          productId: mtoProd.id,
          name: mtoProd.name,
          quantity: 1,
          costPrice: 1500,
          sellPrice: 3000,
          currency: AppConstants.currencyYer,
        ),
      ];

      // Order 4: cod (1x trackedProd @2000, paid 0)
      final o4 = IndividualOrder(
        id: 'ord_4',
        orderNumber: 'PF-004',
        customerId: c2.id,
        customerName: c2.name,
        paymentStatus: AppConstants.paymentCod,
        orderStatus: AppConstants.orderStatusPending,
        createdAt: todayMidday,
        paidAmount: 0,
        currency: AppConstants.currencyYer,
      );
      final o4Items = [
        OrderItem(
          id: 'oi_5',
          orderId: o4.id,
          productId: trackedProd.id,
          name: trackedProd.name,
          quantity: 1,
          costPrice: 1000,
          sellPrice: 2000,
          currency: AppConstants.currencyYer,
        ),
      ];

      // Atomic stock deduction happens inside OrderRepositoryImpl.saveOrder
      await orderRepo.saveOrder(o1, o1Items);
      await orderRepo.saveOrder(o2, o2Items);
      await orderRepo.saveOrder(o3, o3Items);
      await orderRepo.saveOrder(o4, o4Items);

      // Stock check: 5 - 2 - 1 - 1 = 1
      var fetchedTracked = await productRepo.getProductById(trackedProd.id);
      var fetchedMto = await productRepo.getProductById(mtoProd.id);
      expect(fetchedTracked!.stockQuantity, 1);
      expect(fetchedMto!.stockQuantity, 0);

      // Attempt to deduct 10 units -> clamped to 0, never negative!
      await productRepo.adjustStock(trackedProd.id, -10);
      fetchedTracked = await productRepo.getProductById(trackedProd.id);
      expect(fetchedTracked!.stockQuantity, 0);

      // Status progression via OrdersBloc (pending -> purchased -> ready -> delivered) + Revert
      final ordersBloc = OrdersBloc(repository: orderRepo);
      ordersBloc.add(const LoadOrders());
      await Future.delayed(const Duration(milliseconds: 50));

      final s1 = OrdersBloc.getNextStatus(AppConstants.orderStatusPending);
      expect(s1, AppConstants.orderStatusPurchased);
      final s2 = OrdersBloc.getNextStatus(s1!);
      expect(s2, AppConstants.orderStatusReady);
      final s3 = OrdersBloc.getNextStatus(s2!);
      expect(s3, AppConstants.orderStatusDelivered);

      ordersBloc.add(AdvanceOrderStatusEvent(o1.id, s1));
      await Future.delayed(const Duration(milliseconds: 30));
      ordersBloc.add(AdvanceOrderStatusEvent(o1.id, s2));
      await Future.delayed(const Duration(milliseconds: 30));
      ordersBloc.add(AdvanceOrderStatusEvent(o1.id, s3!));
      await Future.delayed(const Duration(milliseconds: 30));

      var reloadedO1 = await orderRepo.getOrderById(o1.id);
      expect(reloadedO1!.orderStatus, AppConstants.orderStatusDelivered);
      expect(reloadedO1.actualDeliveryDate, isNotNull);

      // Revert status back to ready
      ordersBloc.add(RevertOrderStatusEvent(o1.id, AppConstants.orderStatusReady));
      await Future.delayed(const Duration(milliseconds: 40));
      reloadedO1 = await orderRepo.getOrderById(o1.id);
      expect(reloadedO1!.orderStatus, AppConstants.orderStatusReady);

      // Record payment on o2 (delta = 2000 -> total paid 3500 out of 5000)
      await orderRepo.updatePaymentStatus(o2.id, AppConstants.paymentPartial, 3500);
      final txRows = await db.query(
        'payment_transactions',
        where: 'orderId = ?',
        whereArgs: [o2.id],
        orderBy: 'paidAt ASC',
      );
      expect(txRows.length, 2);
      final amounts =
          txRows.map((r) => (r['amount'] as num).toDouble()).toList();
      expect(amounts, containsAll([1500.0, 2000.0]));

      // Backdate a payment on o3 to yesterday to verify day-level CashBox isolation
      await orderRepo.updatePaymentStatus(o3.id, AppConstants.paymentPartial, 1000);
      await db.update(
        'payment_transactions',
        {'paidAt': yesterday.toIso8601String()},
        where: 'orderId = ?',
        whereArgs: [o3.id],
      );

      // Record Business Expense (800 YER) and Personal Drawing (1200 YER) today
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_biz_1',
          title: 'علب تغليف',
          expenseType: AppConstants.expenseTypeBusiness,
          amount: 800,
          currency: AppConstants.currencyYer,
          expenseDate: todayMidday,
        ),
      );
      await expenseRepo.createExpense(
        Expense(
          id: 'exp_pers_1',
          title: 'سحب مصروف بيت',
          expenseType: AppConstants.expenseTypePersonal,
          amount: 1200,
          currency: AppConstants.currencyYer,
          expenseDate: todayMidday,
        ),
      );

      // Verify CashBoxCubit strict math for today:
      // today cashIn = 4300 (o1) + 1500 (o2) + 2000 (o2 delta) = 7800
      // businessOut = 800, personalOut = 1200
      // netDrawer = 7800 - 800 - 1200 = 5800
      final cashBoxCubit = CashBoxCubit(
        cashBoxRepo: CashBoxRepositoryImpl(),
        expenseRepo: expenseRepo,
        initialDate: todayMidday,
      );
      await cashBoxCubit.loadDate(todayMidday);
      expect(cashBoxCubit.state, isA<CashBoxLoaded>());
      final cbLoaded = cashBoxCubit.state as CashBoxLoaded;
      expect(cbLoaded.summary.cashInYer, closeTo(7800.0, 0.01));
      expect(cbLoaded.summary.businessExpensesYer, closeTo(800.0, 0.01));
      expect(cbLoaded.summary.personalDrawingsYer, closeTo(1200.0, 0.01));
      expect(
        cbLoaded.summary.netDrawerYer,
        closeTo(
          cbLoaded.summary.cashInYer -
              cbLoaded.summary.businessExpensesYer -
              cbLoaded.summary.personalDrawingsYer,
          0.01,
        ),
      );
      expect(cbLoaded.summary.netDrawerYer, closeTo(5800.0, 0.01));

      // Yesterday CashBox should only see o3's 1000 YER
      await cashBoxCubit.previousDay();
      final cbPrev = cashBoxCubit.state as CashBoxLoaded;
      expect(cbPrev.summary.cashInYer, closeTo(1000.0, 0.01));
      expect(cbPrev.summary.netDrawerYer, closeTo(1000.0, 0.01));

      // Verify DashboardBloc: netProfit deducts businessExpenses (800) ONLY, NOT personalDrawings (1200)!
      // Orders total sell: o1=4300, o2=5000, o3=3000, o4=2000 -> 14300
      // Orders total cost: o1=2100, o2=2500, o3=1500, o4=1000 -> 7100
      // Gross profit = 14300 - 7100 = 7200
      // Net profit = 7200 - 800 = 6400 (personal 1200 NOT deducted!)
      final dashboardBloc = DashboardBloc(
        orderRepo: orderRepo,
        shipmentRepo: shipmentRepo,
        customerRepo: customerRepo,
        expenseRepo: expenseRepo,
        productRepo: productRepo,
      );
      dashboardBloc.add(const LoadDashboardData());
      await Future.delayed(const Duration(milliseconds: 80));
      expect(dashboardBloc.state, isA<DashboardLoaded>());
      final dashStats = (dashboardBloc.state as DashboardLoaded).stats;
      expect(dashStats.totalExpensesInYer, closeTo(800.0, 0.01));
      expect(dashStats.personalDrawingsInYer, closeTo(1200.0, 0.01));
      expect(dashStats.netProfitInYer, closeTo(6400.0, 0.01));
      expect(dashStats.todayCashInYer, closeTo(7800.0, 0.01));

      // DailyClosingRepository
      final todayStr = DailyClosingRepository.formatClosingDate(todayMidday);
      await closingRepo.saveClosing(
        DailyClosing(
          id: 'close_1',
          closingDate: todayStr,
          cashInYer: cbLoaded.summary.cashInYer,
          businessExpensesYer: cbLoaded.summary.businessExpensesYer,
          personalDrawingsYer: cbLoaded.summary.personalDrawingsYer,
          ordersCount: 4,
          notes: 'إغلاق يومي ناجح',
        ),
      );
      final fetchedClosing = await closingRepo.getClosingForDate(todayMidday);
      expect(fetchedClosing, isNotNull);
      expect(fetchedClosing!.netDrawerYer, closeTo(5800.0, 0.01));
      expect((await closingRepo.getRecentClosings()).length, 1);

      // MonthlyInsightsService
      final report = await MonthlyInsightsService.instance.generateForMonth(
        now.year,
        now.month,
      );
      expect(report.ordersCount, 4);
      expect(report.totalSalesYer, closeTo(14300.0, 0.01));
      expect(report.businessExpensesYer, closeTo(800.0, 0.01));
      expect(report.personalDrawingsYer, closeTo(1200.0, 0.01));
      expect(report.cashCollectedYer, closeTo(8800.0, 0.01));
      expect(report.topProducts, isNotEmpty);
      expect(report.topCustomers, isNotEmpty);

      // ReorderEvent: update trackedProd sellPrice from 2000 -> 2600, then reorder o1
      await productRepo.updateProduct(trackedProd.copyWith(sellPrice: 2600));
      ordersBloc.add(ReorderEvent(reloadedO1));
      await Future.delayed(const Duration(milliseconds: 60));
      final allAfterReorder = await orderRepo.getAllOrders();
      expect(allAfterReorder.length, 5);
      final reordered = allAfterReorder.firstWhere((o) => o.id != o1.id && o.orderNumber != 'PF-001' && o.orderNumber != 'PF-002' && o.orderNumber != 'PF-003' && o.orderNumber != 'PF-004');
      expect(reordered.items.first.sellPrice, closeTo(2600.0, 0.01));
      expect(reordered.paidAmount, 0.0);
      expect(reordered.paymentStatus, AppConstants.paymentDebt);
      expect(reordered.orderStatus, AppConstants.orderStatusPending);

      await ordersBloc.close();
      await cashBoxCubit.close();
      await dashboardBloc.close();
    });
  });

  group('2. Multi-Currency Commerce & Consolidated Shipments', () {
    test('Mixed YER/SAR/USD orders in SAR shipment: no double-counting in Dashboard, no negative debt on overpayment, cascading delete', () async {
      final orderRepo = OrderRepositoryImpl();
      final shipmentRepo = ShipmentRepositoryImpl();
      final customerRepo = CustomerRepositoryImpl();
      final expenseRepo = ExpenseRepositoryImpl();
      final productRepo = ProductRepositoryImpl();

      // Rates: 1 SAR = 535 YER, 1 USD = 2040 YER
      const shipmentId = 'ship_mc_1';

      // Order A (USD): 1 item cost=10 USD, sell=15 USD. Paid=20 USD (OVERPAYMENT -> debt must be 0!)
      final ordUsd = IndividualOrder(
        id: 'mc_ord_usd',
        orderNumber: 'MC-USD',
        shipmentId: shipmentId,
        paymentStatus: AppConstants.paymentPrepaid,
        paidAmount: 20.0,
        currency: AppConstants.currencyUsd,
        items: [
          OrderItem(
            id: 'mc_oi_1',
            orderId: 'mc_ord_usd',
            name: 'ساعة ذكية',
            quantity: 1,
            costPrice: 10.0,
            sellPrice: 15.0,
            currency: AppConstants.currencyUsd,
          ),
        ],
      );

      // Order B (SAR): 2 items cost=50 SAR, sell=80 SAR -> cost=100 SAR, sell=160 SAR. Paid=100 SAR
      final ordSar = IndividualOrder(
        id: 'mc_ord_sar',
        orderNumber: 'MC-SAR',
        shipmentId: shipmentId,
        paymentStatus: AppConstants.paymentPartial,
        paidAmount: 100.0,
        currency: AppConstants.currencySar,
        items: [
          OrderItem(
            id: 'mc_oi_2',
            orderId: 'mc_ord_sar',
            name: 'عطر فاخر',
            quantity: 2,
            costPrice: 50.0,
            sellPrice: 80.0,
            currency: AppConstants.currencySar,
          ),
        ],
      );

      // Order C (YER, unassigned): cost=5000, sell=8000, paid=8000 -> profit = 3000 YER
      final ordYer = IndividualOrder(
        id: 'mc_ord_yer',
        orderNumber: 'MC-YER',
        shipmentId: null,
        paymentStatus: AppConstants.paymentPrepaid,
        paidAmount: 8000.0,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'mc_oi_3',
            orderId: 'mc_ord_yer',
            name: 'طقم هدايا',
            quantity: 1,
            costPrice: 5000.0,
            sellPrice: 8000.0,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final shipment = ConsolidatedShipment(
        id: shipmentId,
        shipmentNumber: 'SHP-MC-01',
        title: 'شحنة دبي المجمعة',
        transportCost: 20.0,
        transportCostCurrency: AppConstants.currencySar, // 20 * 535 = 10,700 YER
        orders: [ordUsd, ordSar],
      );

      await orderRepo.saveOrder(ordUsd, ordUsd.items);
      await orderRepo.saveOrder(ordSar, ordSar.items);
      await orderRepo.saveOrder(ordYer, ordYer.items);
      await shipmentRepo.saveShipment(shipment, [ordUsd.id, ordSar.id]);

      // Overpayment check
      expect(ordUsd.remainingDebt, 0.0);

      // Expected shipment net profit in YER:
      // USD profit: (15 - 10) * 2040 = 10,200 YER
      // SAR profit: (160 - 100) * 535 = 32,100 YER
      // Transport cost: 20 * 535 = 10,700 YER
      // Shipment net profit = 10,200 + 32,100 - 10,700 = 31,600 YER
      // Unassigned ordYer profit = 3,000 YER
      // Total Dashboard netProfitInYer = 31,600 + 3,000 = 34,600 YER (NO double counting!)
      final dashboardBloc = DashboardBloc(
        orderRepo: orderRepo,
        shipmentRepo: shipmentRepo,
        customerRepo: customerRepo,
        expenseRepo: expenseRepo,
        productRepo: productRepo,
      );
      dashboardBloc.add(const LoadDashboardData());
      await Future.delayed(const Duration(milliseconds: 80));

      final stats = (dashboardBloc.state as DashboardLoaded).stats;
      expect(stats.netProfitInYer, closeTo(34600.0, 0.01));
      // Debt check: ordUsd overpaid -> 0 debt; ordSar debt = (160 - 100) * 535 = 32,100 YER
      expect(stats.totalDebtsInYer, closeTo(32100.0, 0.01));

      // Cascading delete of ordUsd: must delete orders, order_items, AND payment_transactions
      expect(
        (await db.query('payment_transactions', where: 'orderId = ?', whereArgs: [ordUsd.id])).length,
        1,
      );
      await orderRepo.deleteOrder(ordUsd.id);
      expect(await orderRepo.getOrderById(ordUsd.id), isNull);
      expect(
        (await db.query('order_items', where: 'orderId = ?', whereArgs: [ordUsd.id])).isEmpty,
        isTrue,
      );
      expect(
        (await db.query('payment_transactions', where: 'orderId = ?', whereArgs: [ordUsd.id])).isEmpty,
        isTrue,
      );

      await dashboardBloc.close();
    });
  });

  group('3. Real SQLite Upgrade (v5 -> v8) & Legacy/Modern JSON Import', () {
    test('Upgrades genuine v5 DB file to v8, backfills payment_transactions, creates tables & indexes, and imports v1 & v8 JSON', () async {
      final tempDir = await Directory.systemTemp.createTemp('amtr_v5_upgrade_');
      final origDbPath = await getDatabasesPath();
      await databaseFactory.setDatabasesPath(tempDir.path);
      final v5FilePath = p.join(tempDir.path, 'mosaed_local.db');

      // 1. Create a genuine v5 database using singleInstance: false
      final v5Db = await openDatabase(
        v5FilePath,
        version: 5,
        singleInstance: false,
        onCreate: (d, version) async {
          await d.execute('''
            CREATE TABLE exchange_rates (
              id TEXT PRIMARY KEY,
              sarToYer REAL NOT NULL,
              usdToYer REAL NOT NULL,
              updatedAt TEXT NOT NULL
            )
          ''');
          await d.execute('''
            CREATE TABLE customers (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT,
              whatsapp TEXT,
              notes TEXT,
              createdAt TEXT NOT NULL
            )
          ''');
          await d.execute('''
            CREATE TABLE shipments (
              id TEXT PRIMARY KEY,
              shipmentNumber TEXT NOT NULL,
              title TEXT NOT NULL,
              carrierName TEXT,
              trackingNumber TEXT,
              transportCost REAL NOT NULL,
              transportCostCurrency TEXT NOT NULL,
              status TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              expectedDeliveryDate TEXT,
              actualDeliveryDate TEXT,
              notes TEXT
            )
          ''');
          await d.execute('''
            CREATE TABLE orders (
              id TEXT PRIMARY KEY,
              orderNumber TEXT NOT NULL,
              customerId TEXT,
              customerName TEXT,
              shipmentId TEXT,
              paymentStatus TEXT NOT NULL,
              orderStatus TEXT NOT NULL,
              createdAt TEXT NOT NULL,
              expectedDeliveryDate TEXT,
              actualDeliveryDate TEXT,
              debtDueDate TEXT,
              hasDebtReminder INTEGER DEFAULT 0,
              isSyncedWithCalendar INTEGER DEFAULT 0,
              paidAmount REAL NOT NULL,
              additionalCost REAL DEFAULT 0.0,
              discount REAL DEFAULT 0.0,
              deliveryFee REAL DEFAULT 0.0,
              deliveryType TEXT DEFAULT 'pickup',
              deliveryAddress TEXT,
              currency TEXT NOT NULL,
              notes TEXT
            )
          ''');
          await d.execute('''
            CREATE TABLE order_items (
              id TEXT PRIMARY KEY,
              orderId TEXT NOT NULL,
              name TEXT NOT NULL,
              description TEXT,
              quantity INTEGER NOT NULL,
              costPrice REAL NOT NULL,
              sellPrice REAL,
              currency TEXT NOT NULL,
              photos TEXT NOT NULL
            )
          ''');
          await d.execute('''
            CREATE TABLE products (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              category TEXT NOT NULL,
              unit TEXT NOT NULL,
              costPrice REAL NOT NULL DEFAULT 0.0,
              sellPrice REAL NOT NULL DEFAULT 0.0,
              currency TEXT NOT NULL,
              stockQuantity INTEGER DEFAULT 0,
              trackStock INTEGER DEFAULT 0,
              lowStockThreshold INTEGER DEFAULT 3,
              isActive INTEGER DEFAULT 1,
              notes TEXT,
              createdAt TEXT NOT NULL
            )
          ''');
          await d.execute('''
            CREATE TABLE expenses (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              category TEXT NOT NULL,
              amount REAL NOT NULL,
              currency TEXT NOT NULL,
              expenseDate TEXT NOT NULL,
              notes TEXT,
              createdAt TEXT NOT NULL
            )
          ''');

          await d.insert('customers', {
            'id': 'v5_cust_1',
            'name': 'عميل v5',
            'phone': '771111111',
            'createdAt': '2026-01-10T10:00:00.000',
          });
          await d.insert('orders', {
            'id': 'v5_ord_1',
            'orderNumber': 'V5-001',
            'customerId': 'v5_cust_1',
            'customerName': 'عميل v5',
            'paymentStatus': 'partial',
            'orderStatus': 'pending',
            'createdAt': '2026-01-10T10:00:00.000',
            'paidAmount': 2500.0,
            'currency': 'YER',
          });
          await d.insert('expenses', {
            'id': 'v5_exp_1',
            'title': 'مصروف قديم',
            'category': 'exp_cat_materials',
            'amount': 500.0,
            'currency': 'YER',
            'expenseDate': '2026-01-10T11:00:00.000',
            'createdAt': '2026-01-10T11:00:00.000',
          });
        },
      );
      await v5Db.close();

      // 2. Point AppDatabase at tempDir and trigger real v5 -> v8 upgrade
      AppDatabase.setTestDatabase(null);
      final upgradedDb = await AppDatabase.instance.database;

      final verRes = await upgradedDb.rawQuery('PRAGMA user_version;');
      expect(verRes.first.values.first, 12);

      // Verify backfill of payment_transactions
      final backfilled = await upgradedDb.query(
        'payment_transactions',
        where: 'id = ?',
        whereArgs: ['backfill_v5_ord_1'],
      );
      expect(backfilled.length, 1);
      expect((backfilled.first['amount'] as num).toDouble(), 2500.0);

      // Verify new columns: expenses.expenseType, customers.preferences
      final expCols = await upgradedDb.rawQuery('PRAGMA table_info(expenses);');
      expect(expCols.any((c) => c['name'] == 'expenseType'), isTrue);
      final oldExp = await upgradedDb.query('expenses', where: 'id = ?', whereArgs: ['v5_exp_1']);
      expect(oldExp.first['expenseType'], 'business');

      final custCols = await upgradedDb.rawQuery('PRAGMA table_info(customers);');
      expect(custCols.any((c) => c['name'] == 'preferences'), isTrue);

      // Verify new tables
      final tables = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      ))
          .map((r) => r['name'] as String)
          .toSet();
      expect(tables, containsAll(['whatsapp_templates', 'product_ingredients', 'daily_closings', 'payment_transactions']));

      // Verify performance indexes
      final indexes = (await upgradedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index'",
      ))
          .map((r) => r['name'] as String)
          .toSet();
      expect(
        indexes,
        containsAll([
          'idx_order_items_orderId',
          'idx_order_items_productId',
          'idx_orders_status_delivery',
          'idx_orders_customerId',
          'idx_payments_paidAt',
          'idx_expenses_date_type',
          'idx_product_ingredients_productId',
          'idx_daily_closings_date',
        ]),
      );

      // 3. Test legacy v1 JSON import (minimal keys, no v6-v8 tables)
      final legacyV1Json = {
        'version': 1,
        'customers': [
          {
            'id': 'leg_c1',
            'name': 'عميل أرشيفي v1',
            'phone': '772222222',
            'createdAt': '2025-05-01T08:00:00.000',
          }
        ],
        'shipments': [],
        'orders': [
          {
            'id': 'leg_o1',
            'orderNumber': 'LEG-01',
            'customerId': 'leg_c1',
            'customerName': 'عميل أرشيفي v1',
            'paymentStatus': 'debt',
            'orderStatus': 'pending',
            'createdAt': '2025-05-01T08:00:00.000',
            'paidAmount': 0.0,
            'currency': 'YER',
          }
        ],
        'order_items': [
          {
            'id': 'leg_oi1',
            'orderId': 'leg_o1',
            'name': 'صنف قديم',
            'quantity': 1,
            'costPrice': 100.0,
            'sellPrice': 200.0,
            'currency': 'YER',
            'photos': '[]',
          }
        ],
        'exchange_rates': [
          {
            'id': 'default_rates',
            'sarToYer': 535.0,
            'usdToYer': 2040.0,
            'updatedAt': '2025-05-01T08:00:00.000',
          }
        ],
      };
      await AppDatabase.instance.importAllDataFromJson(legacyV1Json);
      final importedOrders = await upgradedDb.query('orders');
      expect(importedOrders.length, 1);
      expect(importedOrders.first['id'], 'leg_o1');

      // 4. Test v8 export & re-import round-trip
      await upgradedDb.insert('whatsapp_templates', {
        'id': 'tpl_1',
        'type': 'ready',
        'tone': 'friendly',
        'title': 'جاهز',
        'body': 'طلبك جاهز',
        'isDefault': 1,
      });
      await upgradedDb.insert('daily_closings', {
        'id': 'dc_1',
        'closingDate': '2026-11-24',
        'cashInYer': 5000.0,
        'businessExpensesYer': 500.0,
        'personalDrawingsYer': 0.0,
        'ordersCount': 2,
        'closedAt': '2026-11-24T22:00:00.000',
      });
      final exportedV8 = await AppDatabase.instance.exportAllDataToJson();
      expect(exportedV8['whatsapp_templates'], hasLength(1));
      expect(exportedV8['daily_closings'], hasLength(1));

      await AppDatabase.instance.importAllDataFromJson(exportedV8);
      expect((await upgradedDb.query('whatsapp_templates')).length, 1);
      expect((await upgradedDb.query('daily_closings')).length, 1);

      // Restore original test DB & databases path
      await AppDatabase.instance.close();
      AppDatabase.setTestDatabase(db);
      await databaseFactory.setDatabasesPath(origDbPath);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('4. Stress, Edge Cases & PDF/Excel Export Verification', () {
    test('Stress test: 300 orders + 900 items hydrated without N+1 in < 2000ms', () async {
      final orderRepo = OrderRepositoryImpl();

      await db.transaction((txn) async {
        for (int i = 0; i < 300; i++) {
          final oid = 'stress_ord_$i';
          await txn.insert('orders', {
            'id': oid,
            'orderNumber': 'ST-$i',
            'customerName': 'عميل ضغط $i',
            'paymentStatus': AppConstants.paymentPrepaid,
            'orderStatus': AppConstants.orderStatusPending,
            'createdAt': DateTime.now().subtract(Duration(minutes: i)).toIso8601String(),
            'paidAmount': 3000.0,
            'currency': AppConstants.currencyYer,
          });
          for (int j = 0; j < 3; j++) {
            await txn.insert('order_items', {
              'id': 'stress_oi_${i}_$j',
              'orderId': oid,
              'name': 'صنف $j',
              'quantity': 1,
              'costPrice': 500.0,
              'sellPrice': 1000.0,
              'currency': AppConstants.currencyYer,
              'photos': '[]',
            });
          }
        }
      });

      final sw = Stopwatch()..start();
      final orders = await orderRepo.getAllOrders();
      sw.stop();

      expect(orders.length, 300);
      expect(orders.first.items.length, 3);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('Edge cases: discount > itemsSell, unpriced items (sellPrice == null), yieldCount == 0', () {
      // 1. Discount larger than itemsSell + deliveryFee -> totalSellPrice >= 0
      final discountedOrder = IndividualOrder(
        id: 'edge_disc',
        orderNumber: 'ED-1',
        deliveryFee: 200,
        discount: 5000,
        items: [
          OrderItem(
            id: 'ed_1',
            orderId: 'edge_disc',
            name: 'بند',
            quantity: 1,
            costPrice: 500,
            sellPrice: 1000,
          ),
        ],
      );
      expect(discountedOrder.totalSellPrice, 0.0);
      expect(discountedOrder.remainingDebt, 0.0);

      // 2. Unpriced items (sellPrice == null)
      final unpricedOrder = IndividualOrder(
        id: 'edge_unpriced',
        orderNumber: 'ED-2',
        items: [
          OrderItem(
            id: 'ed_2',
            orderId: 'edge_unpriced',
            name: 'بند غير مسعر',
            quantity: 2,
            costPrice: 400,
            sellPrice: null,
          ),
          OrderItem(
            id: 'ed_3',
            orderId: 'edge_unpriced',
            name: 'بند مسعر',
            quantity: 1,
            costPrice: 300,
            sellPrice: 600,
          ),
        ],
      );
      expect(unpricedOrder.isFullyPriced, isFalse);
      expect(unpricedOrder.itemsSellOnly, 600.0);
      expect(unpricedOrder.totalCostPrice, 1100.0);

      // 3. yieldCount == 0 in PricingCalculatorService
      const calc = PricingCalculatorService();
      final resZero = calc.calculate(
        ingredientCosts: [1000, 500],
        yieldCount: 0,
        marginPercent: 20,
        currency: 'YER',
      );
      expect(resZero.yieldCount, 1);
      expect(resZero.unitCost.isFinite, isTrue);
      expect(resZero.unitCost, 1500.0);
      expect(resZero.suggestedSellPrice, 1800.0);
    });

    test('PDF (A4, Thermal80, Catalog, MonthlyReport) & Excel generation produce valid binary outputs', () async {
      final sampleOrder = IndividualOrder(
        id: 'pdf_ord_1',
        orderNumber: 'INV-900',
        customerName: 'فاطمة علي',
        paymentStatus: AppConstants.paymentPartial,
        orderStatus: AppConstants.orderStatusReady,
        paidAmount: 2000,
        deliveryFee: 500,
        discount: 200,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'pdf_oi_1',
            orderId: 'pdf_ord_1',
            name: 'كيكة العسل',
            quantity: 2,
            costPrice: 1000,
            sellPrice: 2000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      // A4 PDF (3 columns)
      final a4Bytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: [sampleOrder],
        options: const PrintOptions(
          paperSize: PrintPaperSize.a4,
          columnsPerRow: 3,
        ),
      );
      expect(a4Bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(a4Bytes.take(4)), '%PDF');

      // Thermal 80mm PDF
      final thermalBytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: [sampleOrder],
        options: const PrintOptions(
          paperSize: PrintPaperSize.thermal80,
          columnsPerRow: 1,
        ),
      );
      expect(thermalBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(thermalBytes.take(4)), '%PDF');

      // Catalog PDF
      final catalogBytes = await CatalogPdfGenerator.generateCatalogPdf([
        Product(
          id: 'cat_p1',
          name: 'معمول تمر',
          category: 'cat_food_sweets',
          unit: 'علبة',
          costPrice: 1200,
          sellPrice: 2500,
          currency: AppConstants.currencyYer,
          isActive: true,
        ),
      ]);
      expect(catalogBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(catalogBytes.take(4)), '%PDF');

      // Monthly Report PDF
      final now = DateTime.now();
      final report = await MonthlyInsightsService.instance.generateForMonth(
        now.year,
        now.month,
      );
      final monthlyBytes = await MonthlyReportPdfGenerator.generateMonthlyPdf(
        report: report,
        currencyCode: AppConstants.currencyYer,
      );
      expect(monthlyBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(monthlyBytes.take(4)), '%PDF');

      // Excel Invoice Export (XLSX is a ZIP archive starting with 'PK')
      final excelBytes = ExcelInvoiceGenerator.generateInvoicesExcel(
        orders: [sampleOrder],
        title: 'تقرير فواتير الاختبار',
      );
      expect(excelBytes.length, greaterThan(1000));
      expect(String.fromCharCodes(excelBytes.take(2)), 'PK');
    });
  });
}
