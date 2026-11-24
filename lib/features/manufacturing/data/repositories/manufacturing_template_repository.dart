import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/manufacturing_template.dart';

/// مستودع قوالب التصنيع القابلة لإعادة الاستخدام مع بنودها (مواد + تكاليف إنتاجية)
class ManufacturingTemplateRepository {
  final AppDatabase dbHelper;

  ManufacturingTemplateRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  Future<List<ManufacturingTemplate>> getAllTemplates() async {
    final db = await dbHelper.database;
    final templateMaps = await db.query(
      'manufacturing_templates',
      orderBy: 'createdAt DESC',
    );
    if (templateMaps.isEmpty) return [];

    final itemMaps = await db.query('manufacturing_template_items');
    final itemsByTemplate = <String, List<ManufacturingTemplateItem>>{};
    for (final row in itemMaps) {
      final item = ManufacturingTemplateItem.fromMap(row);
      itemsByTemplate.putIfAbsent(item.templateId, () => []).add(item);
    }

    return templateMaps.map((m) {
      final id = m['id'] as String;
      return ManufacturingTemplate.fromMap(
        m,
        items: itemsByTemplate[id] ?? const [],
      );
    }).toList();
  }

  Future<ManufacturingTemplate?> getTemplateById(String id) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'manufacturing_templates',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    final itemMaps = await db.query(
      'manufacturing_template_items',
      where: 'templateId = ?',
      whereArgs: [id],
    );
    final items = itemMaps.map(ManufacturingTemplateItem.fromMap).toList();
    return ManufacturingTemplate.fromMap(maps.first, items: items);
  }

  Future<void> saveTemplate(ManufacturingTemplate template) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert(
        'manufacturing_templates',
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'manufacturing_template_items',
        where: 'templateId = ?',
        whereArgs: [template.id],
      );
      for (final item in template.items) {
        await txn.insert(
          'manufacturing_template_items',
          item.copyWith(templateId: template.id).toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
    DataSyncBus.instance.notify(DataDomain.materials);
  }

  Future<void> deleteTemplate(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'products',
        {'templateId': null},
        where: 'templateId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'manufacturing_template_items',
        where: 'templateId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'manufacturing_templates',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    DataSyncBus.instance.notify(DataDomain.materials);
  }
}
