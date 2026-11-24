import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../../../models/whatsapp_template.dart';
import '../domain/whatsapp_template_engine.dart';

/// مستودع قوالب رسائل واتساب في قاعدة البيانات المحلية SQLite
class WhatsAppTemplateRepository {
  final AppDatabase dbHelper;

  WhatsAppTemplateRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  /// تهيئة القوالب الافتراضية إذا كان الجدول فارغاً
  Future<void> seedDefaultsIfEmpty() async {
    final db = await dbHelper.database;
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM whatsapp_templates'),
        ) ??
        0;
    if (count > 0) return;

    final batch = db.batch();
    for (final template in WhatsAppTemplateEngine.defaultTemplates) {
      batch.insert(
        'whatsapp_templates',
        template.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  /// جلب جميع القوالب المحفوظة
  Future<List<WhatsAppTemplate>> getAllTemplates() async {
    await seedDefaultsIfEmpty();
    final db = await dbHelper.database;
    final maps = await db.query('whatsapp_templates');
    return maps.map((m) => WhatsAppTemplate.fromMap(m)).toList();
  }

  /// جلب القوالب حسب النوع (confirm_deposit | ready | reminder | thanks)
  Future<List<WhatsAppTemplate>> getTemplatesByType(String type) async {
    await seedDefaultsIfEmpty();
    final db = await dbHelper.database;
    final maps = await db.query(
      'whatsapp_templates',
      where: 'type = ?',
      whereArgs: [type],
    );
    return maps.map((m) => WhatsAppTemplate.fromMap(m)).toList();
  }

  /// جلب قالب محدد حسب النوع والنبرة
  Future<WhatsAppTemplate?> getTemplate(
    String type, {
    String tone = WhatsAppTemplateEngine.toneWarm,
  }) async {
    await seedDefaultsIfEmpty();
    final db = await dbHelper.database;
    final maps = await db.query(
      'whatsapp_templates',
      where: 'type = ? AND tone = ?',
      whereArgs: [type, tone],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return WhatsAppTemplate.fromMap(maps.first);
    }
    final fallbackMaps = await db.query(
      'whatsapp_templates',
      where: 'type = ?',
      whereArgs: [type],
      limit: 1,
    );
    if (fallbackMaps.isNotEmpty) {
      return WhatsAppTemplate.fromMap(fallbackMaps.first);
    }
    return null;
  }

  /// حفظ أو تحديث قالب رسالة
  Future<void> saveTemplate(WhatsAppTemplate template) async {
    final db = await dbHelper.database;
    await db.insert(
      'whatsapp_templates',
      template.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// حذف قالب حسب المعرف
  Future<void> deleteTemplate(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'whatsapp_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
