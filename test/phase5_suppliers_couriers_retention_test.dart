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
import 'package:mosaed/features/cashbox/data/repositories/cashbox_repository_impl.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/couriers/data/repositories/courier_repository_impl.dart';
import 'package:mosaed/features/couriers/presentation/bloc/couriers_bloc.dart';
import 'package:mosaed/features/couriers/presentation/screens/courier_details_screen.dart';
import 'package:mosaed/features/couriers/presentation/screens/couriers_list_screen.dart';
import 'package:mosaed/features/couriers/presentation/widgets/add_edit_courier_sheet.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/domain/smart_reorder_service.dart';
import 'package:mosaed/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:mosaed/features/customers/presentation/screens/customer_details_screen.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/screens/home_dashboard_screen.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/expenses/presentation/bloc/expenses_bloc.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/orders/presentation/screens/order_details_screen.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/products/presentation/bloc/products_bloc.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/features/shipments/presentation/bloc/shipments_bloc.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_ledger_repository.dart';
import 'package:mosaed/features/suppliers/data/repositories/supplier_repository_impl.dart';
import 'package:mosaed/features/suppliers/presentation/bloc/suppliers_bloc.dart';
import 'package:mosaed/features/suppliers/presentation/screens/supplier_details_screen.dart';
import 'package:mosaed/features/suppliers/presentation/widgets/supplier_transaction_sheet.dart';
import 'package:mosaed/features/whatsapp/domain/whatsapp_template_engine.dart';
import 'package:mosaed/models/courier.dart';
import 'package:mosaed/models/customer.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';
import 'package:mosaed/models/supplier.dart';
import 'package:mosaed/models/supplier_transaction.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Widget _buildPhase5Harness({
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
          supportedLocales: AppLocalizationsDelegate.supportedLocales,
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            const AppLocalizationsDelegate(),
            LocalJsonLocalization.delegate,
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
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 300));
}

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
      return e.toString();
    }).join('\n---\n');
    fail('Captured ${errors.length} FlutterError(s) in $contextLabel:\n$summary');
  }
}

Future<Database> _openFreshV11Db() async {
  final db = await openDatabase(
    inMemoryDatabasePath,
    version: 11,
    onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
  );
  AppDatabase.setTestDatabase(db);
  return db;
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
      'business_mode': AppConstants.businessModeProductiveFamily,
      'business_name': 'مطبخ البركة المنزلي',
      'business_phone': '+967 771122334',
      'multi_currency_enabled': true,
      'default_currency': AppConstants.currencyYer,
      'locale_code': 'ar',
    });
    await PreferencesService.instance.init();
    await LocalizationHelper.load('ar');
  });

  setUp(() async {
    db = await _openFreshV11Db();
    await CurrencyService.instance.init();
  });

  tearDown(() async {
    await db.close();
    AppDatabase.setTestDatabase(null);
  });

  group('a) DB v11 Schema, JSON Backup/Restore Round-Trip & DemoData v11', () {
    test(
      'DB v11 creates new tables and columns and round-trips cleanly via JSON export/import',
      () async {
        // Verify tables exist
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table'",
        );
        final tableNames = tables.map((r) => r['name'] as String).toSet();
        expect(tableNames, contains('supplier_transactions'));
        expect(tableNames, contains('couriers'));
        expect(tableNames, contains('courier_settlements'));

        // Verify new columns on orders, customers, products
        final orderCols = (await db.rawQuery('PRAGMA table_info(orders)'))
            .map((r) => r['name'] as String)
            .toSet();
        expect(
          orderCols,
          containsAll([
            'courierId',
            'courierStatus',
            'courierFee',
            'isSettledWithCourier',
          ]),
        );

        final custCols = (await db.rawQuery('PRAGMA table_info(customers)'))
            .map((r) => r['name'] as String)
            .toSet();
        expect(custCols, contains('returnCount'));

        final prodCols = (await db.rawQuery('PRAGMA table_info(products)'))
            .map((r) => r['name'] as String)
            .toSet();
        expect(prodCols, contains('reorderCycleDays'));

        // Seed records across v11 tables & columns
        final supplierRepo = SupplierRepositoryImpl();
        final ledgerRepo = SupplierLedgerRepository();
        final courierRepo = CourierRepositoryImpl();
        final customerRepo = CustomerRepositoryImpl();
        final productRepo = ProductRepositoryImpl();

        await supplierRepo.createSupplier(
          Supplier(id: 'sup_v11', name: 'مورد النسخ الاحتياطي'),
        );
        await ledgerRepo.recordTransaction(
          SupplierTransaction(
            id: 'stx_v11',
            supplierId: 'sup_v11',
            type: AppConstants.supplierTxPurchaseCredit,
            amount: 75000,
            currency: AppConstants.currencyYer,
            notes: 'شراء آجل اختباري',
          ),
          supplierName: 'مورد النسخ الاحتياطي',
        );

        final courier = Courier(
          id: 'cur_v11',
          name: 'مندوب النسخ الاحتياطي',
          phone: '+967770001122',
          defaultFee: 1500,
          currency: AppConstants.currencyYer,
        );
        await courierRepo.saveCourier(courier);

        await customerRepo.saveCustomer(
          Customer(id: 'cust_v11', name: 'عميل مرتجعات', returnCount: 3),
        );
        await productRepo.createProduct(
          Product(
            id: 'prod_v11',
            name: 'بخور أسبوعي',
            sellPrice: 25000,
            reorderCycleDays: 14,
          ),
        );

        await db.insert('courier_settlements', {
          'id': 'cset_v11',
          'courierId': 'cur_v11',
          'orderCount': 2,
          'collectedCashYer': 50000.0,
          'deliveryFeesYer': 3000.0,
          'returnFeesYer': 0.0,
          'netRemittedYer': 47000.0,
          'notes': 'تسوية اختبارية',
          'settledAt': DateTime.now().toIso8601String(),
        });

        // Export JSON
        final exported = await AppDatabase.instance.exportAllDataToJson();
        expect((exported['supplier_transactions'] as List).length, 1);
        expect((exported['couriers'] as List).length, 1);
        expect((exported['courier_settlements'] as List).length, 1);

        // Wipe and import into fresh DB
        await db.close();
        db = await _openFreshV11Db();
        await AppDatabase.instance.importAllDataFromJson(exported);

        final restoredSuppliersTx = await ledgerRepo.getTransactions('sup_v11');
        expect(restoredSuppliersTx.length, 1);
        expect(restoredSuppliersTx.first.amount, 75000);

        final restoredCourier = await courierRepo.getCourierById('cur_v11');
        expect(restoredCourier, isNotNull);
        expect(restoredCourier!.name, 'مندوب النسخ الاحتياطي');

        final restoredSettlements = await courierRepo.getSettlements('cur_v11');
        expect(restoredSettlements.length, 1);
        expect(restoredSettlements.first.netRemittedYer, 47000.0);

        final restoredCustomer = await customerRepo.getCustomerById('cust_v11');
        expect(restoredCustomer!.returnCount, 3);

        final restoredProduct = await productRepo.getProductById('prod_v11');
        expect(restoredProduct!.reorderCycleDays, 14);
      },
    );

    test(
      'DemoDataService v11 seeds couriers, supplier_transactions, returnCount, reorderCycleDays and cleans all on removeDemoData()',
      () async {
        final stats = await DemoDataService.instance.generateDemoData();
        expect(stats.hasDemoData, isTrue);

        final couriers = await db.query('couriers');
        expect(couriers.length, 2);

        final supTxs = await db.query('supplier_transactions');
        expect(supTxs.length, 2);

        final flaggedCusts = await db.query(
          'customers',
          where: 'returnCount >= 2',
        );
        expect(flaggedCusts.length, greaterThanOrEqualTo(1));

        final cycleProds = await db.query(
          'products',
          where: 'reorderCycleDays = 7',
        );
        expect(cycleProds.length, greaterThanOrEqualTo(1));

        // Clean demo data
        final deleted = await DemoDataService.instance.removeDemoData();
        expect(deleted, greaterThan(0));
        expect((await db.query('couriers')).isEmpty, isTrue);
        expect((await db.query('supplier_transactions')).isEmpty, isTrue);
        expect((await db.query('courier_settlements')).isEmpty, isTrue);
      },
    );
  });

  group('b) SupplierLedgerRepository & CashBox Payables Integration', () {
    test(
      'Credit purchase vs cash purchase vs payment math and CashBox totalSupplierPayablesYer',
      () async {
        final supplierRepo = SupplierRepositoryImpl();
        final ledgerRepo = SupplierLedgerRepository();
        final cashBoxRepo = CashBoxRepositoryImpl();
        final now = DateTime.now();

        final supplier = Supplier(
          id: 'sup_1',
          name: 'مورد العطور والعود',
          phone: '+967771112223',
        );
        await supplierRepo.createSupplier(supplier);

        // 1) Credit purchase: 100,000 YER -> increases payable balance, does NOT deduct CashBox
        await ledgerRepo.recordTransaction(
          SupplierTransaction(
            id: 'tx_credit_1',
            supplierId: supplier.id,
            type: AppConstants.supplierTxPurchaseCredit,
            amount: 100000,
            currency: AppConstants.currencyYer,
            txDate: now,
          ),
          supplierName: supplier.name,
        );

        var summary = await ledgerRepo.getBalanceSummary(supplier.id);
        expect(summary.totalCreditPurchasesYer, 100000);
        expect(summary.totalCashPurchasesYer, 0);
        expect(summary.totalPaymentsYer, 0);
        expect(summary.payableBalanceYer, 100000);

        var cashBox = await cashBoxRepo.getDailySummary(now);
        expect(cashBox.businessExpensesYer, 0);
        expect(cashBox.totalSupplierPayablesYer, 100000);

        // 2) Cash purchase: 30,000 YER -> deducts CashBox as business expense, does NOT increase payable balance
        await ledgerRepo.recordTransaction(
          SupplierTransaction(
            id: 'tx_cash_1',
            supplierId: supplier.id,
            type: AppConstants.supplierTxPurchaseCash,
            amount: 30000,
            currency: AppConstants.currencyYer,
            txDate: now,
          ),
          supplierName: supplier.name,
        );

        summary = await ledgerRepo.getBalanceSummary(supplier.id);
        expect(summary.totalCashPurchasesYer, 30000);
        expect(summary.payableBalanceYer, 100000);

        cashBox = await cashBoxRepo.getDailySummary(now);
        expect(cashBox.businessExpensesYer, 30000);
        expect(cashBox.totalSupplierPayablesYer, 100000);

        // 3) Payment: 40,000 YER -> reduces payable balance to 60,000 & deducts CashBox (+40,000 expense => 70,000 total)
        await ledgerRepo.recordTransaction(
          SupplierTransaction(
            id: 'tx_pay_1',
            supplierId: supplier.id,
            type: AppConstants.supplierTxPayment,
            amount: 40000,
            currency: AppConstants.currencyYer,
            txDate: now,
          ),
          supplierName: supplier.name,
        );

        summary = await ledgerRepo.getBalanceSummary(supplier.id);
        expect(summary.totalPaymentsYer, 40000);
        expect(summary.payableBalanceYer, 60000);
        expect(await ledgerRepo.getTotalPayablesYer(), 60000);

        cashBox = await cashBoxRepo.getDailySummary(now);
        expect(cashBox.businessExpensesYer, 70000);
        expect(cashBox.totalSupplierPayablesYer, 60000);
      },
    );
  });

  group('c) CourierRepositoryImpl Full COD & RTO Custody & Settlement Lifecycle', () {
    test(
      'Assign orders -> mark delivered (payment_transactions delta) -> mark returned (restoreStock + returnCount) -> settleCourier (settlement + exp_cat_delivery)',
      () async {
        final courierRepo = CourierRepositoryImpl();
        final orderRepo = OrderRepositoryImpl();
        final productRepo = ProductRepositoryImpl();
        final customerRepo = CustomerRepositoryImpl();

        final customer = Customer(
          id: 'cust_cod',
          name: 'عميل توصيل',
          phone: '+967772223334',
          returnCount: 0,
        );
        await customerRepo.saveCustomer(customer);

        final product = Product(
          id: 'prod_cod',
          name: 'معمول تمر فاخر',
          costPrice: 5000,
          sellPrice: 10000,
          currency: AppConstants.currencyYer,
          trackStock: true,
          stockQuantity: 10,
        );
        await productRepo.createProduct(product);

        final courier = Courier(
          id: 'courier_1',
          name: 'خالد السريع',
          phone: '+967770009988',
          defaultFee: 1500,
          currency: AppConstants.currencyYer,
        );
        await courierRepo.saveCourier(courier);

        // Order 1: COD 20,000 YER (2 units), unpaid before dispatch
        final order1 = IndividualOrder(
          id: 'ord_cod_1',
          orderNumber: '5001',
          customerId: customer.id,
          customerName: customer.name,
          paymentStatus: AppConstants.paymentCod,
          orderStatus: AppConstants.orderStatusReady,
          paidAmount: 0,
          currency: AppConstants.currencyYer,
        );
        final item1 = OrderItem(
          id: 'oi_cod_1',
          orderId: order1.id,
          productId: product.id,
          name: product.name,
          quantity: 2,
          costPrice: 5000,
          sellPrice: 10000,
          currency: AppConstants.currencyYer,
        );
        await orderRepo.saveOrder(order1, [item1]);

        // Order 2: COD 30,000 YER (3 units) -> will be returned!
        final order2 = IndividualOrder(
          id: 'ord_cod_2',
          orderNumber: '5002',
          customerId: customer.id,
          customerName: customer.name,
          paymentStatus: AppConstants.paymentCod,
          orderStatus: AppConstants.orderStatusReady,
          paidAmount: 0,
          currency: AppConstants.currencyYer,
        );
        final item2 = OrderItem(
          id: 'oi_cod_2',
          orderId: order2.id,
          productId: product.id,
          name: product.name,
          quantity: 3,
          costPrice: 5000,
          sellPrice: 10000,
          currency: AppConstants.currencyYer,
        );
        await orderRepo.saveOrder(order2, [item2]);

        // Stock after creating 2+3=5 units should be 5
        var freshProd = await productRepo.getProductById(product.id);
        expect(freshProd!.stockQuantity, 5);

        // 1) Assign both orders to courier
        await courierRepo.assignOrdersToCourier(
          courierId: courier.id,
          orderIds: [order1.id, order2.id],
          defaultFee: 1500,
        );

        var summary = await courierRepo.getCustodySummary(courier);
        expect(summary.activeOrdersCount, 2);
        expect(summary.expectedCollectYer, 50000);

        // 2) Mark order1 delivered (collected 20,000, delivery fee 1,500)
        final loadedOrder1 = (await orderRepo.getOrderById(order1.id))!;
        await courierRepo.markOrderDeliveredByCourier(
          order: loadedOrder1,
          collectedAmount: 20000,
          courierFee: 1500,
        );

        final payTxs = await db.query(
          'payment_transactions',
          where: 'orderId = ?',
          whereArgs: [order1.id],
        );
        expect(payTxs.length, 1);
        expect((payTxs.first['amount'] as num).toDouble(), 20000);
        expect(
          (payTxs.first['notes'] as String).startsWith('courier_cod:'),
          isTrue,
        );

        // 3) Mark order2 returned (restoreStock: true, returnFee: 500)
        final loadedOrder2 = (await orderRepo.getOrderById(order2.id))!;
        await courierRepo.markOrderReturnedByCourier(
          order: loadedOrder2,
          restoreStock: true,
          returnFee: 500,
        );

        // Stock restored by 3 units: 5 -> 8
        freshProd = await productRepo.getProductById(product.id);
        expect(freshProd!.stockQuantity, 8);

        // Customer returnCount incremented: 0 -> 1
        final freshCust = await customerRepo.getCustomerById(customer.id);
        expect(freshCust!.returnCount, 1);
        expect(freshCust.hasRepeatRefusals, isTrue);

        // Custody summary before settlement: collected 20,000 - deliveryFee 1,500 - returnFee 500 = 18,000 net due
        summary = await courierRepo.getCustodySummary(courier);
        expect(summary.deliveredUnsettledCount, 1);
        expect(summary.returnedUnsettledCount, 1);
        expect(summary.collectedCashYer, 20000);
        expect(summary.deliveryFeesYer, 1500);
        expect(summary.returnFeesYer, 500);
        expect(summary.netDueFromCourierYer, 18000);

        // 4) Settle courier
        final settlement = await courierRepo.settleCourier(
          courier: courier,
          notes: 'تصفية نهاية اليوم',
        );
        expect(settlement.orderCount, 2);
        expect(settlement.collectedCashYer, 20000);
        expect(settlement.deliveryFeesYer, 1500);
        expect(settlement.returnFeesYer, 500);
        expect(settlement.netRemittedYer, 18000);

        // Orders marked isSettledWithCourier = 1
        final settledOrder1 = (await orderRepo.getOrderById(order1.id))!;
        final settledOrder2 = (await orderRepo.getOrderById(order2.id))!;
        expect(settledOrder1.isSettledWithCourier, isTrue);
        expect(settledOrder2.isSettledWithCourier, isTrue);

        // Business expense logged under exp_cat_delivery for 2,000 YER (1500 + 500)
        final deliveryExpenses = await db.query(
          'expenses',
          where: 'category = ?',
          whereArgs: ['exp_cat_delivery'],
        );
        expect(deliveryExpenses.length, 1);
        expect((deliveryExpenses.first['amount'] as num).toDouble(), 2000);

        // Unsettled orders should now be empty
        final remaining = await courierRepo.getCourierOrders(
          courier.id,
          unsettledOnly: true,
        );
        expect(remaining, isEmpty);
      },
    );
  });

  group('d) SmartReorderService & All 6 Phase 5 WhatsAppTemplateEngine Helpers', () {
    test('getDueReorderNudges & computeDebtAging return accurate results', () async {
      final customerRepo = CustomerRepositoryImpl();
      final productRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final service = SmartReorderService();
      final now = DateTime.now();

      final c1 = Customer(id: 'c_nudge_1', name: 'أم محمد');
      final c2 = Customer(id: 'c_nudge_2', name: 'أبو علي');
      await customerRepo.saveCustomer(c1);
      await customerRepo.saveCustomer(c2);

      final prod = Product(
        id: 'p_cycle_7',
        name: 'قهوة يمنية مختصة',
        sellPrice: 12000,
        reorderCycleDays: 7,
      );
      await productRepo.createProduct(prod);

      // c1 delivered 12 days ago -> overdue by 5 days -> DUE
      final ord1 = IndividualOrder(
        id: 'o_nudge_1',
        orderNumber: '7001',
        customerId: c1.id,
        customerName: c1.name,
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusDelivered,
        createdAt: now.subtract(const Duration(days: 13)),
        actualDeliveryDate: now.subtract(const Duration(days: 12)),
        paidAmount: 12000,
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(ord1, [
        OrderItem(
          id: 'oi_n1',
          orderId: ord1.id,
          productId: prod.id,
          name: prod.name,
          quantity: 1,
          costPrice: 7000,
          sellPrice: 12000,
          currency: AppConstants.currencyYer,
        ),
      ]);

      // c2 delivered 3 days ago -> NOT due yet
      final ord2 = IndividualOrder(
        id: 'o_nudge_2',
        orderNumber: '7002',
        customerId: c2.id,
        customerName: c2.name,
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusDelivered,
        createdAt: now.subtract(const Duration(days: 3)),
        actualDeliveryDate: now.subtract(const Duration(days: 3)),
        paidAmount: 12000,
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(ord2, [
        OrderItem(
          id: 'oi_n2',
          orderId: ord2.id,
          productId: prod.id,
          name: prod.name,
          quantity: 1,
          costPrice: 7000,
          sellPrice: 12000,
          currency: AppConstants.currencyYer,
        ),
      ]);

      final nudges = await service.getDueReorderNudges(now: now, limit: 3);
      expect(nudges.length, 1);
      expect(nudges.first.customer.id, c1.id);
      expect(nudges.first.product.id, prod.id);
      expect(nudges.first.daysSinceLastOrder, 12);
      expect(nudges.first.overdueDays, 5);

      // Debt aging test
      final unpaidOld = IndividualOrder(
        id: 'o_debt_1',
        orderNumber: '8001',
        customerId: c1.id,
        paymentStatus: AppConstants.paymentDebt,
        orderStatus: AppConstants.orderStatusDelivered,
        createdAt: now.subtract(const Duration(days: 20)),
        debtDueDate: now.subtract(const Duration(days: 10)),
        paidAmount: 5000,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi_d1',
            orderId: 'o_debt_1',
            name: 'عسل',
            quantity: 1,
            costPrice: 10000,
            sellPrice: 20000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );
      final aging = service.computeDebtAging([unpaidOld], now: now);
      expect(aging.hasOverdueDebt, isTrue);
      expect(aging.unpaidOrdersCount, 1);
      expect(aging.remainingDebtYer, 15000);
      expect(aging.oldestUnpaidDays, 10);
    });

    test('All 6 new Phase 5 WhatsAppTemplateEngine helpers produce valid messages', () {
      final sampleOrder = IndividualOrder(
        id: 'ord_wa',
        orderNumber: '9001',
        customerName: 'سارة علي',
        paymentStatus: AppConstants.paymentCod,
        orderStatus: AppConstants.orderStatusReady,
        deliveryAddress: 'شارع حدة - صنعاء',
        paidAmount: 0,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi_wa_1',
            orderId: 'ord_wa',
            name: 'بخور عرائسي',
            quantity: 2,
            costPrice: 15000,
            sellPrice: 25000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final msg1 = WhatsAppTemplateEngine.buildSupplierPaymentReceiptMessage(
        supplierName: 'مؤسسة الروضة',
        paidAmount: 50000,
        currency: AppConstants.currencyYer,
        remainingBalanceYer: 25000,
      );
      expect(msg1, contains('مؤسسة الروضة'));
      expect(msg1, contains('50,000'));
      expect(msg1, contains('25,000'));

      final msg2 = WhatsAppTemplateEngine.buildSupplierStatementMessage(
        supplierName: 'مؤسسة الروضة',
        totalPurchasesYer: 150000,
        totalPaymentsYer: 100000,
        balanceYer: 50000,
      );
      expect(msg2, contains('مؤسسة الروضة'));
      expect(msg2, contains('150,000'));
      expect(msg2, contains('50,000'));

      final msg3 = WhatsAppTemplateEngine.buildCourierDispatchSheetMessage(
        courierName: 'أحمد للتوصيل',
        orders: [sampleOrder],
      );
      expect(msg3, contains('أحمد للتوصيل'));
      expect(msg3, contains('#9001'));
      expect(msg3, contains('شارع حدة - صنعاء'));

      final msg4 = WhatsAppTemplateEngine.buildCourierSettlementReceiptMessage(
        courierName: 'أحمد للتوصيل',
        deliveredCount: 4,
        returnedCount: 1,
        collectedCashYer: 80000,
        deliveryFeesYer: 6000,
        returnFeesYer: 1000,
        netRemittedYer: 73000,
      );
      expect(msg4, contains('أحمد للتوصيل'));
      expect(msg4, contains('73,000'));

      final msg5 = WhatsAppTemplateEngine.buildPreDispatchCodConfirmMessage(
        sampleOrder,
      );
      expect(msg5, contains('سارة علي'));
      expect(msg5, contains('#9001'));
      expect(msg5, contains('تأكيد'));

      final msg6 = WhatsAppTemplateEngine.buildSmartReorderNudgeMessage(
        customerName: 'سارة علي',
        productName: 'بخور عرائسي',
        daysSinceLastOrder: 14,
      );
      expect(msg6, contains('سارة علي'));
      expect(msg6, contains('بخور عرائسي'));
      expect(msg6, contains('14'));
    });
  });

  group('e) Narrow-Screen (360x740) Light & Dark Widget Overflow Tests', () {
    late Courier testCourier;
    late Supplier testSupplier;
    late Customer testCustomer;
    late IndividualOrder testCodOrder;

    Future<void> seedWidgetData() async {
      final courierRepo = CourierRepositoryImpl();
      final supplierRepo = SupplierRepositoryImpl();
      final ledgerRepo = SupplierLedgerRepository();
      final customerRepo = CustomerRepositoryImpl();
      final productRepo = ProductRepositoryImpl();
      final orderRepo = OrderRepositoryImpl();
      final now = DateTime.now();

      testCourier = Courier(
        id: 'w_courier_1',
        name: 'أحمد السريع لتوصيل الطرود',
        phone: '+967771234567',
        whatsapp: '+967771234567',
        defaultFee: 1500,
        currency: AppConstants.currencyYer,
        notes: 'توصيل أحياء المدينة',
      );
      await courierRepo.saveCourier(testCourier);

      testSupplier = Supplier(
        id: 'w_sup_1',
        name: 'مؤسسة الروضة للمواد الخام والبهارات',
        phone: '+967772233445',
        whatsapp: '+967772233445',
        category: 'sup_cat_materials',
      );
      await supplierRepo.createSupplier(testSupplier);
      await ledgerRepo.recordTransaction(
        SupplierTransaction(
          id: 'w_stx_1',
          supplierId: testSupplier.id,
          type: AppConstants.supplierTxPurchaseCredit,
          amount: 120000,
          currency: AppConstants.currencyYer,
          notes: 'فاتورة خامات آجل',
          txDate: now.subtract(const Duration(days: 3)),
        ),
        supplierName: testSupplier.name,
      );
      await ledgerRepo.recordTransaction(
        SupplierTransaction(
          id: 'w_stx_2',
          supplierId: testSupplier.id,
          type: AppConstants.supplierTxPayment,
          amount: 45000,
          currency: AppConstants.currencyYer,
          notes: 'دفعة سداد أولى',
          txDate: now.subtract(const Duration(days: 1)),
        ),
        supplierName: testSupplier.name,
      );

      testCustomer = Customer(
        id: 'w_cust_1',
        name: 'عائشة أحمد الأكوع',
        phone: '+967779900112',
        whatsapp: '+967779900112',
        returnCount: 2,
      );
      await customerRepo.saveCustomer(testCustomer);

      final prod = Product(
        id: 'w_prod_1',
        name: 'بخور عدني عرائسي فاخر',
        costPrice: 20000,
        sellPrice: 35000,
        currency: AppConstants.currencyYer,
        reorderCycleDays: 7,
      );
      await productRepo.createProduct(prod);

      // Delivered order 10 days ago with unpaid debt -> triggers BOTH Smart Reorder Card AND Debt Aging badge!
      final deliveredOldOrder = IndividualOrder(
        id: 'w_ord_delivered',
        orderNumber: '9101',
        customerId: testCustomer.id,
        customerName: testCustomer.name,
        paymentStatus: AppConstants.paymentDebt,
        orderStatus: AppConstants.orderStatusDelivered,
        createdAt: now.subtract(const Duration(days: 12)),
        actualDeliveryDate: now.subtract(const Duration(days: 10)),
        debtDueDate: now.subtract(const Duration(days: 8)),
        paidAmount: 10000,
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(deliveredOldOrder, [
        OrderItem(
          id: 'w_oi_1',
          orderId: deliveredOldOrder.id,
          productId: prod.id,
          name: prod.name,
          quantity: 1,
          costPrice: 20000,
          sellPrice: 35000,
          currency: AppConstants.currencyYer,
        ),
      ]);

      final prod2 = Product(
        id: 'w_prod_2',
        name: 'عسل سدر دوعني ملكي',
        costPrice: 30000,
        sellPrice: 45000,
        currency: AppConstants.currencyYer,
      );
      await productRepo.createProduct(prod2);

      // Active COD order assigned to courier -> shows pre-dispatch COD button in OrderDetailsScreen & unsettled order in CourierDetailsScreen
      testCodOrder = IndividualOrder(
        id: 'w_ord_cod',
        orderNumber: '9102',
        customerId: testCustomer.id,
        customerName: testCustomer.name,
        paymentStatus: AppConstants.paymentCod,
        orderStatus: AppConstants.orderStatusReady,
        deliveryAddress: 'حي حدة - جولة المصباحي',
        paidAmount: 0,
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(testCodOrder, [
        OrderItem(
          id: 'w_oi_2',
          orderId: testCodOrder.id,
          productId: prod2.id,
          name: prod2.name,
          quantity: 2,
          costPrice: 30000,
          sellPrice: 45000,
          currency: AppConstants.currencyYer,
        ),
      ]);
      await courierRepo.assignOrdersToCourier(
        courierId: testCourier.id,
        orderIds: [testCodOrder.id],
        defaultFee: 1500,
      );
    }

    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      final themeLabel = themeMode == ThemeMode.light ? 'Light' : 'Dark';

      testWidgets(
        'All 8 Phase 5 screens & sheets render with ZERO overflow at 360x740 [$themeLabel]',
        (WidgetTester tester) async {
          tester.view.physicalSize = const Size(360, 740);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.runAsync(seedWidgetData);

          final screens = <(String, Widget)>[
            ('CouriersListScreen', const CouriersListScreen()),
            ('CourierDetailsScreen', CourierDetailsScreen(courier: testCourier)),
            (
              'AddEditCourierSheet',
              Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AddEditCourierSheet(courierToEdit: testCourier),
                  ),
                ),
              ),
            ),
            ('SupplierDetailsScreen', SupplierDetailsScreen(supplier: testSupplier)),
            (
              'SupplierTransactionSheet',
              Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SupplierTransactionSheet(
                      supplierId: testSupplier.id,
                      supplierName: testSupplier.name,
                      isPayment: false,
                    ),
                  ),
                ),
              ),
            ),
            ('OrderDetailsScreen', OrderDetailsScreen(orderId: testCodOrder.id)),
            (
              'CustomerDetailsScreen',
              CustomerDetailsScreen(initialCustomer: testCustomer),
            ),
            ('HomeDashboardScreen', const HomeDashboardScreen()),
          ];

          for (final entry in screens) {
            final label = '${entry.$1} [$themeLabel 360x740]';
            final errors = await _captureFlutterErrors(() async {
              await _pumpReady(
                tester,
                _buildPhase5Harness(
                  themeMode: themeMode,
                  child: entry.$2,
                ),
              );

              if (entry.$1 == 'OrderDetailsScreen') {
                expect(
                  find.text('order_pre_dispatch_cod_btn'.i18n()),
                  findsOneWidget,
                );
              }

              // Scroll to catch any off-screen layout issues (and bring Smart Re-Order Card into viewport)
              final scrollables = find.byType(Scrollable);
              if (entry.$1 == 'HomeDashboardScreen') {
                await tester.scrollUntilVisible(
                  find.text('home_smart_reorder_title'.i18n()),
                  250,
                  scrollable: scrollables.first,
                );
                await tester.pump(const Duration(milliseconds: 200));
                expect(
                  find.text('home_smart_reorder_title'.i18n()),
                  findsOneWidget,
                );
                expect(
                  find.text('home_smart_reorder_wa_btn'.i18n()),
                  findsOneWidget,
                );
                expect(
                  find.text('home_smart_reorder_repeat_btn'.i18n()),
                  findsOneWidget,
                );
              } else if (scrollables.evaluate().isNotEmpty) {
                await tester.drag(scrollables.first, const Offset(0, -350));
                await tester.pump(const Duration(milliseconds: 200));
              }
            });

            _assertNoFlutterErrors(errors, label);
          }
        },
      );
    }
  });
}
