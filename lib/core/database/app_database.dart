import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// المحرك المحلي لقاعدة البيانات SQLite
/// يدعم جميع العمليات المحلية وحفظ البيانات بدون إنترنت مع التصدير والاستيراد.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._init();
  static Database? _database;

  AppDatabase._init();

  static void setTestDatabase(Database? db) {
    _database = db;
  }

  Future<void> createDBForTesting(Database db) async {
    await _createDB(db, 1);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('amtr_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE orders ADD COLUMN debtDueDate TEXT;');
      await db.execute('ALTER TABLE orders ADD COLUMN hasDebtReminder INTEGER DEFAULT 0;');
      await db.execute('ALTER TABLE orders ADD COLUMN isSyncedWithCalendar INTEGER DEFAULT 0;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE customers ADD COLUMN whatsapp TEXT;');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE orders ADD COLUMN additionalCost REAL DEFAULT 0.0;');
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // جدول أسعار الصرف (القاعدة الريال اليمني YER)
    await db.execute('''
      CREATE TABLE exchange_rates (
        id TEXT PRIMARY KEY,
        sarToYer REAL NOT NULL,
        usdToYer REAL NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // جدول العملاء
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        whatsapp TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // جدول الشحنات المجمعة (الحمولة)
    await db.execute('''
      CREATE TABLE shipments (
        id TEXT PRIMARY KEY,
        shipmentNumber TEXT NOT NULL,
        title TEXT NOT NULL,
        carrierName TEXT,
        trackingNumber TEXT,
        transportCost REAL NOT NULL,
        transportCostCurrency TEXT NOT NULL,
        status TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        expectedDeliveryDate TEXT,
        actualDeliveryDate TEXT,
        notes TEXT
      )
    ''');

    // جدول الطلبات الفردية
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        orderNumber TEXT NOT NULL,
        customerId TEXT,
        customerName TEXT,
        shipmentId TEXT,
        paymentStatus TEXT NOT NULL,
        orderStatus TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        expectedDeliveryDate TEXT,
        actualDeliveryDate TEXT,
        debtDueDate TEXT,
        hasDebtReminder INTEGER DEFAULT 0,
        isSyncedWithCalendar INTEGER DEFAULT 0,
        paidAmount REAL NOT NULL,
        additionalCost REAL DEFAULT 0.0,
        currency TEXT NOT NULL,
        notes TEXT,
        FOREIGN KEY (customerId) REFERENCES customers (id) ON DELETE SET NULL,
        FOREIGN KEY (shipmentId) REFERENCES shipments (id) ON DELETE SET NULL
      )
    ''');

    // جدول الأغراض والبنود المفصلة داخل كل طلب فردي
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        quantity INTEGER NOT NULL,
        costPrice REAL NOT NULL,
        sellPrice REAL,
        currency TEXT NOT NULL,
        photos TEXT NOT NULL,
        FOREIGN KEY (orderId) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // تهيئة أولية لأسعار الصرف الافتراضية
    await db.insert('exchange_rates', {
      'id': 'default_rates',
      'sarToYer': 535.0, // افتراضي 1 ريال سعودي = 535 ريال يمني
      'usdToYer': 2040.0, // افتراضي 1 دولار أمريكي = 2040 ريال يمني
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// مسار ملف قاعدة البيانات الفعلي للاستخدام في التصدير
  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'amtr_local.db');
  }

  /// تصدير كامل بيانات التطبيق في ملف JSON موحد مع تضمين صور السلع المرفقة
  Future<Map<String, dynamic>> exportAllDataToJson() async {
    final db = await database;
    final customers = await db.query('customers');
    final shipments = await db.query('shipments');
    final orders = await db.query('orders');
    final orderItems = await db.query('order_items');
    final exchangeRates = await db.query('exchange_rates');

    // تضمين ملفات الصور المرفقة كـ Base64 لضمان عدم ضياعها
    final photosData = <String, String>{};
    for (final item in orderItems) {
      if (item['photos'] != null) {
        try {
          final decoded = jsonDecode(item['photos'] as String);
          if (decoded is List) {
            for (final p in decoded) {
              final pathStr = p.toString();
              final file = File(pathStr);
              if (await file.exists()) {
                final fileName = basename(pathStr);
                final bytes = await file.readAsBytes();
                photosData[fileName] = base64Encode(bytes);
              }
            }
          }
        } catch (_) {}
      }
    }

    return {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'customers': customers,
      'shipments': shipments,
      'orders': orders,
      'order_items': orderItems,
      'exchange_rates': exchangeRates,
      'photos_data': photosData,
    };
  }

  /// استيراد كامل البيانات من JSON واستعادة الصور لمجلد المستندات الدائم
  Future<void> importAllDataFromJson(Map<String, dynamic> data) async {
    // 1. استعادة وتفريغ الصور إلى مجلد المستندات الدائم
    final restoredPhotosMap = <String, String>{};
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(join(docsDir.path, 'amtr_photos'));
      if (!photosDir.existsSync()) {
        await photosDir.create(recursive: true);
      }

      if (data['photos_data'] is Map) {
        final photosMap = data['photos_data'] as Map;
        for (final entry in photosMap.entries) {
          try {
            final fileName = entry.key.toString();
            final bytes = base64Decode(entry.value.toString());
            final targetPath = join(photosDir.path, fileName);
            final targetFile = File(targetPath);
            await targetFile.writeAsBytes(bytes);
            restoredPhotosMap[fileName] = targetPath;
          } catch (_) {}
        }
      }
    } catch (_) {}

    // 2. تحديث قاعدة البيانات ضمن معاملة آمنة
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('order_items');
      await txn.delete('orders');
      await txn.delete('shipments');
      await txn.delete('customers');
      await txn.delete('exchange_rates');

      if (data['customers'] is List) {
        for (final item in data['customers']) {
          await txn.insert('customers', Map<String, dynamic>.from(item as Map));
        }
      }
      if (data['shipments'] is List) {
        for (final item in data['shipments']) {
          await txn.insert('shipments', Map<String, dynamic>.from(item as Map));
        }
      }
      if (data['orders'] is List) {
        for (final item in data['orders']) {
          await txn.insert('orders', Map<String, dynamic>.from(item as Map));
        }
      }
      if (data['order_items'] is List) {
        for (final item in data['order_items']) {
          final itemMap = Map<String, dynamic>.from(item as Map);
          if (itemMap['photos'] != null && restoredPhotosMap.isNotEmpty) {
            try {
              final decoded = jsonDecode(itemMap['photos'] as String);
              if (decoded is List) {
                final updatedList = decoded.map((p) {
                  final fn = basename(p.toString());
                  return restoredPhotosMap[fn] ?? p.toString();
                }).toList();
                itemMap['photos'] = jsonEncode(updatedList);
              }
            } catch (_) {}
          }
          await txn.insert('order_items', itemMap);
        }
      }
      if (data['exchange_rates'] is List) {
        for (final item in data['exchange_rates']) {
          await txn.insert('exchange_rates', Map<String, dynamic>.from(item as Map));
        }
      }
    });
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
