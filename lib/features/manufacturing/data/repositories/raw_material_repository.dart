import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/raw_material.dart';

/// مستودع مكتبة المواد الخام والموارد الإنتاجية القابلة لإعادة الاستخدام
class RawMaterialRepository {
  final AppDatabase dbHelper;

  RawMaterialRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  Future<List<RawMaterial>> getAll() async {
    final db = await dbHelper.database;
    final maps = await db.query('raw_materials', orderBy: 'createdAt DESC');
    return maps.map(RawMaterial.fromMap).toList();
  }

  Future<RawMaterial?> getById(String id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'raw_materials',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RawMaterial.fromMap(maps.first);
  }

  Future<List<RawMaterial>> getBySupplierId(String supplierId) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'raw_materials',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'createdAt DESC',
    );
    return maps.map(RawMaterial.fromMap).toList();
  }

  Future<void> save(RawMaterial material) async {
    final db = await dbHelper.database;
    await db.insert(
      'raw_materials',
      material.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DataSyncBus.instance.notify(DataDomain.materials);
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'product_ingredients',
        {'materialId': null},
        where: 'materialId = ?',
        whereArgs: [id],
      );
      await txn.update(
        'manufacturing_template_items',
        {'materialId': null},
        where: 'materialId = ?',
        whereArgs: [id],
      );
      await txn.delete('raw_materials', where: 'id = ?', whereArgs: [id]);
    });
    DataSyncBus.instance.notify(DataDomain.materials);
  }
}
