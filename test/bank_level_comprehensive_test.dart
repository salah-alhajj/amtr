import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:amtr/core/constants.dart';
import 'package:amtr/core/database/app_database.dart';
import 'package:amtr/core/services/currency_service.dart';
import 'package:amtr/models/customer.dart';
import 'package:amtr/models/individual_order.dart';
import 'package:amtr/models/order_item.dart';
import 'package:amtr/features/customers/data/repositories/customer_repository_impl.dart';
import 'package:amtr/features/customers/presentation/bloc/customers_bloc.dart';
import 'package:amtr/features/dashboard/presentation/bloc/dashboard_bloc.dart';
import 'package:amtr/features/orders/data/repositories/order_repository_impl.dart';
import 'package:amtr/features/orders/presentation/bloc/orders_bloc.dart';
import 'package:amtr/features/shipments/data/repositories/shipment_repository_impl.dart';
import 'package:amtr/features/shipments/presentation/bloc/shipments_bloc.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(db);
  });

  group('Bank-Level Strict Financial & Accounting Integrity (اختبارات النزاهة المصرفية والمحاسبية)', () {
    final currencyService = CurrencyService.instance;

    setUp(() async {
      await currencyService.updateRates(newSarToYer: 535.0, newUsdToYer: 2040.0);
    });

    test('1. Floating-Point Micro-Unit Cent Precision (دقة الميكرو-سنت وتجنب تراكم الكسور العشرية)', () {
      // محاكاة شراء 3 قطع بسعر إفرادي ذو كسر دقيق 33.333333 ريال سعودي
      final items = [
        OrderItem(
          id: 'item_cent_1',
          orderId: 'ord_cent',
          name: 'بند أ',
          quantity: 3,
          costPrice: 33.333333,
          sellPrice: 50.555555,
          currency: AppConstants.currencySar,
        ),
      ];

      final order = IndividualOrder(
        id: 'ord_cent',
        orderNumber: 'CENT-101',
        paidAmount: 51.666665,
        currency: AppConstants.currencySar,
        items: items,
      );

      final expectedTotalCost = 3 * 33.333333;
      final expectedTotalSell = 3 * 50.555555;
      expect(order.totalCostPrice, closeTo(expectedTotalCost, 0.000001));
      expect(order.totalSellPrice, closeTo(expectedTotalSell, 0.000001));
      expect(order.remainingDebt, closeTo(expectedTotalSell - 51.666665, 0.000001));
      expect(order.totalSellPrice, closeTo(order.paidAmount + order.remainingDebt, 0.000001));
    });

    test('2. Multi-Item High-Volume Ledger Stress Test (محاكاة إجهاد دفتر الأستاذ لـ 100 عنصر)', () {
      final List<OrderItem> largeOrderItems = [];
      double accumulatedExpectedCost = 0.0;
      double accumulatedExpectedSell = 0.0;

      for (int i = 1; i <= 100; i++) {
        final cost = i * 1.5;
        final sell = i * 2.25;
        accumulatedExpectedCost += cost;
        accumulatedExpectedSell += sell;

        largeOrderItems.add(OrderItem(
          id: 'bulk_item_$i',
          orderId: 'bulk_order_1',
          name: 'صنف #$i',
          quantity: 1,
          costPrice: cost,
          sellPrice: sell,
          currency: AppConstants.currencySar,
        ));
      }

      final bulkOrder = IndividualOrder(
        id: 'bulk_order_1',
        orderNumber: 'BULK-999',
        paidAmount: accumulatedExpectedSell * 0.4, // دفع 40% دفعة مقدمة
        currency: AppConstants.currencySar,
        items: largeOrderItems,
      );

      expect(bulkOrder.totalCostPrice, closeTo(accumulatedExpectedCost, 0.0001));
      expect(bulkOrder.totalSellPrice, closeTo(accumulatedExpectedSell, 0.0001));
      expect(bulkOrder.paidAmount, closeTo(accumulatedExpectedSell * 0.4, 0.0001));
      expect(bulkOrder.remainingDebt, closeTo(accumulatedExpectedSell * 0.6, 0.0001));

      // القاعدة الصارمة: البيع = المدفوع + المتبقي
      expect(bulkOrder.totalSellPrice, closeTo(bulkOrder.paidAmount + bulkOrder.remainingDebt, 0.0001));
      expect(bulkOrder.rawProfit, closeTo(accumulatedExpectedSell - accumulatedExpectedCost, 0.0001));
    });

    test('3. Currency Conversion Volatility Simulation (محاكاة تقلبات أسعار الصرف الحادة)', () async {
      const amountSar = 2500.0;
      
      // السعر الأول: 1 SAR = 535 YER
      expect(currencyService.toBaseYer(amountSar, AppConstants.currencySar), 1337500.0);

      // هبوط أو صعود سعر الصرف المفاجئ: 1 SAR = 580 YER
      await currencyService.updateRates(newSarToYer: 580.0, newUsdToYer: 2150.0);
      expect(currencyService.toBaseYer(amountSar, AppConstants.currencySar), 1450000.0);

      // التحويل العكسي
      final convertedBack = currencyService.fromBaseYer(1450000.0, AppConstants.currencySar);
      expect(convertedBack, 2500.0);
    });
  });

  group('Pure Dart BLoC Unit Tests (اختبارات وحدات إدارة الحالة بلوك النقية بدون مولدات)', () {
    late CustomerRepositoryImpl customerRepo;
    late OrderRepositoryImpl orderRepo;
    late ShipmentRepositoryImpl shipmentRepo;

    setUp(() {
      customerRepo = CustomerRepositoryImpl();
      orderRepo = OrderRepositoryImpl();
      shipmentRepo = ShipmentRepositoryImpl();
    });

    test('4. CustomersBloc Flow (تحميل وإضافة عميل بنجاح)', () async {
      final bloc = CustomersBloc(repository: customerRepo);
      expect(bloc.state, isA<CustomersInitial>());

      bloc.add(const LoadCustomers());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CustomersLoading>(),
          isA<CustomersLoaded>(),
        ]),
      );

      final newCustomer = Customer(
        id: 'test_cust_bloc_${DateTime.now().millisecondsSinceEpoch}',
        name: 'أحمد المفلحي',
        phone: '966555123456',
        notes: 'عميل اختبار BLoC',
      );

      bloc.add(CreateCustomerEvent(newCustomer));
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<CustomersLoading>(),
          isA<CustomersLoaded>().having(
            (state) => state.customers.any((c) => c.id == newCustomer.id),
            'contains new customer',
            isTrue,
          ),
        ]),
      );

      await bloc.close();
    });

    test('5. OrdersBloc Filtering & State Transitions (تدفق حالات الطلبات والتصفية)', () async {
      final bloc = OrdersBloc(repository: orderRepo);
      expect(bloc.state, isA<OrdersInitial>());

      bloc.add(const LoadOrders());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<OrdersLoading>(),
          isA<OrdersLoaded>(),
        ]),
      );

      // تصفية حسب حالة الدفع (تحديث فوري دون وميض تحميل)
      bloc.add(const FilterOrders(AppConstants.paymentDebt));
      await expectLater(
        bloc.stream,
        emits(
          isA<OrdersLoaded>().having(
            (state) => state.selectedFilter,
            'selectedFilter is debt',
            AppConstants.paymentDebt,
          ),
        ),
      );

      await bloc.close();
    });

    test('6. DashboardBloc Metrics Loading (تحميل مقاييس لوحة التحكم والتحويل متعدد العملات)', () async {
      final bloc = DashboardBloc(
        orderRepo: orderRepo,
        shipmentRepo: shipmentRepo,
        customerRepo: customerRepo,
        currency: CurrencyService.instance,
      );

      expect(bloc.state, isA<DashboardInitial>());

      bloc.add(const LoadDashboardData());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<DashboardLoading>(),
          isA<DashboardLoaded>().having(
            (state) => state.activeCurrency,
            'default currency matches active currency',
            CurrencyService.instance.activeDisplayCurrency,
          ),
        ]),
      );

      await bloc.close();
    });

    test('7. ShipmentsBloc Flow (تحميل الشحنات المجمعة)', () async {
      final bloc = ShipmentsBloc(repository: shipmentRepo);
      expect(bloc.state, isA<ShipmentsInitial>());

      bloc.add(const LoadShipments());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          isA<ShipmentsLoading>(),
          isA<ShipmentsLoaded>(),
        ]),
      );

      await bloc.close();
    });
  });
}
