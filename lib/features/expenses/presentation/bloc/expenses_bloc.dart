import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/expense.dart';
import '../../domain/repositories/expense_repository.dart';

// --- Events ---
abstract class ExpensesEvent {
  const ExpensesEvent();
}

class LoadExpenses extends ExpensesEvent {
  const LoadExpenses();
}

class SearchExpenses extends ExpensesEvent {
  final String query;
  const SearchExpenses(this.query);
}

class FilterExpensesByCategory extends ExpensesEvent {
  final String category;
  const FilterExpensesByCategory(this.category);
}

class FilterExpensesByFrequency extends ExpensesEvent {
  final String frequency; // 'all', 'petty_cash', 'daily', 'weekly', 'monthly', 'once'
  const FilterExpensesByFrequency(this.frequency);
}

class CreateExpenseEvent extends ExpensesEvent {
  final Expense expense;
  const CreateExpenseEvent(this.expense);
}

class UpdateExpenseEvent extends ExpensesEvent {
  final Expense expense;
  const UpdateExpenseEvent(this.expense);
}

class DeleteExpenseEvent extends ExpensesEvent {
  final String id;
  const DeleteExpenseEvent(this.id);
}

// --- States ---
abstract class ExpensesState {
  const ExpensesState();
}

class ExpensesInitial extends ExpensesState {
  const ExpensesInitial();
}

class ExpensesLoading extends ExpensesState {
  const ExpensesLoading();
}

class ExpensesLoaded extends ExpensesState {
  final List<Expense> allExpenses;
  final List<Expense> displayedExpenses;
  final double totalInYer;
  final double pettyCashTotalInYer;
  final double dailyTotalInYer;
  final double weeklyTotalInYer;
  final double monthlyTotalInYer;
  final double estimatedMonthlyRecurringInYer;
  final String searchQuery;
  final String selectedCategory;
  final String selectedFrequency;

  const ExpensesLoaded({
    required this.allExpenses,
    required this.displayedExpenses,
    required this.totalInYer,
    this.pettyCashTotalInYer = 0.0,
    this.dailyTotalInYer = 0.0,
    this.weeklyTotalInYer = 0.0,
    this.monthlyTotalInYer = 0.0,
    this.estimatedMonthlyRecurringInYer = 0.0,
    this.searchQuery = '',
    this.selectedCategory = 'all',
    this.selectedFrequency = 'all',
  });
}

class ExpensesError extends ExpensesState {
  final String message;
  const ExpensesError(this.message);
}

// --- BLoC ---
class ExpensesBloc extends Bloc<ExpensesEvent, ExpensesState> {
  final ExpenseRepository repository;
  final CurrencyService currencyService;
  late final StreamSubscription<DataDomain> _syncSub;
  bool _isSelfMutating = false;

  ExpensesBloc({
    required this.repository,
    CurrencyService? currency,
  })  : currencyService = currency ?? CurrencyService.instance,
        super(const ExpensesInitial()) {
    on<LoadExpenses>(_onLoad);
    on<SearchExpenses>(_onSearch);
    on<FilterExpensesByCategory>(_onFilter);
    on<FilterExpensesByFrequency>(_onFilterFrequency);
    on<CreateExpenseEvent>(_onCreate);
    on<UpdateExpenseEvent>(_onUpdate);
    on<DeleteExpenseEvent>(_onDelete);
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!isClosed &&
          !_isSelfMutating &&
          state is ExpensesLoaded &&
          (domain == DataDomain.expenses || domain == DataDomain.suppliers)) {
        add(const LoadExpenses());
      }
    });
  }

  Future<void> _runSelfMutation(Future<void> Function() mutation) async {
    _isSelfMutating = true;
    try {
      await mutation();
      await Future<void>.microtask(() {});
    } finally {
      _isSelfMutating = false;
    }
  }

  @override
  Future<void> close() async {
    await _syncSub.cancel();
    return super.close();
  }

  Future<void> _onLoad(LoadExpenses event, Emitter<ExpensesState> emit) async {
    final prevQuery =
        state is ExpensesLoaded ? (state as ExpensesLoaded).searchQuery : '';
    final prevCat = state is ExpensesLoaded
        ? (state as ExpensesLoaded).selectedCategory
        : 'all';
    final prevFreq = state is ExpensesLoaded
        ? (state as ExpensesLoaded).selectedFrequency
        : 'all';

    if (state is! ExpensesLoaded) {
      emit(const ExpensesLoading());
    }
    try {
      final list = await repository.getAllExpenses();
      final filtered = _applyFilters(list, prevQuery, prevCat, prevFreq);
      emit(_buildLoadedState(
        all: list,
        displayed: filtered,
        query: prevQuery,
        category: prevCat,
        frequency: prevFreq,
      ));
    } catch (e) {
      emit(ExpensesError(e.toString()));
    }
  }

  void _onSearch(SearchExpenses event, Emitter<ExpensesState> emit) {
    if (state is! ExpensesLoaded) return;
    final current = state as ExpensesLoaded;
    final filtered = _applyFilters(
      current.allExpenses,
      event.query,
      current.selectedCategory,
      current.selectedFrequency,
    );
    emit(_buildLoadedState(
      all: current.allExpenses,
      displayed: filtered,
      query: event.query,
      category: current.selectedCategory,
      frequency: current.selectedFrequency,
    ));
  }

  void _onFilter(FilterExpensesByCategory event, Emitter<ExpensesState> emit) {
    if (state is! ExpensesLoaded) return;
    final current = state as ExpensesLoaded;
    final filtered = _applyFilters(
      current.allExpenses,
      current.searchQuery,
      event.category,
      current.selectedFrequency,
    );
    emit(_buildLoadedState(
      all: current.allExpenses,
      displayed: filtered,
      query: current.searchQuery,
      category: event.category,
      frequency: current.selectedFrequency,
    ));
  }

  void _onFilterFrequency(
    FilterExpensesByFrequency event,
    Emitter<ExpensesState> emit,
  ) {
    if (state is! ExpensesLoaded) return;
    final current = state as ExpensesLoaded;
    final filtered = _applyFilters(
      current.allExpenses,
      current.searchQuery,
      current.selectedCategory,
      event.frequency,
    );
    emit(_buildLoadedState(
      all: current.allExpenses,
      displayed: filtered,
      query: current.searchQuery,
      category: current.selectedCategory,
      frequency: event.frequency,
    ));
  }

  ExpensesLoaded _buildLoadedState({
    required List<Expense> all,
    required List<Expense> displayed,
    required String query,
    required String category,
    required String frequency,
  }) {
    double pettyTotal = 0.0;
    double dailyTotal = 0.0;
    double weeklyTotal = 0.0;
    double monthlyTotal = 0.0;
    double estMonthlyRecurring = 0.0;

    for (final e in all) {
      final valYer = currencyService.toBaseYer(e.amount, e.currency);
      if (e.isPettyCash) pettyTotal += valYer;
      final isRecurringRule = e.parentRuleId == null;
      switch (e.recurrence) {
        case AppConstants.expenseRecurrenceDaily:
          dailyTotal += valYer;
          if (isRecurringRule) estMonthlyRecurring += valYer * 30.0;
          break;
        case AppConstants.expenseRecurrenceWeekly:
          weeklyTotal += valYer;
          if (isRecurringRule) estMonthlyRecurring += valYer * 4.0;
          break;
        case AppConstants.expenseRecurrenceMonthly:
          monthlyTotal += valYer;
          if (isRecurringRule) estMonthlyRecurring += valYer;
          break;
      }
    }

    return ExpensesLoaded(
      allExpenses: all,
      displayedExpenses: displayed,
      totalInYer: _sumInYer(displayed),
      pettyCashTotalInYer: pettyTotal,
      dailyTotalInYer: dailyTotal,
      weeklyTotalInYer: weeklyTotal,
      monthlyTotalInYer: monthlyTotal,
      estimatedMonthlyRecurringInYer: estMonthlyRecurring,
      searchQuery: query,
      selectedCategory: category,
      selectedFrequency: frequency,
    );
  }

  List<Expense> _applyFilters(
    List<Expense> list,
    String query,
    String category,
    String frequency,
  ) {
    final q = query.trim().toLowerCase();
    return list.where((e) {
      if (category != 'all' && e.category != category) return false;
      if (frequency == 'petty_cash' && !e.isPettyCash) return false;
      if (frequency != 'all' &&
          frequency != 'petty_cash' &&
          e.recurrence != frequency) {
        return false;
      }
      if (q.isNotEmpty) {
        return e.title.toLowerCase().contains(q) ||
            (e.notes ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  double _sumInYer(List<Expense> list) {
    double sum = 0.0;
    for (final e in list) {
      sum += currencyService.toBaseYer(e.amount, e.currency);
    }
    return sum;
  }

  Future<void> _onCreate(
    CreateExpenseEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    await _runSelfMutation(() => repository.createExpense(event.expense));
    add(const LoadExpenses());
  }

  Future<void> _onUpdate(
    UpdateExpenseEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    await _runSelfMutation(() => repository.updateExpense(event.expense));
    add(const LoadExpenses());
  }

  Future<void> _onDelete(
    DeleteExpenseEvent event,
    Emitter<ExpensesState> emit,
  ) async {
    await _runSelfMutation(() => repository.deleteExpense(event.id));
    add(const LoadExpenses());
  }
}
