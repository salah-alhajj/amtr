import 'package:sqflite/sqflite.dart';
import '../../../../core/audit/audit.dart';
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
    final beforeMat = await getById(material.id);
    final afterMap = material.toMap();
    await db.insert(
      'raw_materials',
      afterMap,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.material,
      entityId: material.id,
      entityLabel: material.name,
      action: beforeMat == null ? AuditAction.create : AuditAction.update,
      summary: material.name,
      before: beforeMat?.toMap(),
      after: afterMap,
      currency: material.currency,
      sourceModule: 'manufacturing',
    );
    DataSyncBus.instance.notify(DataDomain.materials);
  }

  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    final beforeMat = await getById(id);
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
      if (beforeMat != null) {
        await CentralAuditService.instance.logInTxn(
          txn,
          entityType: AuditEntityType.material,
          entityId: id,
          entityLabel: beforeMat.name,
          action: AuditAction.delete,
          summary: beforeMat.name,
          before: beforeMat.toMap(),
          currency: beforeMat.currency,
          sourceModule: 'manufacturing',
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.materials);
    CentralAuditService.instance.notifyAuditChanged();
  }
}
