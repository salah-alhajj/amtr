import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/product.dart';
import '../../domain/repositories/product_repository.dart';

// --- Events ---
abstract class ProductsEvent {
  const ProductsEvent();
}

class LoadProducts extends ProductsEvent {
  const LoadProducts();
}

class SearchProducts extends ProductsEvent {
  final String query;
  const SearchProducts(this.query);
}

class FilterProducts extends ProductsEvent {
  final String categoryFilter; // 'all', 'low_stock', or category key
  const FilterProducts(this.categoryFilter);
}

class CreateProductEvent extends ProductsEvent {
  final Product product;
  const CreateProductEvent(this.product);
}

class UpdateProductEvent extends ProductsEvent {
  final Product product;
  const UpdateProductEvent(this.product);
}

class DeleteProductEvent extends ProductsEvent {
  final String id;
  const DeleteProductEvent(this.id);
}

class AdjustProductStockEvent extends ProductsEvent {
  final String id;
  final int delta;
  const AdjustProductStockEvent(this.id, this.delta);
}

// --- States ---
abstract class ProductsState {
  const ProductsState();
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<Product> allProducts;
  final List<Product> displayedProducts;
  final String searchQuery;
  final String selectedFilter;

  const ProductsLoaded({
    required this.allProducts,
    required this.displayedProducts,
    this.searchQuery = '',
    this.selectedFilter = 'all',
  });
}

class ProductsError extends ProductsState {
  final String message;
  const ProductsError(this.message);
}

// --- BLoC ---
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductRepository repository;
  late final StreamSubscription<DataDomain> _syncSub;
  bool _isSelfMutating = false;

  ProductsBloc({required this.repository}) : super(const ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<SearchProducts>(_onSearchProducts);
    on<FilterProducts>(_onFilterProducts);
    on<CreateProductEvent>(_onCreateProduct);
    on<UpdateProductEvent>(_onUpdateProduct);
    on<DeleteProductEvent>(_onDeleteProduct);
    on<AdjustProductStockEvent>(_onAdjustStock);
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!isClosed &&
          !_isSelfMutating &&
          state is ProductsLoaded &&
          (domain == DataDomain.products || domain == DataDomain.materials)) {
        add(const LoadProducts());
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

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    final prevQuery =
        state is ProductsLoaded ? (state as ProductsLoaded).searchQuery : '';
    final prevFilter = state is ProductsLoaded
        ? (state as ProductsLoaded).selectedFilter
        : 'all';
    if (state is! ProductsLoaded) {
      emit(const ProductsLoading());
    }
    try {
      final list = await repository.getAllProducts();
      final filtered = _applyFilters(list, prevQuery, prevFilter);
      emit(ProductsLoaded(
        allProducts: list,
        displayedProducts: filtered,
        searchQuery: prevQuery,
        selectedFilter: prevFilter,
      ));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }

  void _onSearchProducts(SearchProducts event, Emitter<ProductsState> emit) {
    if (state is! ProductsLoaded) return;
    final current = state as ProductsLoaded;
    final filtered = _applyFilters(
      current.allProducts,
      event.query,
      current.selectedFilter,
    );
    emit(ProductsLoaded(
      allProducts: current.allProducts,
      displayedProducts: filtered,
      searchQuery: event.query,
      selectedFilter: current.selectedFilter,
    ));
  }

  void _onFilterProducts(FilterProducts event, Emitter<ProductsState> emit) {
    if (state is! ProductsLoaded) return;
    final current = state as ProductsLoaded;
    final filtered = _applyFilters(
      current.allProducts,
      current.searchQuery,
      event.categoryFilter,
    );
    emit(ProductsLoaded(
      allProducts: current.allProducts,
      displayedProducts: filtered,
      searchQuery: current.searchQuery,
      selectedFilter: event.categoryFilter,
    ));
  }

  List<Product> _applyFilters(
    List<Product> products,
    String query,
    String filter,
  ) {
    final q = query.trim().toLowerCase();
    return products.where((p) {
      if (filter == 'low_stock' && !p.isLowStock) {
        return false;
      } else if (filter == 'type_resale' && !p.isResale) {
        return false;
      } else if (filter == 'type_manufactured' && !p.isManufactured) {
        return false;
      } else if (filter != 'all' &&
          filter != 'low_stock' &&
          filter != 'type_resale' &&
          filter != 'type_manufactured' &&
          p.category != filter) {
        return false;
      }
      if (q.isNotEmpty) {
        final matchName = p.name.toLowerCase().contains(q);
        final matchNotes = (p.notes ?? '').toLowerCase().contains(q);
        final matchUnit = p.unit.toLowerCase().contains(q);
        return matchName || matchNotes || matchUnit;
      }
      return true;
    }).toList();
  }

  Future<void> _onCreateProduct(
    CreateProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    await _runSelfMutation(() => repository.createProduct(event.product));
    add(const LoadProducts());
  }

  Future<void> _onUpdateProduct(
    UpdateProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    await _runSelfMutation(() => repository.updateProduct(event.product));
    add(const LoadProducts());
  }

  Future<void> _onDeleteProduct(
    DeleteProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    await _runSelfMutation(() => repository.deleteProduct(event.id));
    add(const LoadProducts());
  }

  Future<void> _onAdjustStock(
    AdjustProductStockEvent event,
    Emitter<ProductsState> emit,
  ) async {
    await _runSelfMutation(() => repository.adjustStock(event.id, event.delta));
    add(const LoadProducts());
  }
}
