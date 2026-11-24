import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier.dart';
import '../../domain/repositories/supplier_repository.dart';

class SupplierRepositoryImpl implements SupplierRepository {
  final AppDatabase _dbHelper = AppDatabase.instance;

  @override
  Future<List<Supplier>> getAllSuppliers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('suppliers', orderBy: 'createdAt DESC');
    return maps.map(Supplier.fromMap).toList();
  }

  @override
  Future<Supplier?> getSupplierById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Supplier.fromMap(maps.first);
  }

  @override
  Future<void> createSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.insert(
      'suppliers',
      supplier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DataSyncBus.instance.notify(DataDomain.suppliers);
  }

  @override
  Future<void> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    await db.update(
      'suppliers',
      supplier.toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    DataSyncBus.instance.notify(DataDomain.suppliers);
  }

  @override
  Future<void> deleteSupplier(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'supplierId': null},
        where: 'supplierId = ?',
        whereArgs: [id],
      );
      await txn.update(
        'raw_materials',
        {'supplierId': null},
        where: 'supplierId = ?',
        whereArgs: [id],
      );
      await txn.update(
        'expenses',
        {'supplierId': null},
        where: 'supplierId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'supplier_transactions',
        where: 'supplierId = ?',
        whereArgs: [id],
      );
      await txn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });
    DataSyncBus.instance.notify(DataDomain.suppliers);
    DataSyncBus.instance.notify(DataDomain.products);
    DataSyncBus.instance.notify(DataDomain.materials);
    DataSyncBus.instance.notify(DataDomain.expenses);
  }

  @override
  Future<Map<String, int>> getLinkedProductCounts() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT supplierId, COUNT(*) as cnt
      FROM products
      WHERE supplierId IS NOT NULL AND supplierId != ''
      GROUP BY supplierId
    ''');
    final counts = <String, int>{};
    for (final row in rows) {
      final sid = row['supplierId'] as String?;
      if (sid != null && sid.isNotEmpty) {
        counts[sid] = (row['cnt'] as num?)?.toInt() ?? 0;
      }
    }
    return counts;
  }

  @override
  Future<List<Product>> getProductsBySupplier(String supplierId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'products',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'createdAt DESC',
    );
    return maps.map(Product.fromMap).toList();
  }

  @override
  Future<List<RawMaterial>> getMaterialsBySupplier(String supplierId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'raw_materials',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'createdAt DESC',
    );
    return maps.map(RawMaterial.fromMap).toList();
  }

  @override
  Future<List<Expense>> getExpensesBySupplier(String supplierId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'expenses',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'expenseDate DESC',
    );
    return maps.map(Expense.fromMap).toList();
  }
}
