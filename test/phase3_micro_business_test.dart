import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/customers/domain/customer_loyalty_helper.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:mosaed/features/printing/services/monthly_report_pdf_generator.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/reports/domain/monthly_insights_service.dart';
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
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    await PreferencesService.instance.setBusinessName('مطبخ أم محمد');
    await PreferencesService.instance.setBusinessPhone('771234567');

    LocalizationHelper.setStrings({
      'customer_tier_vip': 'عميل مميز VIP',
      'customer_tier_regular': 'عميل دائم',
      'customer_tier_new': 'عميل جديد',
      'monthly_report_title': 'ملخص الشهر',
      'monthly_sales_label': 'مبيعات الشهر',
      'monthly_expenses_label': 'مصاريف الشغل',
      'monthly_net_profit_label': 'صافي ربح الشهر',
      'monthly_personal_drawings_label': 'سحب شخصي للبيت',
      'monthly_top_products_title': 'أكثر 5 منتجات مبيعاً',
      'monthly_top_customers_title': 'أفضل 5 عملاء',
      'monthly_orders_count': '{count} طلبات',
      'yer': 'ر.ي',
    }, 'ar');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 8,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    await db.delete('payment_transactions');
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('expenses');
  });

  group('Phase 3 (W3.1): Customer Loyalty, Preferences & Reorder Tests', () {
    test('Customer preferences persist in DB v8 and survive JSON export/import', () async {
      final repo = CustomerRepositoryImpl();
      final customer = Customer(
        id: 'cust_pref_1',
        name: 'أم سارة',
        phone: '771112233',
        preferences: 'الطول 54 • بدون سكر • تغليف هدايا',
      );
      await repo.saveCustomer(customer);

      final fetched = await repo.getCustomerById('cust_pref_1');
      expect(fetched, isNotNull);
      expect(fetched!.preferences, 'الطول 54 • بدون سكر • تغليف هدايا');

      final json = await AppDatabase.instance.exportAllDataToJson();
      await db.delete('customers');
      await AppDatabase.instance.importAllDataFromJson(json);

      final restored = await repo.getCustomerById('cust_pref_1');
      expect(restored!.preferences, 'الطول 54 • بدون سكر • تغليف هدايا');
    });

    test('CustomerLoyaltyHelper computes VIP, Regular and New tiers accurately', () {
      expect(
        CustomerLoyaltyHelper.computeTier(ordersCount: 5, totalSalesYer: 10000),
        CustomerLoyaltyTier.vip,
      );
      expect(
        CustomerLoyaltyHelper.computeTier(ordersCount: 1, totalSalesYer: 120000),
        CustomerLoyaltyTier.vip,
      );
      expect(
        CustomerLoyaltyHelper.computeTier(ordersCount: 2, totalSalesYer: 15000),
        CustomerLoyaltyTier.regular,
      );
      expect(
        CustomerLoyaltyHelper.computeTier(ordersCount: 1, totalSalesYer: 5000),
        CustomerLoyaltyTier.newCustomer,
      );
    });

    test('OrdersBloc ReorderEvent duplicates order and refreshes catalog price', () async {
      final productRepo = ProductRepositoryImpl();
      await productRepo.createProduct(Product(
        id: 'prod_re_1',
        name: 'كنافة',
        costPrice: 1200,
        sellPrice: 3500, // سعر محدث في الكتالوج
        currency: AppConstants.currencyYer,
      ));

      final orderRepo = OrderRepositoryImpl();
      final sourceOrder = IndividualOrder(
        id: 'ord_src_1',
        orderNumber: 'SRC-1',
        customerName: 'فاطمة',
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusDelivered,
        paidAmount: 2500,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi_src_1',
            orderId: 'ord_src_1',
            productId: 'prod_re_1',
            name: 'كنافة',
            quantity: 2,
            costPrice: 1000,
            sellPrice: 2500, // السعر القديم
            currency: AppConstants.currencyYer,
          ),
        ],
      );
      await orderRepo.saveOrder(sourceOrder, sourceOrder.items);

      final bloc = OrdersBloc(repository: orderRepo);
      bloc.add(ReorderEvent(sourceOrder));
      await expectLater(bloc.stream, emitsThrough(isA<OrdersLoaded>()));

      final all = await orderRepo.getAllOrders();
      expect(all.length, 2);
      final duplicated = all.firstWhere((o) => o.id != 'ord_src_1');
      expect(duplicated.orderStatus, AppConstants.orderStatusPending);
      expect(duplicated.paidAmount, 0.0);
      expect(duplicated.items.first.sellPrice, 3500.0);
      expect(duplicated.items.first.costPrice, 1200.0);
      await bloc.close();
    });
  });

  group('Phase 3 (W3.2): MonthlyInsightsService & PDF Report Tests', () {
    test('MonthlyInsightsService computes sales, comparison, top lists and excludes personal drawings from netProfit', () async {
      final orderRepo = OrderRepositoryImpl();
      final expenseRepo = ExpenseRepositoryImpl();
      final now = DateTime.now();
      final prevMonth = DateTime(now.year, now.month - 1, 15);

      await orderRepo.saveOrder(
        IndividualOrder(
          id: 'ord_prev',
          orderNumber: 'M-0',
          customerName: 'خالد',
          createdAt: prevMonth,
          paidAmount: 4000,
          currency: AppConstants.currencyYer,
          items: [
            OrderItem(
              id: 'oi_p',
              orderId: 'ord_prev',
              name: 'معمول',
              quantity: 2,
              costPrice: 1000,
              sellPrice: 2000,
              currency: AppConstants.currencyYer,
            ),
          ],
        ),
        [
          OrderItem(
            id: 'oi_p',
            orderId: 'ord_prev',
            name: 'معمول',
            quantity: 2,
            costPrice: 1000,
            sellPrice: 2000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      final curItem = OrderItem(
        id: 'oi_c1',
        orderId: 'ord_cur',
        name: 'بسبوسة',
        quantity: 3,
        costPrice: 1000, // 3000 cost
        sellPrice: 3000, // 9000 sell
        currency: AppConstants.currencyYer,
      );
      await orderRepo.saveOrder(
        IndividualOrder(
          id: 'ord_cur',
          orderNumber: 'M-1',
          customerId: 'c1',
          customerName: 'سارة',
          createdAt: now,
          paidAmount: 9000,
          currency: AppConstants.currencyYer,
          items: [curItem],
        ),
        [curItem],
      );

      await expenseRepo.createExpense(Expense(
        id: 'exp_m_biz',
        title: 'دقيق وسكر',
        expenseType: AppConstants.expenseTypeBusiness,
        amount: 1000,
        expenseDate: now,
      ));
      await expenseRepo.createExpense(Expense(
        id: 'exp_m_home',
        title: 'مصروف البيت',
        expenseType: AppConstants.expenseTypePersonal,
        amount: 2000,
        expenseDate: now,
      ));

      final report = await MonthlyInsightsService.instance.generateForMonth(now.year, now.month);
      expect(report.totalSalesYer, 9000.0);
      expect(report.prevMonthSalesYer, 4000.0);
      expect(report.salesChangePercent, closeTo(125.0, 0.1));
      expect(report.businessExpensesYer, 1000.0);
      expect(report.personalDrawingsYer, 2000.0);
      expect(report.netProfitYer, 5000.0); // (9000 - 3000) - 1000 = 5000
      expect(report.topProducts.first.name, 'بسبوسة');
      expect(report.topCustomers.first.name, 'سارة');

      final pdfBytes = await MonthlyReportPdfGenerator.generateMonthlyPdf(
        report: report,
        currencyCode: AppConstants.currencyYer,
      );
      expect(pdfBytes.length, greaterThan(500));
      expect(String.fromCharCodes(pdfBytes.take(4)), '%PDF');
    });
  });

  group('Phase 3 (W3.3): Weekly Backup Preferences Tests', () {
    test('PreferencesService stores weekly backup reminder and last backup timestamp', () async {
      final prefs = PreferencesService.instance;
      expect(prefs.isWeeklyBackupReminderEnabled(), isFalse);

      await prefs.setWeeklyBackupReminderEnabled(true);
      expect(prefs.isWeeklyBackupReminderEnabled(), isTrue);

      final now = DateTime(2026, 11, 24, 15, 30);
      await prefs.setLastBackupAt(now);
      expect(prefs.getLastBackupAt(), now);
    });
  });
}
