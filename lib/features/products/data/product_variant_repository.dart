import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/data_sync_bus.dart';
import '../../../models/product_variant.dart';

/// مستودع إدارة متغيرات المنتجات (المقاسات / الألوان / النكهات) في SQLite
class ProductVariantRepository {
  final AppDatabase dbHelper;

  ProductVariantRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  Future<List<ProductVariant>> getByProductId(String productId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_variants',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'variantName ASC',
    );
    return maps.map(ProductVariant.fromMap).toList();
  }

  Future<List<ProductVariant>> getActiveByProductId(String productId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_variants',
      where: 'productId = ? AND isActive = ?',
      whereArgs: [productId, 1],
      orderBy: 'variantName ASC',
    );
    return maps.map(ProductVariant.fromMap).toList();
  }

  Future<Map<String, List<ProductVariant>>> getAllGroupedByProduct() async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'product_variants',
      orderBy: 'variantName ASC',
    );
    final grouped = <String, List<ProductVariant>>{};
    for (final map in maps) {
      final variant = ProductVariant.fromMap(map);
      grouped.putIfAbsent(variant.productId, () => []).add(variant);
    }
    return grouped;
  }

  Future<Set<String>> getActiveVariantProductIds() async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT productId FROM product_variants WHERE isActive = 1',
    );
    return rows
        .map((r) => r['productId'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<void> replaceForProduct(
    String productId,
    List<ProductVariant> variants,
  ) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete(
        'product_variants',
        where: 'productId = ?',
        whereArgs: [productId],
      );
      for (final variant in variants) {
        await txn.insert(
          'product_variants',
          variant.copyWith(productId: productId).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.products);
  }

  Future<void> adjustVariantStock(String variantId, int delta) async {
    if (variantId.isEmpty || delta == 0) return;
    final db = await dbHelper.database;
    final rows = await db.query(
      'product_variants',
      columns: ['stockQuantity'],
      where: 'id = ?',
      whereArgs: [variantId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final currentQty = (rows.first['stockQuantity'] as num?)?.toInt() ?? 0;
    final updatedQty = (currentQty + delta).clamp(0, 999999);
    await db.update(
      'product_variants',
      {'stockQuantity': updatedQty},
      where: 'id = ?',
      whereArgs: [variantId],
    );
    DataSyncBus.instance.notify(DataDomain.products);
  }
}
