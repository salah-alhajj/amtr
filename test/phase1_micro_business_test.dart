import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/cashbox/data/repositories/cashbox_repository_impl.dart';
import 'package:mosaed/features/cashbox/presentation/cubit/cashbox_cubit.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/dashboard/presentation/widgets/currency_selector_bar.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/onboarding/presentation/screens/business_setup_wizard_screen.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();

    LocalizationHelper.setStrings({
      'wizard_step_counter': 'الخطوة {current} من {total}',
      'wizard_step1_title': 'ما نوع مشروعك؟',
      'wizard_step1_subtitle': 'اختر النمط المناسب',
      'business_mode_family': 'أسر منتجة / متجر منزلي',
      'business_mode_trade': 'تجارة وشحنات مجمعة',
      'wizard_family_desc': 'مطبخ منزلي',
      'wizard_trade_desc': 'تجارة وتوريد',
      'common_next': 'التالي',
      'onboarding_next': 'التالي',
      'common_previous': 'السابق',
      'common_skip': 'تخطي',
      'wizard_step2_title': 'هوية مشروعك وعملتك',
      'wizard_step2_subtitle': 'تظهر في الفواتير',
      'business_name_label': 'اسم المشروع',
      'business_name_hint': 'مثال: مطبخ أم محمد',
      'wizard_default_currency_label': 'العملة الأساسية',
      'wizard_multi_currency_toggle': 'أتعامل بأكثر من عملة',
      'wizard_multi_currency_hint': 'أظهر مبدل العملات',
      'wizard_step3_title': 'مشروعك جاهز!',
      'wizard_step3_subtitle': 'بدون تعقيد محاسبي',
      'wizard_start_btn': 'ابدأ الآن',
      'currency_yer': 'ريال يمني',
      'currency_sar': 'ريال سعودي',
      'currency_usd': 'دولار',
      'yer': 'ر.ي',
    }, 'ar');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 6,
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
    await db.delete('shipments');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('expenses');
  });

  group('Phase 1: DB v6, PaymentTransactions & CashBox Tests', () {
    test('OrderRepositoryImpl records payment_transactions on saveOrder and updatePaymentStatus', () async {
      final orderRepo = OrderRepositoryImpl();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final order = IndividualOrder(
        id: 'ord_tx_1',
        orderNumber: 'Q-101',
        paymentStatus: AppConstants.paymentPartial,
        createdAt: yesterday,
        paidAmount: 2000,
        currency: AppConstants.currencyYer,
        isQuickOrder: true,
        items: [
          OrderItem(
            id: 'oi_tx_1',
            orderId: 'ord_tx_1',
            productId: 'prod_1',
            name: 'بسبوسة',
            quantity: 1,
            costPrice: 1000,
            sellPrice: 5000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );

      await orderRepo.saveOrder(order, order.items);
      final fetched = await orderRepo.getAllOrders();
      expect(fetched.length, 1);
      expect(fetched.first.isQuickOrder, isTrue);
      expect(fetched.first.items.first.productId, 'prod_1');

      // سداد المتبقي اليوم (3000) على طلب الأمس
      await orderRepo.updatePaymentStatus('ord_tx_1', AppConstants.paymentPrepaid, 5000);

      final summaryToday = await CashBoxRepositoryImpl().getDailySummary(DateTime.now());
      expect(summaryToday.cashInYer, 3000.0);
    });

    test('Personal drawings reduce netDrawerYer but do NOT reduce business netProfitInYer', () async {
      final orderRepo = OrderRepositoryImpl();
      final expenseRepo = ExpenseRepositoryImpl();

      final order = IndividualOrder(
        id: 'ord_cb_1',
        orderNumber: 'Q-202',
        paymentStatus: AppConstants.paymentPrepaid,
        paidAmount: 10000,
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi_cb_1',
            orderId: 'ord_cb_1',
            name: 'كيكة',
            quantity: 1,
            costPrice: 4000,
            sellPrice: 10000,
            currency: AppConstants.currencyYer,
          ),
        ],
      );
      await orderRepo.saveOrder(order, order.items);

      await expenseRepo.createExpense(Expense(
        id: 'exp_biz',
        title: 'علب تغليف',
        expenseType: AppConstants.expenseTypeBusiness,
        amount: 1000,
        currency: AppConstants.currencyYer,
      ));
      await expenseRepo.createExpense(Expense(
        id: 'exp_home',
        title: 'مقاضي البيت',
        expenseType: AppConstants.expenseTypePersonal,
        amount: 2500,
        currency: AppConstants.currencyYer,
      ));

      final cashBoxCubit = CashBoxCubit();
      await cashBoxCubit.loadDate(DateTime.now());
      final cbState = cashBoxCubit.state as CashBoxLoaded;
      expect(cbState.summary.cashInYer, 10000.0);
      expect(cbState.summary.businessExpensesYer, 1000.0);
      expect(cbState.summary.personalDrawingsYer, 2500.0);
      expect(cbState.summary.netDrawerYer, 6500.0); // 10000 - 1000 - 2500
      await cashBoxCubit.close();

      final dashboardBloc = DashboardBloc(
        orderRepo: orderRepo,
        shipmentRepo: ShipmentRepositoryImpl(),
        customerRepo: CustomerRepositoryImpl(),
        expenseRepo: expenseRepo,
        productRepo: ProductRepositoryImpl(),
      );
      dashboardBloc.add(const LoadDashboardData());
      await expectLater(dashboardBloc.stream, emitsThrough(isA<DashboardLoaded>()));

      final dashState = dashboardBloc.state as DashboardLoaded;
      expect(dashState.stats.totalExpensesInYer, 1000.0);
      expect(dashState.stats.personalDrawingsInYer, 2500.0);
      expect(dashState.stats.netProfitInYer, 5000.0); // (10000 - 4000) - 1000 = 5000
      await dashboardBloc.close();
    });

    test('Database v5 -> v6 upgrade backfills payment_transactions and preserves JSON backup', () async {
      final v5Db = await openDatabase(
        inMemoryDatabasePath,
        version: 5,
        singleInstance: false,
        onCreate: (db, version) async {
          await db.execute('CREATE TABLE exchange_rates (id TEXT PRIMARY KEY, sarToYer REAL, usdToYer REAL, updatedAt TEXT)');
          await db.execute('CREATE TABLE customers (id TEXT PRIMARY KEY, name TEXT, phone TEXT, whatsapp TEXT, notes TEXT, createdAt TEXT)');
          await db.execute('CREATE TABLE shipments (id TEXT PRIMARY KEY, shipmentNumber TEXT, title TEXT, carrierName TEXT, trackingNumber TEXT, transportCost REAL, transportCostCurrency TEXT, status TEXT, createdAt TEXT, expectedDeliveryDate TEXT, actualDeliveryDate TEXT, notes TEXT)');
          await db.execute('CREATE TABLE orders (id TEXT PRIMARY KEY, orderNumber TEXT, customerId TEXT, customerName TEXT, shipmentId TEXT, paymentStatus TEXT, orderStatus TEXT, createdAt TEXT, expectedDeliveryDate TEXT, actualDeliveryDate TEXT, debtDueDate TEXT, hasDebtReminder INTEGER, isSyncedWithCalendar INTEGER, paidAmount REAL, additionalCost REAL, discount REAL, deliveryFee REAL, deliveryType TEXT, deliveryAddress TEXT, currency TEXT, notes TEXT)');
          await db.execute('CREATE TABLE order_items (id TEXT PRIMARY KEY, orderId TEXT, name TEXT, description TEXT, quantity INTEGER, costPrice REAL, sellPrice REAL, currency TEXT, photos TEXT)');
          await db.execute('CREATE TABLE products (id TEXT PRIMARY KEY, name TEXT, category TEXT, unit TEXT, costPrice REAL, sellPrice REAL, currency TEXT, stockQuantity INTEGER, trackStock INTEGER, lowStockThreshold INTEGER, isActive INTEGER, notes TEXT, createdAt TEXT)');
          await db.execute('CREATE TABLE expenses (id TEXT PRIMARY KEY, title TEXT, category TEXT, amount REAL, currency TEXT, expenseDate TEXT, notes TEXT, createdAt TEXT)');
          await db.insert('orders', {
            'id': 'old_ord',
            'orderNumber': 'OLD-1',
            'paymentStatus': 'prepaid',
            'orderStatus': 'delivered',
            'createdAt': '2026-10-01T10:00:00.000',
            'paidAmount': 4500.0,
            'currency': 'yer',
          });
        },
      );
      await v5Db.close();
      expect(v5Db.isOpen, isFalse);

      // التحقق من تصدير واستيراد JSON مع payment_transactions
      await OrderRepositoryImpl().saveOrder(
        IndividualOrder(
          id: 'ord_json',
          orderNumber: 'J-1',
          paidAmount: 1500,
          currency: AppConstants.currencyYer,
        ),
        [],
      );
      final json = await AppDatabase.instance.exportAllDataToJson();
      expect((json['payment_transactions'] as List).length, 1);

      await db.delete('payment_transactions');
      await db.delete('orders');
      await AppDatabase.instance.importAllDataFromJson(json);
      final restoredTx = await db.query('payment_transactions');
      expect(restoredTx.length, 1);
    });
  });

  group('Phase 1: BusinessModeCubit & Widgets Tests', () {
    test('BusinessModeCubit toggles mode and updates preferences reactively', () async {
      final cubit = BusinessModeCubit();
      cubit.loadFromPreferences();
      expect(cubit.state.isProductiveFamily, isTrue);

      await cubit.updateProfile(
        businessMode: AppConstants.businessModeTradeLogistics,
        businessName: 'مؤسسة النجم',
        defaultCurrency: AppConstants.currencySar,
        multiCurrencyEnabled: true,
      );
      expect(cubit.state.isProductiveFamily, isFalse);
      expect(cubit.state.businessName, 'مؤسسة النجم');
      expect(cubit.state.defaultCurrency, AppConstants.currencySar);
      expect(cubit.state.multiCurrencyEnabled, isTrue);
      await cubit.close();
    });

    testWidgets('BusinessSetupWizardScreen renders 3 steps and navigates cleanly', (tester) async {
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => LocaleBloc()),
            BlocProvider(create: (_) => BusinessModeCubit()..loadFromPreferences()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Directionality(
              textDirection: TextDirection.rtl,
              child: BusinessSetupWizardScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ما نوع مشروعك؟'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('هوية مشروعك وعملتك'), findsOneWidget);
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();

      expect(find.text('مشروعك جاهز!'), findsOneWidget);
      expect(find.text('ابدأ الآن'), findsOneWidget);
    });

    testWidgets('CurrencySelectorBar renders YER segment cleanly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: CurrencySelectorBar(
                currencyService: CurrencyService.instance,
                activeCurrency: AppConstants.currencyYer,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('ريال يمني'), findsOneWidget);
      expect(find.text('ريال سعودي'), findsOneWidget);
    });
  });
}
