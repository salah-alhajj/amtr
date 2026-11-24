import '../../../../core/database/app_database.dart';
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
    await db.insert('expenses', expense.toMap());
    DataSyncBus.instance.notify(DataDomain.expenses);
  }

  @override
  Future<void> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
    DataSyncBus.instance.notify(DataDomain.expenses);
  }

  @override
  Future<void> deleteExpense(String id) async {
    final db = await _dbHelper.database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
    DataSyncBus.instance.notify(DataDomain.expenses);
  }
}
