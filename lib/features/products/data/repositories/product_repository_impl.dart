import '../../../../core/audit/audit.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/product.dart';
import '../../domain/repositories/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  final AppDatabase _dbHelper = AppDatabase.instance;

  @override
  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', orderBy: 'createdAt DESC');
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  @override
  Future<List<Product>> getActiveProducts() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => Product.fromMap(m)).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Product.fromMap(maps.first);
  }

  @override
  Future<void> createProduct(Product product) async {
    final db = await _dbHelper.database;
    final map = product.toMap();
    await db.insert('products', map);
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.product,
      entityId: product.id,
      entityLabel: product.name,
      action: AuditAction.create,
      summary: product.name,
      after: map,
      currency: product.currency,
      sourceModule: 'products',
    );
    DataSyncBus.instance.notify(DataDomain.products);
  }

  @override
  Future<void> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    final beforeProduct = await getProductById(product.id);
    final afterMap = product.toMap();
    await db.update(
      'products',
      afterMap,
      where: 'id = ?',
      whereArgs: [product.id],
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.product,
      entityId: product.id,
      entityLabel: product.name,
      action: AuditAction.update,
      summary: product.name,
      before: beforeProduct?.toMap(),
      after: afterMap,
      currency: product.currency,
      sourceModule: 'products',
    );
    DataSyncBus.instance.notify(DataDomain.products);
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
    final beforeProduct = await getProductById(id);
    await db.transaction((txn) async {
      await txn.delete(
        'product_ingredients',
        where: 'productId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'product_variants',
        where: 'productId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'product_bundle_items',
        where: 'bundleProductId = ? OR componentProductId = ?',
        whereArgs: [id, id],
      );
      await txn.delete('products', where: 'id = ?', whereArgs: [id]);
      if (beforeProduct != null) {
        await CentralAuditService.instance.logInTxn(
          txn,
          entityType: AuditEntityType.product,
          entityId: id,
          entityLabel: beforeProduct.name,
          action: AuditAction.delete,
          summary: beforeProduct.name,
          before: beforeProduct.toMap(),
          currency: beforeProduct.currency,
          sourceModule: 'products',
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.products);
    CentralAuditService.instance.notifyAuditChanged();
  }

  @override
  Future<void> adjustStock(String id, int delta) async {
    final product = await getProductById(id);
    if (product == null || !product.trackStock) return;
    final updatedQty = (product.stockQuantity + delta).clamp(0, 999999);
    final updated = product.copyWith(stockQuantity: updatedQty);
    final db = await _dbHelper.database;
    await db.update(
      'products',
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.product,
      entityId: id,
      entityLabel: product.name,
      action: AuditAction.stockAdjust,
      summary: '${product.name}: ${product.stockQuantity} -> $updatedQty',
      before: {'stockQuantity': product.stockQuantity},
      after: {'stockQuantity': updatedQty},
      currency: product.currency,
      sourceModule: 'products',
    );
    DataSyncBus.instance.notify(DataDomain.products);
  }
}
