import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/audit/audit.dart';
import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../../../models/supplier_transaction.dart';

/// ملخص رصيد حساب المورد بالعملة الأساسية (ريال يمني)
class SupplierBalanceSummary {
  final double totalCreditPurchasesYer;
  final double totalCashPurchasesYer;
  final double totalPaymentsYer;
  final double payableBalanceYer;

  const SupplierBalanceSummary({
    this.totalCreditPurchasesYer = 0.0,
    this.totalCashPurchasesYer = 0.0,
    this.totalPaymentsYer = 0.0,
    double? payableBalanceYer,
  }) : payableBalanceYer =
            payableBalanceYer ?? (totalCreditPurchasesYer - totalPaymentsYer);

  static const SupplierBalanceSummary zero = SupplierBalanceSummary();

  double get totalPurchasesYer =>
      totalCreditPurchasesYer + totalCashPurchasesYer;
}

/// مستودع دفتر حساب الموردين (شراء آجل، شراء نقدي، دفعات سداد)
class SupplierLedgerRepository {
  final AppDatabase _dbHelper;
  final CurrencyService _currencyService;

  SupplierLedgerRepository({
    AppDatabase? dbHelper,
    CurrencyService? currencyService,
  })  : _dbHelper = dbHelper ?? AppDatabase.instance,
        _currencyService = currencyService ?? CurrencyService.instance;

  /// جلب جميع الحركات المالية المسجلة لمورد محدد مرتبة من الأحدث للأقدم
  Future<List<SupplierTransaction>> getTransactions(String supplierId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'supplier_transactions',
      where: 'supplierId = ?',
      whereArgs: [supplierId],
      orderBy: 'txDate DESC, createdAt DESC',
    );
    return maps.map(SupplierTransaction.fromMap).toList();
  }

  /// حساب ملخص رصيد مورد محدد بالريال اليمني
  Future<SupplierBalanceSummary> getBalanceSummary(String supplierId) async {
    final transactions = await getTransactions(supplierId);
    double totalCreditYer = 0.0;
    double totalCashYer = 0.0;
    double totalPaymentsYer = 0.0;

    for (final tx in transactions) {
      final amountYer = _currencyService.toBaseYer(tx.amount, tx.currency);
      if (tx.isCreditPurchase) {
        totalCreditYer += amountYer;
      } else if (tx.isCashPurchase) {
        totalCashYer += amountYer;
      } else if (tx.isPayment) {
        totalPaymentsYer += amountYer;
      }
    }

    return SupplierBalanceSummary(
      totalCreditPurchasesYer: totalCreditYer,
      totalCashPurchasesYer: totalCashYer,
      totalPaymentsYer: totalPaymentsYer,
    );
  }

  /// جلب الأرصدة المستحقة لكل الموردين بالريال اليمني (موجب = للمورد عندي)
  Future<Map<String, double>> getAllBalancesYer() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'supplier_transactions',
      columns: ['supplierId', 'type', 'amount', 'currency'],
    );
    final balances = <String, double>{};

    for (final row in rows) {
      final supplierId = row['supplierId'] as String?;
      if (supplierId == null || supplierId.isEmpty) continue;
      final type = row['type'] as String? ?? '';
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      final currency =
          (row['currency'] as String?) ?? AppConstants.currencyYer;
      final amountYer = _currencyService.toBaseYer(amount, currency);

      if (type == AppConstants.supplierTxPurchaseCredit) {
        balances[supplierId] = (balances[supplierId] ?? 0.0) + amountYer;
      } else if (type == AppConstants.supplierTxPayment) {
        balances[supplierId] = (balances[supplierId] ?? 0.0) - amountYer;
      }
    }

    return balances;
  }

  /// إجمالي المبالغ المستحقة للموردين (مجموع الأرصدة الموجبة فقط)
  Future<double> getTotalPayablesYer() async {
    final balances = await getAllBalancesYer();
    double total = 0.0;
    for (final balance in balances.values) {
      if (balance > 0) {
        total += balance;
      }
    }
    return total;
  }

  /// تسجيل حركة جديدة في دفتر حساب المورد
  /// - الشراء النقدي والسداد يسجلان تلقائياً مصروف شغل في الصندوق ضمن نفس المعاملة
  /// - الشراء الآجل يزيد الرصيد المستحق للمورد فقط دون خصم فوري من الصندوق
  /// - عند تمرير [stockItemId] و [stockQuantity] > 0 في عملية شراء، يُحدَّث مخزون المنتج أو المادة الخام ضمن نفس المعاملة الذرية
  Future<void> recordTransaction(
    SupplierTransaction tx, {
    required String supplierName,
    String? stockItemType,
    String? stockItemId,
    double stockQuantity = 0.0,
  }) async {
    final db = await _dbHelper.database;
    final affectsCashBox = tx.isCashPurchase || tx.isPayment;
    final hasStockReplenishment = !tx.isPayment &&
        stockItemId != null &&
        stockItemId.trim().isNotEmpty &&
        stockQuantity > 0;

    await db.transaction((txn) async {
      await txn.insert(
        'supplier_transactions',
        tx.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (affectsCashBox) {
        final cleanName = supplierName.trim();
        final expenseTitle = tx.isPayment
            ? 'supplier_ledger_expense_payment_title'.trParams({
                'name': cleanName,
              })
            : 'supplier_ledger_expense_cash_purchase_title'.trParams({
                'name': cleanName,
              });

        final expense = Expense(
          id: const Uuid().v4(),
          title: expenseTitle,
          category: 'exp_cat_materials',
          expenseType: AppConstants.expenseTypeBusiness,
          supplierId: tx.supplierId,
          amount: tx.amount,
          currency: tx.currency,
          expenseDate: tx.txDate,
          notes: tx.notes,
          receiptPhotoPath: tx.receiptPhotoPath,
          createdAt: tx.createdAt,
        );

        await txn.insert(
          'expenses',
          expense.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (hasStockReplenishment) {
        final targetId = stockItemId.trim();
        if (stockItemType == 'product') {
          await txn.rawUpdate(
            'UPDATE products SET stockQuantity = stockQuantity + ? WHERE id = ?',
            [stockQuantity.round(), targetId],
          );
        } else if (stockItemType == 'material') {
          await txn.rawUpdate(
            'UPDATE raw_materials SET stockQuantity = stockQuantity + ? WHERE id = ?',
            [stockQuantity, targetId],
          );
        }
      }

      final afterSnapshot = Map<String, dynamic>.from(tx.toMap());
      if (hasStockReplenishment) {
        afterSnapshot['stockItemType'] = stockItemType;
        afterSnapshot['stockItemId'] = stockItemId;
        afterSnapshot['quantity'] = stockQuantity;
      }
      final impactYer = affectsCashBox
          ? -_currencyService.toBaseYer(tx.amount, tx.currency)
          : 0.0;
      await CentralAuditService.instance.logInTxn(
        txn,
        entityType: AuditEntityType.supplierTx,
        entityId: tx.id,
        entityLabel: supplierName.trim(),
        action: tx.isPayment ? AuditAction.payment : AuditAction.create,
        summary: '${supplierName.trim()} (${tx.type})',
        after: afterSnapshot,
        financialImpactYer: impactYer,
        currency: tx.currency,
        sourceModule: 'suppliers',
      );
    });

    DataSyncBus.instance.notify(DataDomain.suppliers);
    if (affectsCashBox) {
      DataSyncBus.instance.notify(DataDomain.expenses);
    }
    if (hasStockReplenishment) {
      if (stockItemType == 'product') {
        DataSyncBus.instance.notify(DataDomain.products);
      } else if (stockItemType == 'material') {
        DataSyncBus.instance.notify(DataDomain.materials);
      }
    }
    CentralAuditService.instance.notifyAuditChanged();
  }

  /// حذف حركة من دفتر حساب المورد
  Future<void> deleteTransaction(String txId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      'supplier_transactions',
      where: 'id = ?',
      whereArgs: [txId],
      limit: 1,
    );
    final beforeMap = rows.isNotEmpty
        ? Map<String, dynamic>.from(rows.first)
        : null;
    await db.delete(
      'supplier_transactions',
      where: 'id = ?',
      whereArgs: [txId],
    );
    if (beforeMap != null) {
      final curr = (beforeMap['currency'] as String?) ?? AppConstants.currencyYer;
      await CentralAuditService.instance.log(
        entityType: AuditEntityType.supplierTx,
        entityId: txId,
        entityLabel: (beforeMap['supplierId'] as String?) ?? txId,
        action: AuditAction.delete,
        summary: '${beforeMap['type'] ?? ''}',
        before: beforeMap,
        currency: curr,
        sourceModule: 'suppliers',
      );
    }
    DataSyncBus.instance.notify(DataDomain.suppliers);
  }
}
