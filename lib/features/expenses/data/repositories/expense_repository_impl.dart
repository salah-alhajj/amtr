import '../../../../core/audit/audit.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../domain/repositories/expense_repository.dart';

class ExpenseRepositoryImpl implements ExpenseRepository {
  final AppDatabase _dbHelper = AppDatabase.instance;

  @override
  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final maps = await db.query('expenses', orderBy: 'expenseDate DESC');
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  @override
  Future<void> createExpense(Expense expense) async {
    final db = await _dbHelper.database;
    final map = expense.toMap();
    await db.insert('expenses', map);
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.expense,
      entityId: expense.id,
      entityLabel: expense.title,
      action: AuditAction.create,
      summary: expense.title,
      after: map,
      financialImpactYer: -CurrencyService.instance.toBaseYer(
        expense.amount,
        expense.currency,
      ),
      currency: expense.currency,
      sourceModule: 'expenses',
    );
    DataSyncBus.instance.notify(DataDomain.expenses);
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    final beforeRows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [expense.id],
      limit: 1,
    );
    final beforeMap = beforeRows.isNotEmpty
        ? Map<String, dynamic>.from(beforeRows.first)
        : null;
    final prevAmtYer = beforeMap != null
        ? CurrencyService.instance.toBaseYer(
            (beforeMap['amount'] as num?)?.toDouble() ?? 0.0,
            (beforeMap['currency'] as String?) ?? expense.currency,
          )
        : 0.0;
    final afterMap = expense.toMap();
    await db.update(
      'expenses',
      afterMap,
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    final nextAmtYer = CurrencyService.instance.toBaseYer(
      expense.amount,
      expense.currency,
    );
    await CentralAuditService.instance.log(
      entityType: AuditEntityType.expense,
      entityId: expense.id,
      entityLabel: expense.title,
      action: AuditAction.update,
      summary: expense.title,
      before: beforeMap,
      after: afterMap,
      financialImpactYer: prevAmtYer - nextAmtYer,
      currency: expense.currency,
      sourceModule: 'expenses',
    );
    DataSyncBus.instance.notify(DataDomain.expenses);
  }

  @override
  Future<void> deleteExpense(String id) async {
    final db = await _dbHelper.database;
    final beforeRows = await db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    final beforeMap = beforeRows.isNotEmpty
        ? Map<String, dynamic>.from(beforeRows.first)
        : null;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (beforeMap != null) {
      final curr = (beforeMap['currency'] as String?) ?? 'YER';
      final amt = (beforeMap['amount'] as num?)?.toDouble() ?? 0.0;
      await CentralAuditService.instance.log(
        entityType: AuditEntityType.expense,
        entityId: id,
        entityLabel: (beforeMap['title'] as String?) ?? id,
        action: AuditAction.delete,
        summary: (beforeMap['title'] as String?) ?? id,
        before: beforeMap,
        financialImpactYer: CurrencyService.instance.toBaseYer(amt, curr),
        currency: curr,
        sourceModule: 'expenses',
      );
    }
    DataSyncBus.instance.notify(DataDomain.expenses);
  }
}
