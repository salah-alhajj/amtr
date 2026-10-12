import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:amtr/core/database/app_database.dart';
import 'package:amtr/core/services/demo_data_service.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database testDb;

  setUpAll(() async {
    testDb = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, version) => AppDatabase.instance.createDBForTesting(db),
    );
    AppDatabase.setTestDatabase(testDb);
  });

  tearDownAll(() async {
    await testDb.close();
  });

  group('DemoDataService Tests (اختبارات خدمة توليد وحذف الداتا التجريبية والتدريبية)', () {
    final demoService = DemoDataService.instance;

    test('1. Initial demo data count should be zero', () async {
      final stats = await demoService.getDemoDataStats();
      expect(stats.totalRecords, equals(0));
      expect(stats.hasDemoData, isFalse);
    });

    test('2. Generate demo data should populate hundreds of interconnected records', () async {
      final stats = await demoService.generateDemoData();

      expect(stats.hasDemoData, isTrue);
      expect(stats.customersCount, equals(35));
      expect(stats.shipmentsCount, equals(15));
      expect(stats.ordersCount, equals(120));
      expect(stats.itemsCount, greaterThan(300));
      expect(stats.totalRecords, greaterThan(450));

      // التحقق من ترابط السجلات في قاعدة البيانات
      final orders = await testDb.query('orders', where: "id LIKE 'demo_%'");
      expect(orders.length, equals(120));

      for (final order in orders) {
        expect(order['customerId'], isNotNull);
        expect((order['customerId'] as String).startsWith('demo_cust_'), isTrue);
      }
    });

    test('3. Remove demo data should cleanly delete all demo records without leaving leftovers', () async {
      final deletedCount = await demoService.removeDemoData();
      expect(deletedCount, greaterThan(450));

      final statsAfter = await demoService.getDemoDataStats();
      expect(statsAfter.totalRecords, equals(0));
      expect(statsAfter.hasDemoData, isFalse);
      expect(statsAfter.customersCount, equals(0));
      expect(statsAfter.shipmentsCount, equals(0));
      expect(statsAfter.ordersCount, equals(0));
      expect(statsAfter.itemsCount, equals(0));
    });
  });
}
