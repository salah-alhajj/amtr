import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/app_database.dart';
import '../localization/localization.dart';

/// خدمة التصدير والاستيراد لقاعدة البيانات والنسخ الاحتياطي
class BackupService {
  static final BackupService instance = BackupService._init();
  BackupService._init();

  /// تصدير قاعدة البيانات كملف JSON ومشاركته فوراً
  Future<String> exportBackupJson({Rect? sharePositionOrigin}) async {
    final data = await AppDatabase.instance.exportAllDataToJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(data);

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'mosaed_backup_$timestamp.json';
    final filePath = join(tempDir.path, fileName);

    final file = File(filePath);
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: 'backup_desc_json'.trParams({'timestamp': timestamp}),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return filePath;
  }

  /// تصدير ملف قاعدة البيانات SQLite الأصلي (.db)
  Future<String> exportRawDatabase({Rect? sharePositionOrigin}) async {
    // إتمام أي معاملات معلقة في ملف WAL ودمجها في الملف الرئيسي قبل التصدير
    try {
      final db = await AppDatabase.instance.database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL);');
    } catch (_) {}

    final originalPath = await AppDatabase.instance.getDatabaseFilePath();
    final originalFile = File(originalPath);

    if (!await originalFile.exists()) {
      throw Exception('backup_db_not_found'.i18n());
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final copyPath = join(tempDir.path, 'mosaed_backup_$timestamp.db');

    await originalFile.copy(copyPath);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(copyPath)],
        subject: 'backup_desc_raw'.trParams({'timestamp': timestamp}),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );

    return copyPath;
  }

  /// استيراد واستعادة قاعدة البيانات من ملف JSON يتم اختياره من الهاتف
  Future<bool> importBackupJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result.isEmpty || result.first.path == null) {
      return false; // المستخدم ألغى الاختيار
    }

    final file = File(result.first.path!);
    final content = await file.readAsString();
    final Map<String, dynamic> data = jsonDecode(content);

    await AppDatabase.instance.importAllDataFromJson(data);
    return true;
  }

  /// استيراد واستعادة قاعدة البيانات من ملف .db أصلي مع تنظيف ملفات WAL و SHM
  Future<bool> importRawDatabase() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db', 'sqlite'],
    );

    if (result.isEmpty || result.first.path == null) {
      return false;
    }

    final selectedPath = result.first.path!;
    final dbPath = await AppDatabase.instance.getDatabaseFilePath();

    await AppDatabase.instance.close();

    // 1. حذف ملفات WAL و SHM إن وُجدت لمنع تلف البيانات أو قراءة سجلات قديمة
    final walFile = File('$dbPath-wal');
    if (await walFile.exists()) {
      try {
        await walFile.delete();
      } catch (_) {}
    }
    final shmFile = File('$dbPath-shm');
    if (await shmFile.exists()) {
      try {
        await shmFile.delete();
      } catch (_) {}
    }

    // 2. نسخ الملف الجديد المسترجع
    final sourceFile = File(selectedPath);
    await sourceFile.copy(dbPath);

    // 3. إعادة فتح قاعدة البيانات والتحقق الصارم من سلامة البنية
    final newDb = await AppDatabase.instance.database;
    await newDb.rawQuery('PRAGMA integrity_check;');
    return true;
  }
}
