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
    await db.insert('products', product.toMap());
    DataSyncBus.instance.notify(DataDomain.products);
  }

  @override
  Future<void> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    DataSyncBus.instance.notify(DataDomain.products);
  }

  @override
  Future<void> deleteProduct(String id) async {
    final db = await _dbHelper.database;
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
    });
    DataSyncBus.instance.notify(DataDomain.products);
  }

  @override
  Future<void> adjustStock(String id, int delta) async {
    final product = await getProductById(id);
    if (product == null || !product.trackStock) return;
    final updatedQty = (product.stockQuantity + delta).clamp(0, 999999);
    await updateProduct(product.copyWith(stockQuantity: updatedQty));
  }
}
