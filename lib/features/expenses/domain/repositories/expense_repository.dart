import '../../../../models/expense.dart';

abstract class ExpenseRepository {
  Future<List<Expense>> getAllExpenses();
  Future<void> createExpense(Expense expense);
  Future<void> updateExpense(Expense expense);
  Future<void> deleteExpense(String id);
}
