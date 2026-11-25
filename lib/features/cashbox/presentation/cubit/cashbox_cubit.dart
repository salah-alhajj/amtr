import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../../expenses/data/repositories/expense_repository_impl.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../data/repositories/cashbox_repository_impl.dart';
import '../../domain/repositories/cashbox_repository.dart';

// --- States ---
abstract class CashBoxState {
  const CashBoxState();
}

class CashBoxInitial extends CashBoxState {
  const CashBoxInitial();
}

class CashBoxLoading extends CashBoxState {
  const CashBoxLoading();
}

class CashBoxLoaded extends CashBoxState {
  final DailyCashBoxSummary summary;
  final DateTime selectedDate;

  const CashBoxLoaded({
    required this.summary,
    required this.selectedDate,
  });
}

class CashBoxError extends CashBoxState {
  final String message;
  const CashBoxError(this.message);
}

// --- Cubit ---
class CashBoxCubit extends Cubit<CashBoxState> {
  final CashBoxRepository cashBoxRepo;
  final ExpenseRepository expenseRepo;
  late final StreamSubscription<DataDomain> _syncSub;
  DateTime _selectedDate;

  CashBoxCubit({
    CashBoxRepository? cashBoxRepo,
    ExpenseRepository? expenseRepo,
    DateTime? initialDate,
  })  : cashBoxRepo = cashBoxRepo ?? CashBoxRepositoryImpl(),
        expenseRepo = expenseRepo ?? ExpenseRepositoryImpl(),
        _selectedDate = _normalizeDate(initialDate ?? DateTime.now()),
        super(const CashBoxInitial()) {
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (domain == DataDomain.orders ||
          domain == DataDomain.payments ||
          domain == DataDomain.expenses) {
        loadDate(_selectedDate, silent: true);
      }
    });
  }

  DateTime get selectedDate => _selectedDate;

  static DateTime _normalizeDate(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  Future<void> loadDate(DateTime date, {bool silent = false}) async {
    final normalized = _normalizeDate(date);
    final alreadyLoadedSameDate = state is CashBoxLoaded &&
        (state as CashBoxLoaded).selectedDate == normalized;
    _selectedDate = normalized;
    if (!silent && !alreadyLoadedSameDate) {
      emit(const CashBoxLoading());
    }
    try {
      final summary = await cashBoxRepo.getDailySummary(_selectedDate);
      if (isClosed) return;
      emit(CashBoxLoaded(summary: summary, selectedDate: _selectedDate));
    } catch (e) {
      if (isClosed) return;
      emit(CashBoxError(e.toString()));
    }
  }

  Future<void> previousDay() {
    return loadDate(_selectedDate.subtract(const Duration(days: 1)));
  }

  Future<void> nextDay() {
    return loadDate(_selectedDate.add(const Duration(days: 1)));
  }

  Future<void> recordExpense(Expense expense) async {
    await expenseRepo.createExpense(expense);
    await loadDate(_selectedDate, silent: true);
  }

  @override
  Future<void> close() async {
    await _syncSub.cancel();
    return super.close();
  }
}
