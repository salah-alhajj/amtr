import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/supplier.dart';
import '../../data/repositories/supplier_ledger_repository.dart';
import '../../domain/repositories/supplier_repository.dart';

// --- Events ---
abstract class SuppliersEvent {
  const SuppliersEvent();
}

class LoadSuppliers extends SuppliersEvent {
  const LoadSuppliers();
}

class SearchSuppliers extends SuppliersEvent {
  final String query;
  const SearchSuppliers(this.query);
}

class FilterSuppliersByCategory extends SuppliersEvent {
  final String category;
  const FilterSuppliersByCategory(this.category);
}

class CreateSupplierEvent extends SuppliersEvent {
  final Supplier supplier;
  const CreateSupplierEvent(this.supplier);
}

class UpdateSupplierEvent extends SuppliersEvent {
  final Supplier supplier;
  const UpdateSupplierEvent(this.supplier);
}

class DeleteSupplierEvent extends SuppliersEvent {
  final String id;
  const DeleteSupplierEvent(this.id);
}

// --- States ---
abstract class SuppliersState {
  const SuppliersState();
}

class SuppliersInitial extends SuppliersState {
  const SuppliersInitial();
}

class SuppliersLoading extends SuppliersState {
  const SuppliersLoading();
}

class SuppliersLoaded extends SuppliersState {
  final List<Supplier> allSuppliers;
  final List<Supplier> displayedSuppliers;
  final Map<String, int> linkedProductCounts;
  final Map<String, double> supplierBalancesYer;
  final double totalPayablesYer;
  final String searchQuery;
  final String selectedCategory;

  const SuppliersLoaded({
    required this.allSuppliers,
    required this.displayedSuppliers,
    this.linkedProductCounts = const {},
    this.supplierBalancesYer = const {},
    this.totalPayablesYer = 0.0,
    this.searchQuery = '',
    this.selectedCategory = 'all',
  });
}

class SuppliersError extends SuppliersState {
  final String message;
  const SuppliersError(this.message);
}

// --- BLoC ---
class SuppliersBloc extends Bloc<SuppliersEvent, SuppliersState> {
  final SupplierRepository repository;
  final SupplierLedgerRepository _ledgerRepository;
  late final StreamSubscription<DataDomain> _syncSub;
  bool _isSelfMutating = false;

  SuppliersBloc({
    required this.repository,
    SupplierLedgerRepository? ledgerRepository,
  })  : _ledgerRepository = ledgerRepository ?? SupplierLedgerRepository(),
        super(const SuppliersInitial()) {
    on<LoadSuppliers>(_onLoad);
    on<SearchSuppliers>(_onSearch);
    on<FilterSuppliersByCategory>(_onFilter);
    on<CreateSupplierEvent>(_onCreate);
    on<UpdateSupplierEvent>(_onUpdate);
    on<DeleteSupplierEvent>(_onDelete);
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!isClosed &&
          !_isSelfMutating &&
          state is SuppliersLoaded &&
          (domain == DataDomain.suppliers ||
              domain == DataDomain.products ||
              domain == DataDomain.materials ||
              domain == DataDomain.expenses)) {
        add(const LoadSuppliers());
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

  Future<void> _onLoad(
    LoadSuppliers event,
    Emitter<SuppliersState> emit,
  ) async {
    final prevQuery =
        state is SuppliersLoaded ? (state as SuppliersLoaded).searchQuery : '';
    final prevCat = state is SuppliersLoaded
        ? (state as SuppliersLoaded).selectedCategory
        : 'all';

    if (state is! SuppliersLoaded) {
      emit(const SuppliersLoading());
    }
    try {
      final list = await repository.getAllSuppliers();
      final counts = await repository.getLinkedProductCounts();
      Map<String, double> balances = const {};
      try {
        balances = await _ledgerRepository.getAllBalancesYer();
      } catch (_) {
        balances = const {};
      }
      final totalPayables = balances.values
          .where((v) => v > 0)
          .fold<double>(0.0, (sum, v) => sum + v);
      final filtered = _applyFilters(list, prevQuery, prevCat);
      emit(SuppliersLoaded(
        allSuppliers: list,
        displayedSuppliers: filtered,
        linkedProductCounts: counts,
        supplierBalancesYer: balances,
        totalPayablesYer: totalPayables,
        searchQuery: prevQuery,
        selectedCategory: prevCat,
      ));
    } catch (e) {
      emit(SuppliersError(e.toString()));
    }
  }

  void _onSearch(SearchSuppliers event, Emitter<SuppliersState> emit) {
    if (state is! SuppliersLoaded) return;
    final current = state as SuppliersLoaded;
    final filtered = _applyFilters(
      current.allSuppliers,
      event.query,
      current.selectedCategory,
    );
    emit(SuppliersLoaded(
      allSuppliers: current.allSuppliers,
      displayedSuppliers: filtered,
      linkedProductCounts: current.linkedProductCounts,
      supplierBalancesYer: current.supplierBalancesYer,
      totalPayablesYer: current.totalPayablesYer,
      searchQuery: event.query,
      selectedCategory: current.selectedCategory,
    ));
  }

  void _onFilter(
    FilterSuppliersByCategory event,
    Emitter<SuppliersState> emit,
  ) {
    if (state is! SuppliersLoaded) return;
    final current = state as SuppliersLoaded;
    final filtered = _applyFilters(
      current.allSuppliers,
      current.searchQuery,
      event.category,
    );
    emit(SuppliersLoaded(
      allSuppliers: current.allSuppliers,
      displayedSuppliers: filtered,
      linkedProductCounts: current.linkedProductCounts,
      supplierBalancesYer: current.supplierBalancesYer,
      totalPayablesYer: current.totalPayablesYer,
      searchQuery: current.searchQuery,
      selectedCategory: event.category,
    ));
  }

  List<Supplier> _applyFilters(
    List<Supplier> list,
    String query,
    String category,
  ) {
    final q = query.trim().toLowerCase();
    return list.where((s) {
      if (category != 'all' && s.category != category) return false;
      if (q.isNotEmpty) {
        return s.name.toLowerCase().contains(q) ||
            (s.phone ?? '').toLowerCase().contains(q) ||
            (s.whatsapp ?? '').toLowerCase().contains(q) ||
            (s.address ?? '').toLowerCase().contains(q) ||
            (s.notes ?? '').toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  Future<void> _onCreate(
    CreateSupplierEvent event,
    Emitter<SuppliersState> emit,
  ) async {
    await _runSelfMutation(() => repository.createSupplier(event.supplier));
    add(const LoadSuppliers());
  }

  Future<void> _onUpdate(
    UpdateSupplierEvent event,
    Emitter<SuppliersState> emit,
  ) async {
    await _runSelfMutation(() => repository.updateSupplier(event.supplier));
    add(const LoadSuppliers());
  }

  Future<void> _onDelete(
    DeleteSupplierEvent event,
    Emitter<SuppliersState> emit,
  ) async {
    await _runSelfMutation(() => repository.deleteSupplier(event.id));
    add(const LoadSuppliers());
  }
}
