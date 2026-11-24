import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../models/expense.dart';
import '../../../../models/payment_transaction.dart';
import '../../../suppliers/data/repositories/supplier_ledger_repository.dart';
import '../../domain/repositories/cashbox_repository.dart';

class CashBoxRepositoryImpl implements CashBoxRepository {
  final AppDatabase _dbHelper;
  final CurrencyService _currencyService;
  final SupplierLedgerRepository _supplierLedgerRepo;

  CashBoxRepositoryImpl({
    AppDatabase? dbHelper,
    CurrencyService? currencyService,
    SupplierLedgerRepository? supplierLedgerRepo,
  })  : _dbHelper = dbHelper ?? AppDatabase.instance,
        _currencyService = currencyService ?? CurrencyService.instance,
        _supplierLedgerRepo = supplierLedgerRepo ??
            SupplierLedgerRepository(
              dbHelper: dbHelper ?? AppDatabase.instance,
              currencyService: currencyService ?? CurrencyService.instance,
            );

  @override
  Future<DailyCashBoxSummary> getDailySummary(DateTime date) async {
    final db = await _dbHelper.database;
    final dayPrefix = _formatDatePrefix(date);

    final paymentMaps = await db.query(
      'payment_transactions',
      where: 'paidAt LIKE ?',
      whereArgs: ['$dayPrefix%'],
    );

    final expenseMaps = await db.query(
      'expenses',
      where: 'expenseDate LIKE ?',
      whereArgs: ['$dayPrefix%'],
    );

    double cashInYer = 0.0;
    double businessExpensesYer = 0.0;
    double pettyCashExpensesYer = 0.0;
    double personalDrawingsYer = 0.0;
    final List<CashBoxMovement> movements = [];

    for (final map in paymentMaps) {
      final tx = PaymentTransaction.fromMap(map);
      final amountYer = _currencyService.toBaseYer(tx.amount, tx.currency);
      cashInYer += amountYer;

      movements.add(
        CashBoxMovement(
          id: tx.id,
          type: CashBoxMovementType.cashIn,
          title: (tx.notes != null && tx.notes!.trim().isNotEmpty)
              ? tx.notes!.trim()
              : '',
          subtitle: tx.paymentMethod,
          amount: tx.amount,
          currency: tx.currency,
          amountInYer: amountYer,
          timestamp: tx.paidAt,
          paymentMethod: tx.paymentMethod,
          referenceId: tx.orderId,
        ),
      );
    }

    for (final map in expenseMaps) {
      final exp = Expense.fromMap(map);
      final amountYer = _currencyService.toBaseYer(exp.amount, exp.currency);
      final isPersonal = exp.isPersonalDrawing;

      if (isPersonal) {
        personalDrawingsYer += amountYer;
      } else {
        businessExpensesYer += amountYer;
        if (exp.isPettyCash) {
          pettyCashExpensesYer += amountYer;
        }
      }

      movements.add(
        CashBoxMovement(
          id: exp.id,
          type: isPersonal
              ? CashBoxMovementType.personalDrawing
              : CashBoxMovementType.businessExpense,
          title: exp.title,
          subtitle: exp.category,
          amount: exp.amount,
          currency: exp.currency,
          amountInYer: amountYer,
          timestamp: exp.expenseDate,
          referenceId: exp.id,
        ),
      );
    }

    movements.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final dueRecurringExpenses = await _loadDueRecurringExpenses(db, date);

    double totalSupplierPayablesYer = 0.0;
    try {
      totalSupplierPayablesYer =
          await _supplierLedgerRepo.getTotalPayablesYer();
    } catch (_) {
      totalSupplierPayablesYer = 0.0;
    }

    final netDrawerYer =
        cashInYer - businessExpensesYer - personalDrawingsYer;

    return DailyCashBoxSummary(
      date: DateTime(date.year, date.month, date.day),
      cashInYer: cashInYer,
      businessExpensesYer: businessExpensesYer,
      pettyCashExpensesYer: pettyCashExpensesYer,
      personalDrawingsYer: personalDrawingsYer,
      netDrawerYer: netDrawerYer,
      movements: movements,
      dueRecurringExpenses: dueRecurringExpenses,
      totalSupplierPayablesYer: totalSupplierPayablesYer,
    );
  }

  Future<List<Expense>> _loadDueRecurringExpenses(
    dynamic db,
    DateTime selectedDate,
  ) async {
    final ruleMaps = await db.query(
      'expenses',
      where:
          "recurrence != ? AND (parentRuleId IS NULL OR parentRuleId = '')",
      whereArgs: [AppConstants.expenseRecurrenceOnce],
      orderBy: 'expenseDate DESC',
    ) as List<Map<String, dynamic>>;

    if (ruleMaps.isEmpty) return const [];

    final rules = ruleMaps.map(Expense.fromMap).toList();
    final ruleIds = rules.map((r) => r.id).toList();
    final placeholders = List.filled(ruleIds.length, '?').join(',');

    final childMaps = await db.rawQuery(
      'SELECT parentRuleId, expenseDate FROM expenses WHERE parentRuleId IN ($placeholders)',
      ruleIds,
    ) as List<Map<String, dynamic>>;

    final Map<String, List<DateTime>> loggedDatesByRule = {};
    for (final row in childMaps) {
      final parentId = row['parentRuleId'] as String?;
      final dateStr = row['expenseDate'] as String?;
      if (parentId == null || dateStr == null) continue;
      final parsed = DateTime.tryParse(dateStr);
      if (parsed == null) continue;
      loggedDatesByRule
          .putIfAbsent(parentId, () => [])
          .add(DateTime(parsed.year, parsed.month, parsed.day));
    }

    final selectedDay =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final due = <Expense>[];

    for (final rule in rules) {
      final ruleDay = DateTime(
        rule.expenseDate.year,
        rule.expenseDate.month,
        rule.expenseDate.day,
      );
      if (ruleDay.isAfter(selectedDay)) continue;

      final childDates = loggedDatesByRule[rule.id] ?? const [];
      bool alreadyLogged = false;

      switch (rule.recurrence) {
        case AppConstants.expenseRecurrenceDaily:
          if (_isSameDay(ruleDay, selectedDay)) {
            alreadyLogged = true;
          } else {
            alreadyLogged = childDates.any((d) => _isSameDay(d, selectedDay));
          }
          break;
        case AppConstants.expenseRecurrenceWeekly:
          final ruleDiffDays = selectedDay.difference(ruleDay).inDays;
          if (ruleDiffDays < 7) {
            alreadyLogged = true;
          } else {
            alreadyLogged = childDates.any((d) {
              if (d.isAfter(selectedDay)) return false;
              return selectedDay.difference(d).inDays < 7;
            });
          }
          break;
        case AppConstants.expenseRecurrenceMonthly:
          if (ruleDay.year == selectedDay.year &&
              ruleDay.month == selectedDay.month) {
            alreadyLogged = true;
          } else {
            alreadyLogged = childDates.any(
              (d) =>
                  d.year == selectedDay.year && d.month == selectedDay.month,
            );
          }
          break;
        default:
          alreadyLogged = true;
      }

      if (!alreadyLogged) {
        due.add(rule);
      }
    }

    return due;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _formatDatePrefix(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
