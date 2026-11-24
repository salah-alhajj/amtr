import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/database/app_database.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/currency_service.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:mosaed/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:mosaed/features/expenses/data/repositories/expense_repository_impl.dart';
import 'package:mosaed/features/orders/data/repositories/order_repository_impl.dart';
import 'package:mosaed/features/products/data/repositories/product_repository_impl.dart';
import 'package:mosaed/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:mosaed/models/expense.dart';
import 'package:mosaed/models/individual_order.dart';
import 'package:mosaed/models/order_item.dart';
import 'package:mosaed/models/product.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();

    LocalizationHelper.setStrings({
      'pf_status_new': 'طلب جديد',
      'pf_status_preparing': 'قيد التجهيز',
      'item_status_awaiting_purchase': 'بانتظار الشراء',
      'item_status_purchased': 'تم الشراء',
    }, 'ar');

    db = await openDatabase(
      inMemoryDatabasePath,
      version: 5,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
    await CurrencyService.instance.updateRates(
      newSarToYer: 535.0,
      newUsdToYer: 2040.0,
    );
  });

  tearDown(() async {
    await db.delete('order_items');
    await db.delete('orders');
    await db.delete('shipments');
    await db.delete('customers');
    await db.delete('products');
    await db.delete('expenses');
  });

  group('Product Catalog & Stock Tests', () {
    final repo = ProductRepositoryImpl();

    test('CRUD and stock adjustment work accurately', () async {
      final product = Product(
        id: 'prod_1',
        name: 'معمول تمر فاخر',
        category: 'cat_food_sweets',
        unit: 'علبة',
        costPrice: 1500,
        sellPrice: 3000,
        currency: AppConstants.currencyYer,
        trackStock: true,
        stockQuantity: 5,
        lowStockThreshold: 3,
      );

      await repo.createProduct(product);
      final fetched = await repo.getProductById('prod_1');
      expect(fetched, isNotNull);
      expect(fetched!.name, 'معمول تمر فاخر');
      expect(fetched.unitProfit, 1500);
      expect(fetched.isLowStock, isFalse);

      await repo.adjustStock('prod_1', -3);
      final afterDecrement = await repo.getProductById('prod_1');
      expect(afterDecrement!.stockQuantity, 2);
      expect(afterDecrement.isLowStock, isTrue);

      await repo.adjustStock('prod_1', -10);
      final clamped = await repo.getProductById('prod_1');
      expect(clamped!.stockQuantity, 0);
      expect(clamped.isOutOfStock, isTrue);
    });
  });

  group('Expenses & True Net Profit Tests', () {
    final expenseRepo = ExpenseRepositoryImpl();
    final orderRepo = OrderRepositoryImpl();
    final productRepo = ProductRepositoryImpl();

    test('DashboardBloc subtracts operating expenses from net profit and tracks low stock & today orders', () async {
      await productRepo.createProduct(Product(
        id: 'prod_low',
        name: 'بخور عدني',
        sellPrice: 5000,
        trackStock: true,
        stockQuantity: 1,
        lowStockThreshold: 3,
      ));

      final order = IndividualOrder(
        id: 'ord_pf_1',
        orderNumber: 'PF-101',
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusPending,
        paidAmount: 11000,
        deliveryType: AppConstants.deliveryDelivery,
        deliveryFee: 2000,
        discount: 1000,
        deliveryAddress: 'حي حدة',
        currency: AppConstants.currencyYer,
        items: [
          OrderItem(
            id: 'oi_1',
            orderId: 'ord_pf_1',
            name: 'كيكة منزلية',
            quantity: 2,
            costPrice: 2500, // 5000 cost
            sellPrice: 5000, // 10000 sell
            currency: AppConstants.currencyYer,
          ),
        ],
      );
      // totalSellPrice = 10000 + 2000 - 1000 = 11000
      // order rawProfit = 11000 - 5000 = 6000
      expect(order.totalSellPrice, 11000.0);
      expect(order.rawProfit, 6000.0);
      expect(order.remainingDebt, 0.0);

      await orderRepo.saveOrder(order, order.items);
      await expenseRepo.createExpense(Expense(
        id: 'exp_1',
        title: 'علب تغليف',
        category: 'exp_cat_packaging',
        amount: 1500,
        currency: AppConstants.currencyYer,
      ));

      final bloc = DashboardBloc(
        orderRepo: orderRepo,
        shipmentRepo: ShipmentRepositoryImpl(),
        customerRepo: CustomerRepositoryImpl(),
        expenseRepo: expenseRepo,
        productRepo: productRepo,
      );

      bloc.add(const LoadDashboardData());
      await expectLater(
        bloc.stream,
        emitsThrough(isA<DashboardLoaded>()),
      );

      final loaded = bloc.state as DashboardLoaded;
      expect(loaded.stats.totalExpensesInYer, 1500.0);
      expect(loaded.stats.netProfitInYer, 4500.0); // 6000 - 1500
      expect(loaded.stats.lowStockCount, 1);
      expect(loaded.stats.todayOrdersCount, 1);
      await bloc.close();
    });
  });

  group('Business Profile & Backup Parity Tests', () {
    test('PreferencesService stores business profile and AppConstants adapts status labels', () async {
      final prefs = PreferencesService.instance;
      await prefs.setBusinessMode(AppConstants.businessModeProductiveFamily);
      await prefs.setBusinessName('مطبخ أم محمد');
      expect(prefs.isProductiveFamilyMode, isTrue);
      expect(prefs.getBusinessName(), 'مطبخ أم محمد');
      expect(
        AppConstants.getOrderStatusLabel(AppConstants.orderStatusPending),
        'طلب جديد',
      );

      await prefs.setBusinessMode(AppConstants.businessModeTradeLogistics);
      expect(
        AppConstants.getOrderStatusLabel(AppConstants.orderStatusPending),
        'بانتظار الشراء',
      );
    });

    test('JSON export and import preserves products and expenses', () async {
      await ProductRepositoryImpl().createProduct(Product(
        id: 'p_backup',
        name: 'عسل سدر',
        sellPrice: 12000,
      ));
      await ExpenseRepositoryImpl().createExpense(Expense(
        id: 'e_backup',
        title: 'عبوات زجاجية',
        amount: 2500,
      ));

      final exported = await AppDatabase.instance.exportAllDataToJson();
      expect((exported['products'] as List).length, 1);
      expect((exported['expenses'] as List).length, 1);

      await db.delete('products');
      await db.delete('expenses');

      await AppDatabase.instance.importAllDataFromJson(exported);
      final restoredProducts = await ProductRepositoryImpl().getAllProducts();
      final restoredExpenses = await ExpenseRepositoryImpl().getAllExpenses();
      expect(restoredProducts.length, 1);
      expect(restoredProducts.first.name, 'عسل سدر');
      expect(restoredExpenses.length, 1);
      expect(restoredExpenses.first.title, 'عبوات زجاجية');
    });
  });
}
