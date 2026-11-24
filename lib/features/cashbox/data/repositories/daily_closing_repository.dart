import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../models/daily_closing.dart';

/// مستودع سجلات الإغلاق اليومي للصندوق في SQLite
class DailyClosingRepository {
  final AppDatabase dbHelper;

  DailyClosingRepository({AppDatabase? db})
      : dbHelper = db ?? AppDatabase.instance;

  static String formatClosingDate(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(DateTime(date.year, date.month, date.day));

  Future<void> saveClosing(DailyClosing closing) async {
    final db = await dbHelper.database;
    await db.insert(
      'daily_closings',
      closing.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DailyClosing?> getClosingForDate(DateTime date) async {
    final db = await dbHelper.database;
    final dateStr = formatClosingDate(date);
    final maps = await db.query(
      'daily_closings',
      where: 'closingDate = ?',
      whereArgs: [dateStr],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return DailyClosing.fromMap(maps.first);
  }

  Future<List<DailyClosing>> getRecentClosings({int limit = 14}) async {
    final db = await dbHelper.database;
    final maps = await db.query(
      'daily_closings',
      orderBy: 'closingDate DESC, closedAt DESC',
      limit: limit,
    );
    return maps.map(DailyClosing.fromMap).toList();
  }
}
