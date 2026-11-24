import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/waste_log.dart';

/// مستودع سجل الهالك والتالف (تسجيل الهدر مع خصم اختياري للمخزون داخل معاملة ذرية)
class WasteLogRepository {
  final AppDatabase dbHelper;

  WasteLogRepository({AppDatabase? db}) : dbHelper = db ?? AppDatabase.instance;

  /// تسجيل هالك/تالف جديد مع خصم تلقائي اختياري من مخزون المنتج أو المادة الخام
  Future<WasteLog> recordWaste(
    WasteLog log, {
    bool deductStock = true,
  }) async {
    final db = await dbHelper.database;

    await db.transaction((txn) async {
      await txn.insert(
        'waste_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (deductStock && log.quantity > 0) {
        if (log.isProduct) {
          final rows = await txn.query(
            'products',
            columns: ['stockQuantity'],
            where: 'id = ?',
            whereArgs: [log.itemId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final current =
                (rows.first['stockQuantity'] as num?)?.toInt() ?? 0;
            final next = math.max(0, current - log.quantity.round());
            await txn.update(
              'products',
              {'stockQuantity': next},
              where: 'id = ?',
              whereArgs: [log.itemId],
            );
          }
        } else if (log.isMaterial) {
          final rows = await txn.query(
            'raw_materials',
            columns: ['stockQuantity'],
            where: 'id = ?',
            whereArgs: [log.itemId],
            limit: 1,
          );
          if (rows.isNotEmpty) {
            final current =
                (rows.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
            final next = math.max(0.0, current - log.quantity);
            await txn.update(
              'raw_materials',
              {'stockQuantity': next},
              where: 'id = ?',
              whereArgs: [log.itemId],
            );
          }
        }
      }
    });

    DataSyncBus.instance.notify(
      log.isProduct ? DataDomain.products : DataDomain.materials,
    );
    return log;
  }

  /// جلب سجلات الهالك والتالف مرتبة من الأحدث للأقدم
  Future<List<WasteLog>> getAll({int limit = 200}) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'waste_logs',
      orderBy: 'loggedAt DESC',
      limit: limit,
    );
    return rows.map(WasteLog.fromMap).toList();
  }

  /// جلب سجلات الهالك والتالف لشهر محدد
  Future<List<WasteLog>> getByMonth(int year, int month) async {
    final db = await dbHelper.database;
    final prefix =
        '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
    final rows = await db.query(
      'waste_logs',
      where: 'loggedAt LIKE ?',
      whereArgs: ['$prefix%'],
      orderBy: 'loggedAt DESC',
    );
    return rows.map(WasteLog.fromMap).toList();
  }

  /// حذف سجل هالك محدد
  Future<void> delete(String id) async {
    final db = await dbHelper.database;
    await db.delete(
      'waste_logs',
      where: 'id = ?',
      whereArgs: [id],
    );
    DataSyncBus.instance.notify(DataDomain.materials);
  }
}
