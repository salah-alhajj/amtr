import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:amtr/core/constants.dart';
import 'package:amtr/core/database/app_database.dart';
import 'package:amtr/core/services/currency_service.dart';
import 'package:amtr/models/consolidated_shipment.dart';
import 'package:amtr/models/customer.dart';
import 'package:amtr/models/individual_order.dart';
import 'package:amtr/models/order_item.dart';

void main() {
  // تهيئة FFI لمحاكاة قاعدة بيانات SQLite في بيئة الاختبارات
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

  group('Bank-Level Financial & Currency Tests (اختبارات الدقة المصرفية والعملات)', () {
    final currencyService = CurrencyService.instance;

    setUp(() async {
      // تثبيت أسعار الصرف للاختبار: 1 SAR = 535 YER, 1 USD = 2040 YER
      await currencyService.updateRates(newSarToYer: 535.0, newUsdToYer: 2040.0);
    });

    test('1. Currency Conversion Precision & Triangle Invariant (تكامل التحويل الدائري)', () {
      const double initialSar = 1000.0; // 1000 ريال سعودي
      final yerEquivalent = currencyService.toBaseYer(initialSar, AppConstants.currencySar);
      expect(yerEquivalent, 535000.0);

      // تحويل الريال اليمني الناتج إلى دولار
      final usdEquivalent = currencyService.fromBaseYer(yerEquivalent, AppConstants.currencyUsd);
      expect(usdEquivalent, closeTo(535000.0 / 2040.0, 0.0001));

      // إعادة التحويل إلى ريال سعودي والتأكد من مطابقة رأس المال الأصلي دون فقد دقة
      final roundTripSar = currencyService.convert(
        amount: usdEquivalent,
        fromCurrency: AppConstants.currencyUsd,
        toCurrency: AppConstants.currencySar,
      );
      expect(roundTripSar, closeTo(initialSar, 0.0001));
    });

    test('2. Order Financial Invariant: Balance Sheet (توازن الفاتورة والديون)', () {
      final items = [
        OrderItem(
          id: 'item_1',
          orderId: 'ord_1',
          name: 'سماعة بلوتوث',
          quantity: 2,
          costPrice: 50.0, // 2 * 50 = 100
          sellPrice: 80.0, // 2 * 80 = 160
          currency: AppConstants.currencySar,
        ),
        OrderItem(
          id: 'item_2',
          orderId: 'ord_1',
          name: 'شاحن سريع',
          quantity: 1,
          costPrice: 30.0, // 1 * 30 = 30
          sellPrice: 50.0, // 1 * 50 = 50
          currency: AppConstants.currencySar,
        ),
      ];

      // إجمالي التكلفة = 130 SAR، إجمالي البيع = 210 SAR
      // العميل دفع عربون 70 SAR، المتبقي دين = 140 SAR
      final order = IndividualOrder(
        id: 'ord_1',
        orderNumber: '1001',
        paidAmount: 70.0,
        currency: AppConstants.currencySar,
        items: items,
      );

      expect(order.totalCostPrice, 130.0);
      expect(order.totalSellPrice, 210.0);
      expect(order.remainingDebt, 140.0);
      expect(order.rawProfit, 80.0);

      // المعادلة المصرفية الصارمة: إجمالي البيع = المبلغ المدفوع + المتبقي كدين
      expect(order.totalSellPrice, order.paidAmount + order.remainingDebt);
      expect(order.isFullyPaid, isFalse);
      expect(order.isFullyPriced, isTrue);
    });

    test('3. Overpayment Non-Negative Debt Invariant (حماية عدم سالبية الديون عند السداد الفائض)', () {
      final items = [
        OrderItem(
          id: 'item_3',
          orderId: 'ord_2',
          name: 'غرض تجريبي',
          quantity: 1,
          costPrice: 100.0,
          sellPrice: 150.0,
          currency: AppConstants.currencyYer,
        ),
      ];

      // العميل دفع 200 (أكثر من المطلوب 150)
      final order = IndividualOrder(
        id: 'ord_2',
        orderNumber: '1002',
        paidAmount: 200.0,
        currency: AppConstants.currencyYer,
        items: items,
      );

      // الدين لا يمكن أن يكون سالباً
      expect(order.remainingDebt, 0.0);
      expect(order.isFullyPaid, isTrue);
    });

    test('4. Mixed-Currency Consolidated Cargo P&L Formula (حسبة صافي الربح للشحنة المجمعة متعددة العملات)', () {
      // الطلب الأول: اشترى بالدولار، باع للعميل بالريال السعودي
      final order1 = IndividualOrder(
        id: 'ord_c1',
        orderNumber: '2001',
        currency: AppConstants.currencySar,
        items: [
          OrderItem(
            id: 'it_c1',
            orderId: 'ord_c1',
            name: 'كمبيوتر لوحي',
            quantity: 1,
            costPrice: 100.0, // 100 USD تكلفة الشراء
            sellPrice: 450.0, // 450 SAR سعر البيع للعميل
            currency: AppConstants.currencyUsd, // اشترى بالدولار
          ),
        ],
      );

      // الطلب الثاني: اشترى بالريال السعودي، وباع بالريال السعودي
      final order2 = IndividualOrder(
        id: 'ord_c2',
        orderNumber: '2002',
        currency: AppConstants.currencySar,
        items: [
          OrderItem(
            id: 'it_c2',
            orderId: 'ord_c2',
            name: 'حقيبة سفر',
            quantity: 2,
            costPrice: 50.0, // 2 * 50 = 100 SAR تكلفة الشراء
            sellPrice: 80.0, // 2 * 80 = 160 SAR سعر البيع
            currency: AppConstants.currencySar,
          ),
        ],
      );

      // الشحنة المجمعة: أجور النقل 50 ريال سعودي
      final shipment = ConsolidatedShipment(
        id: 'shp_1',
        shipmentNumber: 'SHP-901',
        title: 'حمولة جدة - المكلا',
        transportCost: 50.0,
        transportCostCurrency: AppConstants.currencySar,
        orders: [order1, order2],
      );

      // التحقق التحليلي بالريال اليمني (القاعدة):
      // تكلفة البضائع:
      // order1: 100 USD * 2040 = 204,000 YER
      // order2: 100 SAR * 535 = 53,500 YER
      // إجمالي التكلفة الأصلية = 257,500 YER
      final expectedCostYer = (100.0 * 2040.0) + (100.0 * 535.0);
      expect(shipment.calculateTotalOriginalCostInYer(currencyService), expectedCostYer);

      // مبيعات العملاء:
      // order1 sell: 450 USD (عملة البند) * 2040 = 918,000 YER
      // order2 sell: 160 SAR * 535 = 85,600 YER
      // تكلفة النقل: 50 SAR * 535 = 26,750 YER
      final transportCostYer = 50.0 * 535.0;
      expect(shipment.calculateTransportCostInYer(currencyService), transportCostYer);

      final totalSellYer = shipment.calculateTotalClientSellPriceInYer(currencyService);
      final netProfitYer = shipment.calculateNetProfitInYer(currencyService);

      // المعادلة الصارمة: صافي الربح = المبيعات - تكلفة البضائع - تكلفة النقل
      expect(netProfitYer, totalSellYer - expectedCostYer - transportCostYer);

      // التحقق من التحويل الفوري لصافي الربح إلى الريال السعودي والدولار
      final profitInSar = shipment.calculateNetProfitIn(targetCurrency: AppConstants.currencySar, service: currencyService);
      expect(profitInSar, closeTo(netProfitYer / 535.0, 0.001));

      final profitInUsd = shipment.calculateNetProfitIn(targetCurrency: AppConstants.currencyUsd, service: currencyService);
      expect(profitInUsd, closeTo(netProfitYer / 2040.0, 0.001));
    });

    test('5. Safe Unpriced Items Handling (معالجة البنود غير المسعرة بدون أخطاء حسابية)', () {
      final unpricedItem = OrderItem(
        id: 'it_unpriced',
        orderId: 'ord_u',
        name: 'قطعة غيار نادرة',
        quantity: 3,
        costPrice: 40.0,
        sellPrice: null, // لم يُسعّر بعد
      );

      final order = IndividualOrder(
        id: 'ord_u',
        orderNumber: '3001',
        items: [unpricedItem],
      );

      expect(order.isFullyPriced, isFalse);
      expect(order.totalSellPrice, 0.0);
      expect(order.totalCostPrice, 120.0);
      expect(order.rawProfit, -120.0); // لم يتم البيع بعد فالمؤشر التقديري سالب التكلفة
    });
  });

  group('Database & Backup Round-Trip Parity Tests (اختبارات سلامة واسترجاع قاعدة البيانات)', () {
    test('6. Export & Import Round-Trip Integrity (تطابق البيانات 100% بعد التصدير والاستيراد)', () async {
      final db = AppDatabase.instance;

      // تجهيز بيانات تجريبية
      final testCustomer = Customer(
        id: 'cust_parity_1',
        name: 'سالم بازرعة',
        phone: '966500000000',
        notes: 'عميل مميز في تجارة الإلكترونيات',
      );

      final testOrder = IndividualOrder(
        id: 'ord_parity_1',
        orderNumber: 'ORD-9999',
        customerId: testCustomer.id,
        customerName: testCustomer.name,
        paymentStatus: AppConstants.paymentPrepaid,
        orderStatus: AppConstants.orderStatusPurchased,
        paidAmount: 500.0,
        currency: AppConstants.currencySar,
      );

      final testItem = OrderItem(
        id: 'item_parity_1',
        orderId: testOrder.id,
        name: 'ساعة ذكية',
        quantity: 2,
        costPrice: 150.0,
        sellPrice: 250.0,
        currency: AppConstants.currencySar,
        photos: ['/data/user/0/images/sample.jpg'],
      );

      final testShipment = ConsolidatedShipment(
        id: 'shp_parity_1',
        shipmentNumber: 'SHP-PARITY',
        title: 'شحنة اختبار السلامة المصرفية',
        carrierName: 'البريد السريع',
        trackingNumber: 'TRK-777888',
        transportCost: 100.0,
        transportCostCurrency: AppConstants.currencySar,
        status: AppConstants.shipmentDistribution,
      );

      // تنظيف الجداول قبل الإدراج لضمان استقلالية ونظافة الاختبار
      final sqliteDb = await db.database;
      await sqliteDb.delete('order_items');
      await sqliteDb.delete('orders');
      await sqliteDb.delete('shipments');
      await sqliteDb.delete('customers');

      await sqliteDb.insert('customers', testCustomer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await sqliteDb.insert('orders', testOrder.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await sqliteDb.insert('order_items', testItem.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await sqliteDb.insert('shipments', testShipment.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // 1. تصدير كامل البيانات إلى JSON
      final exportedJson = await db.exportAllDataToJson();
      expect(exportedJson['customers'], isNotEmpty);
      expect(exportedJson['orders'], isNotEmpty);
      expect(exportedJson['order_items'], isNotEmpty);
      expect(exportedJson['shipments'], isNotEmpty);

      // 2. محاكاة استيراد البيانات من النسخة المصدرة
      await db.importAllDataFromJson(exportedJson);

      // 3. التحقق الصارم من تطابق الحقول والأرقام
      final restoredOrders = await sqliteDb.query('orders', where: 'id = ?', whereArgs: [testOrder.id]);
      expect(restoredOrders.length, 1);
      final restoredOrder = IndividualOrder.fromMap(restoredOrders.first);
      expect(restoredOrder.orderNumber, 'ORD-9999');
      expect(restoredOrder.paidAmount, 500.0);
      expect(restoredOrder.paymentStatus, AppConstants.paymentPrepaid);

      final restoredItems = await sqliteDb.query('order_items', where: 'id = ?', whereArgs: [testItem.id]);
      expect(restoredItems.length, 1);
      final restoredItem = OrderItem.fromMap(restoredItems.first);
      expect(restoredItem.name, 'ساعة ذكية');
      expect(restoredItem.totalCost, 300.0);
      expect(restoredItem.totalSell, 500.0);
      expect(restoredItem.photos, contains('/data/user/0/images/sample.jpg'));
    });
  });
}
