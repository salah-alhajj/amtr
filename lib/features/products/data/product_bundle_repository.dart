import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/data_sync_bus.dart';
import '../../../models/product_bundle_item.dart';

/// مستودع إدارة مكوّنات الباقات والبوكسات التجميعية في SQLite
class ProductBundleRepository {
  final AppDatabase dbHelper;

  ProductBundleRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  Future<List<ProductBundleItem>> getByBundleId(String bundleProductId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_bundle_items',
      where: 'bundleProductId = ?',
      whereArgs: [bundleProductId],
      orderBy: 'componentName ASC',
    );
    return maps.map(ProductBundleItem.fromMap).toList();
  }

  Future<Map<String, List<ProductBundleItem>>> getAllBundleItemsGrouped() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_bundle_items',
      orderBy: 'componentName ASC',
    );
    final grouped = <String, List<ProductBundleItem>>{};
    for (final map in maps) {
      final item = ProductBundleItem.fromMap(map);
      grouped.putIfAbsent(item.bundleProductId, () => []).add(item);
    }
    return grouped;
  }

  Future<void> replaceForBundle(
    String bundleProductId,
    List<ProductBundleItem> items,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'product_bundle_items',
        where: 'bundleProductId = ?',
        whereArgs: [bundleProductId],
      );
      for (final item in items) {
        await txn.insert(
          'product_bundle_items',
          item.copyWith(bundleProductId: bundleProductId).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.products);
  }
}
