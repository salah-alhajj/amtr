import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/audit/audit.dart';
import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../../../models/product.dart';
import '../../../../models/product_ingredient.dart';
import '../../../../models/production_batch.dart';

/// مستودع دفعات الإنتاج (تسجيل الدفعات، زيادة مخزون المنتج، خصم المواد الخام، وتسجيل المصروف اختيارياً)
class ProductionBatchRepository {
  final AppDatabase dbHelper;
  final CurrencyService currencyService;

  ProductionBatchRepository({
    AppDatabase? db,
    CurrencyService? currencyService,
  })  : dbHelper = db ?? AppDatabase.instance,
        currencyService = currencyService ?? CurrencyService.instance;

  Future<void> recordBatch(ProductionBatch batch) async {
    final db = await dbHelper.database;
    await db.insert(
      'production_batches',
      batch.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ProductionBatch>> getRecentBatches({int limit = 50}) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'production_batches',
      orderBy: 'producedAt DESC',
      limit: limit,
    );
    return rows.map(ProductionBatch.fromMap).toList();
  }

  Future<List<ProductionBatch>> getAllBatches({int limit = 200}) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'production_batches',
      orderBy: 'producedAt DESC',
      limit: limit,
    );
    return rows.map(ProductionBatch.fromMap).toList();
  }

  Future<List<ProductionBatch>> getCuringBatches() async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'production_batches',
      where: 'batchStatus = ?',
      whereArgs: [AppConstants.batchStatusCuring],
      orderBy: 'readyAt ASC',
    );
    return rows.map(ProductionBatch.fromMap).toList();
  }

  Future<List<ProductionBatch>> getByProductId(String productId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      'production_batches',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'producedAt DESC',
    );
    return rows.map(ProductionBatch.fromMap).toList();
  }

  /// إنتاج دفعة من منتج مصنّع بشكل ذري داخل معاملة SQLite:
  /// 1) إذا كانت الدفعة جاهزة فوراً (`curingDays == 0`)، زيادة `products.stockQuantity` بمقدار [yieldCount].
  ///    أما إذا كانت قيد التعتيق (`curingDays > 0`)، فلا يُضاف للمخزون الجاهز حتى يتم اعتماد جاهزيتها.
  /// 2) عند [deductMaterials]، خصم مقادير المواد الخام من `raw_materials.stockQuantity` (لا يقل عن 0).
  /// 3) حفظ سجل `ProductionBatch` في جدول `production_batches`.
  /// 4) عند [logExpense] وتكلفة > 0، تسجيل مصروف تشغيلي (`exp_cat_materials`).
  /// 5) إرسال إشعارات `DataSyncBus`.
  Future<ProductionBatch> produceBatch({
    required Product product,
    int? customYield,
    bool deductMaterials = true,
    bool logExpense = false,
    String? notes,
    int curingDays = 0,
    int shelfLifeDays = 0,
  }) async {
    final db = await dbHelper.database;
    final yieldCount = math.max(1, customYield ?? product.batchYield);
    final baseYield = math.max(1, product.batchYield);
    final batchRatio = yieldCount / baseYield;
    final producedAt = DateTime.now();
    final safeCuringDays = math.max(0, curingDays);
    final safeShelfLifeDays = math.max(0, shelfLifeDays);
    final readyAt = safeCuringDays > 0
        ? producedAt.add(Duration(days: safeCuringDays))
        : producedAt;
    final expiresAt = safeShelfLifeDays > 0
        ? readyAt.add(Duration(days: safeShelfLifeDays))
        : null;
    final batchStatus = safeCuringDays > 0
        ? AppConstants.batchStatusCuring
        : AppConstants.batchStatusReady;
    const uuid = Uuid();

    late ProductionBatch createdBatch;
    bool expenseLogged = false;

    await db.transaction((txn) async {
      // 1) زيادة مخزون المنتج فوراً فقط إذا لم تكن الدفعة قيد التعتيق
      if (safeCuringDays == 0) {
        final prodRows = await txn.query(
          'products',
          columns: ['stockQuantity'],
          where: 'id = ?',
          whereArgs: [product.id],
          limit: 1,
        );
        final currentStock = prodRows.isNotEmpty
            ? ((prodRows.first['stockQuantity'] as num?)?.toInt() ??
                product.stockQuantity)
            : product.stockQuantity;
        final updatedStock = (currentStock + yieldCount).clamp(0, 999999);
        await txn.update(
          'products',
          {'stockQuantity': updatedStock},
          where: 'id = ?',
          whereArgs: [product.id],
        );
      }

      // 2) تحميل مكونات وصفة المنتج وحساب التكلفة وخصم الخامات
      final ingRows = await txn.query(
        'product_ingredients',
        where: 'productId = ?',
        whereArgs: [product.id],
      );
      final ingredients = ingRows.map(ProductIngredient.fromMap).toList();

      double totalCost = 0.0;
      if (ingredients.isNotEmpty) {
        for (final ing in ingredients) {
          final effCost = ing.effectiveCost;
          if (effCost > 0) {
            final inProductCurrency = currencyService.convert(
              amount: effCost,
              fromCurrency: ing.currency,
              toCurrency: product.currency,
            );
            totalCost += inProductCurrency * batchRatio;
          }
        }
      } else {
        totalCost = product.costPrice * yieldCount;
      }

      if (deductMaterials && ingredients.isNotEmpty) {
        for (final ing in ingredients) {
          final matId = ing.materialId;
          if (matId == null || matId.isEmpty) continue;
          final deductQty = ing.quantity * batchRatio;
          if (deductQty <= 0) continue;

          final matRows = await txn.query(
            'raw_materials',
            columns: ['stockQuantity'],
            where: 'id = ?',
            whereArgs: [matId],
            limit: 1,
          );
          if (matRows.isEmpty) continue;
          final currentMatStock =
              (matRows.first['stockQuantity'] as num?)?.toDouble() ?? 0.0;
          final nextMatStock = math.max(0.0, currentMatStock - deductQty);
          await txn.update(
            'raw_materials',
            {'stockQuantity': nextMatStock},
            where: 'id = ?',
            whereArgs: [matId],
          );
        }
      }

      // 3) حفظ سجل دفعة الإنتاج
      final trimmedNotes =
          (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null;
      createdBatch = ProductionBatch(
        id: uuid.v4(),
        productId: product.id,
        productName: product.name,
        yieldCount: yieldCount,
        totalCost: totalCost,
        currency: product.currency,
        notes: trimmedNotes,
        producedAt: producedAt,
        batchStatus: batchStatus,
        readyAt: readyAt,
        expiresAt: expiresAt,
      );
      await txn.insert(
        'production_batches',
        createdBatch.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 4) تسجيل المصروف التشغيلي عند الطلب
      if (logExpense && totalCost > 0) {
        final expense = Expense(
          id: uuid.v4(),
          title:
              '${'mfg_batch_expense_prefix'.i18n()}: ${product.name} (×$yieldCount)',
          category: 'exp_cat_materials',
          expenseType: AppConstants.expenseTypeBusiness,
          amount: totalCost,
          currency: product.currency,
          expenseDate: producedAt,
          notes: trimmedNotes,
          supplierId: product.supplierId,
          createdAt: producedAt,
        );
        await txn.insert('expenses', expense.toMap());
        expenseLogged = true;
      }
      await CentralAuditService.instance.logInTxn(
        txn,
        entityType: AuditEntityType.productionBatch,
        entityId: createdBatch.id,
        entityLabel: product.name,
        action: AuditAction.create,
        summary: '${product.name} (×$yieldCount)',
        after: createdBatch.toMap(),
        financialImpactYer: expenseLogged
            ? -currencyService.toBaseYer(totalCost, product.currency)
            : 0.0,
        currency: product.currency,
        sourceModule: 'manufacturing',
      );
    });

    DataSyncBus.instance.notify(DataDomain.products);
    DataSyncBus.instance.notify(DataDomain.materials);
    if (expenseLogged) {
      DataSyncBus.instance.notify(DataDomain.expenses);
    }
    CentralAuditService.instance.notifyAuditChanged();

    return createdBatch;
  }

  /// اعتماد جاهزية دفعة قيد التعتيق/التخمير ونقل كميتها إلى مخزون المنتج الجاهز بشكل ذري وآمن ضد التكرار
  Future<ProductionBatch> markBatchReady(ProductionBatch batch) async {
    final db = await dbHelper.database;
    final now = DateTime.now();
    ProductionBatch resultBatch = batch;
    bool didTransition = false;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'production_batches',
        where: 'id = ?',
        whereArgs: [batch.id],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final current = ProductionBatch.fromMap(rows.first);
      if (current.batchStatus != AppConstants.batchStatusCuring) {
        resultBatch = current;
        return;
      }

      await txn.update(
        'production_batches',
        {
          'batchStatus': AppConstants.batchStatusReady,
          'readyAt': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [batch.id],
      );

      final prodRows = await txn.query(
        'products',
        columns: ['stockQuantity'],
        where: 'id = ?',
        whereArgs: [current.productId],
        limit: 1,
      );
      if (prodRows.isNotEmpty) {
        final currentStock =
            (prodRows.first['stockQuantity'] as num?)?.toInt() ?? 0;
        final updatedStock =
            (currentStock + current.yieldCount).clamp(0, 999999);
        await txn.update(
          'products',
          {'stockQuantity': updatedStock},
          where: 'id = ?',
          whereArgs: [current.productId],
        );
      }

      resultBatch = current.copyWith(
        batchStatus: AppConstants.batchStatusReady,
        readyAt: now,
      );
      didTransition = true;
      await CentralAuditService.instance.logInTxn(
        txn,
        entityType: AuditEntityType.productionBatch,
        entityId: current.id,
        entityLabel: current.productName,
        action: AuditAction.statusChange,
        summary: '${current.productName} (+${current.yieldCount})',
        before: current.toMap(),
        after: resultBatch.toMap(),
        currency: current.currency,
        sourceModule: 'manufacturing',
      );
    });

    if (didTransition) {
      DataSyncBus.instance.notify(DataDomain.products);
      CentralAuditService.instance.notifyAuditChanged();
    }

    return resultBatch;
  }
}
