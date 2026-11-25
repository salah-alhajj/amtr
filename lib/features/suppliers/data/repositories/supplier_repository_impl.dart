import 'package:sqflite/sqflite.dart';
import '../../../../core/audit/audit.dart';
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
    final map = supplier.toMap();
    await db.insert(
      'suppliers',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.supplier,
      entityId: supplier.id,
      entityLabel: supplier.name,
      action: AuditAction.create,
      summary: supplier.name,
      after: map,
      sourceModule: 'suppliers',
    );
    DataSyncBus.instance.notify(DataDomain.suppliers);
  }

  @override
  Future<void> updateSupplier(Supplier supplier) async {
    final db = await _dbHelper.database;
    final beforeSupplier = await getSupplierById(supplier.id);
    final afterMap = supplier.toMap();
    await db.update(
      'suppliers',
      afterMap,
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.supplier,
      entityId: supplier.id,
      entityLabel: supplier.name,
      action: AuditAction.update,
      summary: supplier.name,
      before: beforeSupplier?.toMap(),
      after: afterMap,
      sourceModule: 'suppliers',
    );
    DataSyncBus.instance.notify(DataDomain.suppliers);
  }

  @override
  Future<void> deleteSupplier(String id) async {
    final db = await _dbHelper.database;
    final beforeSupplier = await getSupplierById(id);
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
      if (beforeSupplier != null) {
        await CentralAuditService.instance.logInTxn(
          txn,
          entityType: AuditEntityType.supplier,
          entityId: id,
          entityLabel: beforeSupplier.name,
          action: AuditAction.delete,
          summary: beforeSupplier.name,
          before: beforeSupplier.toMap(),
          sourceModule: 'suppliers',
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.suppliers);
    DataSyncBus.instance.notify(DataDomain.products);
    DataSyncBus.instance.notify(DataDomain.materials);
    DataSyncBus.instance.notify(DataDomain.expenses);
    CentralAuditService.instance.notifyAuditChanged();
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
