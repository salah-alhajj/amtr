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
    await _createDB(db, 13);
  }

  Future<void> upgradeDBForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    await _upgradeDB(db, oldVersion, newVersion);
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mosaed_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // الهجرة التلقائية السلسة من اسم قاعدة البيانات القديم إن وُجد
    final legacyPath = join(dbPath, 'amtr_local.db');
    if (!await databaseExists(path) && await databaseExists(legacyPath)) {
      try {
        final legacyFile = File(legacyPath);
        if (await legacyFile.exists()) {
          await legacyFile.copy(path);
        }
      } catch (_) {}
    }

    return await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addColumnIfMissing(db, 'orders', 'debtDueDate TEXT');
      await _addColumnIfMissing(
        db,
        'orders',
        'hasDebtReminder INTEGER DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'isSyncedWithCalendar INTEGER DEFAULT 0',
      );
    }
    if (oldVersion < 3) {
      await _addColumnIfMissing(db, 'customers', 'whatsapp TEXT');
    }
    if (oldVersion < 4) {
      await _addColumnIfMissing(
        db,
        'orders',
        'additionalCost REAL DEFAULT 0.0',
      );
    }
    if (oldVersion < 5) {
      await _addColumnIfMissing(db, 'orders', 'discount REAL DEFAULT 0.0');
      await _addColumnIfMissing(db, 'orders', 'deliveryFee REAL DEFAULT 0.0');
      await _addColumnIfMissing(
        db,
        'orders',
        "deliveryType TEXT DEFAULT 'pickup'",
      );
      await _addColumnIfMissing(db, 'orders', 'deliveryAddress TEXT');
      await _createMicroBusinessTables(db);
    }
    if (oldVersion < 6) {
      await _addColumnIfMissing(
        db,
        'expenses',
        "expenseType TEXT DEFAULT 'business'",
      );
      await _addColumnIfMissing(db, 'orders', 'isQuickOrder INTEGER DEFAULT 0');
      await _addColumnIfMissing(db, 'orders', 'occasionLabel TEXT');
      await _addColumnIfMissing(db, 'orders', 'prepReminderAt TEXT');
      await _addColumnIfMissing(db, 'order_items', 'productId TEXT');
      await _createPaymentTransactionsTable(db);
      await _createPerformanceIndexes(db);

      // Backfill لحركات الدفع السابقة من الطلبات القائمة
      await db.execute('''
        INSERT OR IGNORE INTO payment_transactions (id, orderId, customerId, amount, currency, paymentMethod, paidAt, notes)
        SELECT 'backfill_' || id, id, customerId, paidAmount, currency, 'cash', createdAt, orderNumber
        FROM orders
        WHERE paidAmount > 0
      ''');
    }
    if (oldVersion < 7) {
      await _createPhase2Tables(db);
    }
    if (oldVersion < 8) {
      await _addColumnIfMissing(db, 'customers', 'preferences TEXT');
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(db, 'products', 'supplierId TEXT');
      await _addColumnIfMissing(
        db,
        'products',
        "productType TEXT NOT NULL DEFAULT 'resale'",
      );
      await _addColumnIfMissing(
        db,
        'products',
        'batchYield INTEGER NOT NULL DEFAULT 1',
      );
      await _addColumnIfMissing(db, 'products', 'templateId TEXT');

      await _addColumnIfMissing(
        db,
        'product_ingredients',
        "itemType TEXT NOT NULL DEFAULT 'material'",
      );
      await _addColumnIfMissing(db, 'product_ingredients', 'materialId TEXT');
      await _addColumnIfMissing(
        db,
        'product_ingredients',
        'quantity REAL NOT NULL DEFAULT 1.0',
      );
      await _addColumnIfMissing(db, 'product_ingredients', 'unit TEXT');
      await _addColumnIfMissing(
        db,
        'product_ingredients',
        'unitCost REAL NOT NULL DEFAULT 0.0',
      );

      await _addColumnIfMissing(
        db,
        'expenses',
        "recurrence TEXT NOT NULL DEFAULT 'once'",
      );
      await _addColumnIfMissing(
        db,
        'expenses',
        'isPettyCash INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(db, 'expenses', 'supplierId TEXT');

      await _createV9Tables(db);
    }
    if (oldVersion < 10) {
      await _addColumnIfMissing(db, 'expenses', 'receiptPhotoPath TEXT');
      await _addColumnIfMissing(db, 'expenses', 'parentRuleId TEXT');
      await _addColumnIfMissing(
        db,
        'raw_materials',
        'stockQuantity REAL NOT NULL DEFAULT 0.0',
      );
      await _addColumnIfMissing(
        db,
        'raw_materials',
        'lowStockThreshold REAL NOT NULL DEFAULT 0.0',
      );
      await _createV10Tables(db);
    }
    if (oldVersion < 11) {
      await _addColumnIfMissing(db, 'orders', 'courierId TEXT');
      await _addColumnIfMissing(
        db,
        'orders',
        "courierStatus TEXT NOT NULL DEFAULT 'none'",
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'courierFee REAL NOT NULL DEFAULT 0.0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'isSettledWithCourier INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'customers',
        'returnCount INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'products',
        'reorderCycleDays INTEGER NOT NULL DEFAULT 0',
      );
      await _createV11Tables(db);
    }
    if (oldVersion < 12) {
      await _addColumnIfMissing(
        db,
        'products',
        'isBundle INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'requiresDeposit INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        'orders',
        'depositAmount REAL NOT NULL DEFAULT 0.0',
      );
      await _addColumnIfMissing(db, 'order_items', 'variantId TEXT');
      await _addColumnIfMissing(db, 'order_items', 'variantName TEXT');
      await _addColumnIfMissing(
        db,
        'production_batches',
        "batchStatus TEXT NOT NULL DEFAULT 'ready'",
      );
      await _addColumnIfMissing(db, 'production_batches', 'readyAt TEXT');
      await _addColumnIfMissing(db, 'production_batches', 'expiresAt TEXT');
      await _createV12Tables(db);
    }
    if (oldVersion < 13) {
      await _createV13Tables(db);
    }
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String columnDef,
  ) async {
    final columnName = columnDef.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final cols = await db.rawQuery('PRAGMA table_info($table);');
    final exists = cols.any(
      (c) => (c['name']?.toString().toLowerCase() ?? '') == columnName,
    );
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDef;');
    }
  }

  Future<void> _createV9Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        whatsapp TEXT,
        category TEXT DEFAULT 'sup_cat_general',
        address TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_materials (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        unitCost REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL,
        supplierId TEXT,
        notes TEXT,
        stockQuantity REAL NOT NULL DEFAULT 0.0,
        lowStockThreshold REAL NOT NULL DEFAULT 0.0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS manufacturing_templates (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        yieldCount INTEGER NOT NULL DEFAULT 1,
        currency TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS manufacturing_template_items (
        id TEXT PRIMARY KEY,
        templateId TEXT NOT NULL,
        itemType TEXT NOT NULL DEFAULT 'material',
        materialId TEXT,
        name TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT,
        unitCost REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL,
        FOREIGN KEY (templateId) REFERENCES manufacturing_templates (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_supplierId ON products(supplierId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_type ON products(productType);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_recurrence ON expenses(recurrence, isPettyCash);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_raw_materials_supplierId ON raw_materials(supplierId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_mfg_template_items_templateId ON manufacturing_template_items(templateId);',
    );
  }

  Future<void> _createV10Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS production_batches (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        productName TEXT NOT NULL,
        yieldCount INTEGER NOT NULL,
        totalCost REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL,
        notes TEXT,
        producedAt TEXT NOT NULL,
        batchStatus TEXT NOT NULL DEFAULT 'ready',
        readyAt TEXT,
        expiresAt TEXT
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_production_batches_productId ON production_batches(productId);',
    );
  }

  Future<void> _createV11Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_transactions (
        id TEXT PRIMARY KEY,
        supplierId TEXT NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        notes TEXT,
        receiptPhotoPath TEXT,
        txDate TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS couriers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        phone TEXT,
        whatsapp TEXT,
        defaultFee REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS courier_settlements (
        id TEXT PRIMARY KEY,
        courierId TEXT NOT NULL,
        orderCount INTEGER NOT NULL DEFAULT 0,
        collectedCashYer REAL NOT NULL DEFAULT 0.0,
        deliveryFeesYer REAL NOT NULL DEFAULT 0.0,
        returnFeesYer REAL NOT NULL DEFAULT 0.0,
        netRemittedYer REAL NOT NULL DEFAULT 0.0,
        notes TEXT,
        settledAt TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_supplier_tx_supplierId ON supplier_transactions(supplierId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_courier_settlements_courierId ON courier_settlements(courierId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_courierId ON orders(courierId, courierStatus);',
    );
  }

  Future<void> _createV12Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_variants (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        variantName TEXT NOT NULL,
        sku TEXT,
        costPrice REAL,
        sellPrice REAL,
        stockQuantity INTEGER NOT NULL DEFAULT 0,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_bundle_items (
        id TEXT PRIMARY KEY,
        bundleProductId TEXT NOT NULL,
        componentProductId TEXT NOT NULL,
        componentName TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS waste_logs (
        id TEXT PRIMARY KEY,
        itemType TEXT NOT NULL,
        itemId TEXT NOT NULL,
        itemName TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT NOT NULL,
        estimatedLossYer REAL NOT NULL DEFAULT 0.0,
        reason TEXT NOT NULL DEFAULT 'spoiled',
        notes TEXT,
        loggedAt TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_variants_productId ON product_variants(productId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_bundle_items_bundleId ON product_bundle_items(bundleProductId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_waste_logs_loggedAt ON waste_logs(loggedAt);',
    );
  }

  Future<void> _createPhase2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS whatsapp_templates (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        tone TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        isDefault INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_ingredients (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        name TEXT NOT NULL,
        cost REAL NOT NULL,
        currency TEXT NOT NULL,
        yieldCount INTEGER DEFAULT 1,
        itemType TEXT NOT NULL DEFAULT 'material',
        materialId TEXT,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit TEXT,
        unitCost REAL NOT NULL DEFAULT 0.0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_closings (
        id TEXT PRIMARY KEY,
        closingDate TEXT UNIQUE NOT NULL,
        cashInYer REAL NOT NULL,
        businessExpensesYer REAL NOT NULL,
        personalDrawingsYer REAL NOT NULL,
        ordersCount INTEGER DEFAULT 0,
        notes TEXT,
        closedAt TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_product_ingredients_productId ON product_ingredients(productId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_daily_closings_date ON daily_closings(closingDate);',
    );
  }

  Future<void> _createPaymentTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_transactions (
        id TEXT PRIMARY KEY,
        orderId TEXT,
        customerId TEXT,
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        paymentMethod TEXT NOT NULL DEFAULT 'cash',
        paidAt TEXT NOT NULL,
        notes TEXT
      )
    ''');
  }

  Future<void> _createPerformanceIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_orderId ON order_items(orderId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_productId ON order_items(productId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_status_delivery ON orders(orderStatus, expectedDeliveryDate);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_customerId ON orders(customerId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_paidAt ON payment_transactions(paidAt);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date_type ON expenses(expenseDate, expenseType);',
    );
  }

  Future<void> _createMicroBusinessTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        costPrice REAL NOT NULL DEFAULT 0.0,
        sellPrice REAL NOT NULL DEFAULT 0.0,
        currency TEXT NOT NULL,
        stockQuantity INTEGER DEFAULT 0,
        trackStock INTEGER DEFAULT 0,
        lowStockThreshold INTEGER DEFAULT 3,
        isActive INTEGER DEFAULT 1,
        notes TEXT,
        supplierId TEXT,
        productType TEXT NOT NULL DEFAULT 'resale',
        batchYield INTEGER NOT NULL DEFAULT 1,
        templateId TEXT,
        reorderCycleDays INTEGER NOT NULL DEFAULT 0,
        isBundle INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        category TEXT NOT NULL,
        expenseType TEXT DEFAULT 'business',
        amount REAL NOT NULL,
        currency TEXT NOT NULL,
        expenseDate TEXT NOT NULL,
        notes TEXT,
        recurrence TEXT NOT NULL DEFAULT 'once',
        isPettyCash INTEGER NOT NULL DEFAULT 0,
        supplierId TEXT,
        receiptPhotoPath TEXT,
        parentRuleId TEXT,
        createdAt TEXT NOT NULL
      )
    ''');
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
        preferences TEXT,
        returnCount INTEGER NOT NULL DEFAULT 0,
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
        discount REAL DEFAULT 0.0,
        deliveryFee REAL DEFAULT 0.0,
        deliveryType TEXT DEFAULT 'pickup',
        deliveryAddress TEXT,
        isQuickOrder INTEGER DEFAULT 0,
        occasionLabel TEXT,
        prepReminderAt TEXT,
        courierId TEXT,
        courierStatus TEXT NOT NULL DEFAULT 'none',
        courierFee REAL NOT NULL DEFAULT 0.0,
        isSettledWithCourier INTEGER NOT NULL DEFAULT 0,
        requiresDeposit INTEGER NOT NULL DEFAULT 0,
        depositAmount REAL NOT NULL DEFAULT 0.0,
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
        productId TEXT,
        variantId TEXT,
        variantName TEXT,
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

    await _createMicroBusinessTables(db);
    await _createPaymentTransactionsTable(db);
    await _createPhase2Tables(db);
    await _createV9Tables(db);
    await _createV10Tables(db);
    await _createV11Tables(db);
    await _createV12Tables(db);
    await _createV13Tables(db);
    await _createPerformanceIndexes(db);
  }

  Future<void> _createV13Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id TEXT PRIMARY KEY,
        sequenceNo INTEGER NOT NULL DEFAULT 0,
        entityType TEXT NOT NULL,
        entityId TEXT NOT NULL,
        entityLabel TEXT NOT NULL,
        action TEXT NOT NULL,
        summary TEXT NOT NULL,
        beforeJson TEXT,
        afterJson TEXT,
        diffJson TEXT NOT NULL,
        changedFieldsCount INTEGER NOT NULL DEFAULT 0,
        financialImpactYer REAL NOT NULL DEFAULT 0.0,
        currency TEXT,
        actorLabel TEXT NOT NULL DEFAULT 'owner',
        sourceModule TEXT NOT NULL DEFAULT 'app',
        checksum TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_createdAt ON audit_logs(createdAt DESC, sequenceNo DESC);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entityType, entityId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);',
    );
  }

  /// مسار ملف قاعدة البيانات الفعلي للاستخدام في التصدير
  Future<String> getDatabaseFilePath() async {
    final dbPath = await getDatabasesPath();
    final newPath = join(dbPath, 'mosaed_local.db');
    if (await databaseExists(newPath)) return newPath;
    final legacyPath = join(dbPath, 'amtr_local.db');
    if (await databaseExists(legacyPath)) return legacyPath;
    return newPath;
  }

  /// تصدير كامل بيانات التطبيق في ملف JSON موحد مع تضمين صور السلع المرفقة
  Future<Map<String, dynamic>> exportAllDataToJson() async {
    final db = await database;
    final customers = await db.query('customers');
    final shipments = await db.query('shipments');
    final orders = await db.query('orders');
    final orderItems = await db.query('order_items');
    final exchangeRates = await db.query('exchange_rates');
    final products = await db.query('products');
    final expenses = await db.query('expenses');
    final paymentTransactions = await db.query('payment_transactions');
    final whatsappTemplates = await db.query('whatsapp_templates');
    final productIngredients = await db.query('product_ingredients');
    final dailyClosings = await db.query('daily_closings');
    final suppliers = await db.query('suppliers');
    final rawMaterials = await db.query('raw_materials');
    final manufacturingTemplates = await db.query('manufacturing_templates');
    final manufacturingTemplateItems =
        await db.query('manufacturing_template_items');
    final productionBatches = await db.query('production_batches');
    final supplierTransactions = await db.query('supplier_transactions');
    final couriers = await db.query('couriers');
    final courierSettlements = await db.query('courier_settlements');
    final productVariants = await db.query('product_variants');
    final productBundleItems = await db.query('product_bundle_items');
    final wasteLogs = await db.query('waste_logs');
    List<Map<String, dynamic>> auditLogs = const [];
    try {
      auditLogs = await db.query('audit_logs');
    } catch (_) {}

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
      'products': products,
      'expenses': expenses,
      'payment_transactions': paymentTransactions,
      'whatsapp_templates': whatsappTemplates,
      'product_ingredients': productIngredients,
      'daily_closings': dailyClosings,
      'suppliers': suppliers,
      'raw_materials': rawMaterials,
      'manufacturing_templates': manufacturingTemplates,
      'manufacturing_template_items': manufacturingTemplateItems,
      'production_batches': productionBatches,
      'supplier_transactions': supplierTransactions,
      'couriers': couriers,
      'courier_settlements': courierSettlements,
      'product_variants': productVariants,
      'product_bundle_items': productBundleItems,
      'waste_logs': wasteLogs,
      'audit_logs': auditLogs,
      'photos_data': photosData,
    };
  }

  /// استيراد كامل البيانات من JSON واستعادة الصور لمجلد المستندات الدائم
  Future<void> importAllDataFromJson(Map<String, dynamic> data) async {
    // 1. استعادة وتفريغ الصور إلى مجلد المستندات الدائم
    final restoredPhotosMap = <String, String>{};
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final photosDir = Directory(join(docsDir.path, 'mosaed_photos'));
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
      await txn.delete('payment_transactions');
      await txn.delete('whatsapp_templates');
      await txn.delete('product_ingredients');
      await txn.delete('product_variants');
      await txn.delete('product_bundle_items');
      await txn.delete('waste_logs');
      try {
        await txn.delete('audit_logs');
      } catch (_) {}
      await txn.delete('daily_closings');
      await txn.delete('manufacturing_template_items');
      await txn.delete('manufacturing_templates');
      await txn.delete('production_batches');
      await txn.delete('supplier_transactions');
      await txn.delete('courier_settlements');
      await txn.delete('couriers');
      await txn.delete('raw_materials');
      await txn.delete('suppliers');
      await txn.delete('orders');
      await txn.delete('shipments');
      await txn.delete('customers');
      await txn.delete('exchange_rates');
      await txn.delete('products');
      await txn.delete('expenses');

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
      if (data['products'] is List) {
        for (final item in data['products']) {
          await txn.insert('products', Map<String, dynamic>.from(item as Map));
        }
      }
      if (data['expenses'] is List) {
        for (final item in data['expenses']) {
          await txn.insert('expenses', Map<String, dynamic>.from(item as Map));
        }
      }
      if (data['payment_transactions'] is List) {
        for (final item in data['payment_transactions']) {
          await txn.insert(
            'payment_transactions',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['whatsapp_templates'] is List) {
        for (final item in data['whatsapp_templates']) {
          await txn.insert(
            'whatsapp_templates',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['product_ingredients'] is List) {
        for (final item in data['product_ingredients']) {
          await txn.insert(
            'product_ingredients',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['daily_closings'] is List) {
        for (final item in data['daily_closings']) {
          await txn.insert(
            'daily_closings',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['suppliers'] is List) {
        for (final item in data['suppliers']) {
          await txn.insert(
            'suppliers',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['raw_materials'] is List) {
        for (final item in data['raw_materials']) {
          await txn.insert(
            'raw_materials',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['manufacturing_templates'] is List) {
        for (final item in data['manufacturing_templates']) {
          await txn.insert(
            'manufacturing_templates',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['manufacturing_template_items'] is List) {
        for (final item in data['manufacturing_template_items']) {
          await txn.insert(
            'manufacturing_template_items',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['production_batches'] is List) {
        for (final item in data['production_batches']) {
          await txn.insert(
            'production_batches',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['supplier_transactions'] is List) {
        for (final item in data['supplier_transactions']) {
          await txn.insert(
            'supplier_transactions',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['couriers'] is List) {
        for (final item in data['couriers']) {
          await txn.insert(
            'couriers',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['courier_settlements'] is List) {
        for (final item in data['courier_settlements']) {
          await txn.insert(
            'courier_settlements',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['product_variants'] is List) {
        for (final item in data['product_variants']) {
          await txn.insert(
            'product_variants',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['product_bundle_items'] is List) {
        for (final item in data['product_bundle_items']) {
          await txn.insert(
            'product_bundle_items',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['waste_logs'] is List) {
        for (final item in data['waste_logs']) {
          await txn.insert(
            'waste_logs',
            Map<String, dynamic>.from(item as Map),
          );
        }
      }
      if (data['audit_logs'] is List) {
        try {
          for (final item in data['audit_logs']) {
            await txn.insert(
              'audit_logs',
              Map<String, dynamic>.from(item as Map),
            );
          }
        } catch (_) {}
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
