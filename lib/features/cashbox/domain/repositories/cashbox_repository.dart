import '../../../../models/expense.dart';

/// نوع حركة الصندوق اليومي
enum CashBoxMovementType {
  cashIn,
  businessExpense,
  personalDrawing,
}

/// حركة مالية مفردة في الصندوق اليومي (مقبوضات أو مصاريف شغل أو سحب شخصي للبيت)
class CashBoxMovement {
  final String id;
  final CashBoxMovementType type;
  final String title;
  final String? subtitle;
  final double amount;
  final String currency;
  final double amountInYer;
  final DateTime timestamp;
  final String? paymentMethod;
  final String? referenceId;

  const CashBoxMovement({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.currency,
    required this.amountInYer,
    required this.timestamp,
    this.paymentMethod,
    this.referenceId,
  });
}

/// ملخص الصندوق اليومي لتاريخ محدد
class DailyCashBoxSummary {
  final DateTime date;
  final double cashInYer;
  final double businessExpensesYer;
  final double pettyCashExpensesYer;
  final double personalDrawingsYer;
  final double netDrawerYer;
  final List<CashBoxMovement> movements;
  final List<Expense> dueRecurringExpenses;
  final double totalSupplierPayablesYer;

  const DailyCashBoxSummary({
    required this.date,
    required this.cashInYer,
    required this.businessExpensesYer,
    this.pettyCashExpensesYer = 0.0,
    required this.personalDrawingsYer,
    required this.netDrawerYer,
    required this.movements,
    this.dueRecurringExpenses = const [],
    this.totalSupplierPayablesYer = 0.0,
  });

  factory DailyCashBoxSummary.empty(DateTime date) {
    return DailyCashBoxSummary(
      date: DateTime(date.year, date.month, date.day),
      cashInYer: 0,
      businessExpensesYer: 0,
      pettyCashExpensesYer: 0,
      personalDrawingsYer: 0,
      netDrawerYer: 0,
      movements: const [],
      dueRecurringExpenses: const [],
      totalSupplierPayablesYer: 0,
    );
  }
}

/// واجهة مستودع الصندوق اليومي
abstract class CashBoxRepository {
  Future<DailyCashBoxSummary> getDailySummary(DateTime date);
}
