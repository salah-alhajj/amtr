import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../domain/customer_financial_helper.dart';
import '../../domain/repositories/customer_repository.dart';

// --- Events ---
abstract class CustomersEvent {
  const CustomersEvent();
}

class LoadCustomers extends CustomersEvent {
  const LoadCustomers();
}

class SearchCustomers extends CustomersEvent {
  final String query;
  const SearchCustomers(this.query);
}

class FilterCustomersEvent extends CustomersEvent {
  final CustomerListFilter filter;
  const FilterCustomersEvent(this.filter);
}

class CreateCustomerEvent extends CustomersEvent {
  final Customer customer;
  const CreateCustomerEvent(this.customer);
}

class UpdateCustomerEvent extends CustomersEvent {
  final Customer customer;
  const UpdateCustomerEvent(this.customer);
}

class DeleteCustomerEvent extends CustomersEvent {
  final String customerId;
  const DeleteCustomerEvent(this.customerId);
}

// --- States ---
abstract class CustomersState {
  const CustomersState();
}

class CustomersInitial extends CustomersState {
  const CustomersInitial();
}

class CustomersLoading extends CustomersState {
  const CustomersLoading();
}

class CustomersLoaded extends CustomersState {
  final List<Customer> allCustomers;
  final List<Customer> customers;
  final String searchQuery;
  final CustomerListFilter activeFilter;
  final Map<String, CustomerFinancialSummary> summaries;
  final Map<CustomerListFilter, int> filterCounts;

  const CustomersLoaded({
    List<Customer>? allCustomers,
    required this.customers,
    this.searchQuery = '',
    this.activeFilter = CustomerListFilter.all,
    this.summaries = const {},
    this.filterCounts = const {},
  }) : allCustomers = allCustomers ?? customers;

  CustomersLoaded copyWith({
    List<Customer>? allCustomers,
    List<Customer>? customers,
    String? searchQuery,
    CustomerListFilter? activeFilter,
    Map<String, CustomerFinancialSummary>? summaries,
    Map<CustomerListFilter, int>? filterCounts,
  }) {
    return CustomersLoaded(
      allCustomers: allCustomers ?? this.allCustomers,
      customers: customers ?? this.customers,
      searchQuery: searchQuery ?? this.searchQuery,
      activeFilter: activeFilter ?? this.activeFilter,
      summaries: summaries ?? this.summaries,
      filterCounts: filterCounts ?? this.filterCounts,
    );
  }
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
}

// --- BLoC ---
class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  final CustomerRepository repository;
  final OrderRepository? orderRepository;

  CustomersBloc({
    required this.repository,
    this.orderRepository,
  }) : super(const CustomersInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<SearchCustomers>(_onSearchCustomers);
    on<FilterCustomersEvent>(_onFilterCustomers);
    on<CreateCustomerEvent>(_onCreateCustomer);
    on<UpdateCustomerEvent>(_onUpdateCustomer);
    on<DeleteCustomerEvent>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomersState> emit) async {
    final currentSearch = state is CustomersLoaded ? (state as CustomersLoaded).searchQuery : '';
    final currentFilter = state is CustomersLoaded ? (state as CustomersLoaded).activeFilter : CustomerListFilter.all;

    emit(const CustomersLoading());
    try {
      final allCustomers = await repository.getAllCustomers();
      final Map<String, CustomerFinancialSummary> summaries = {};

      if (orderRepository != null) {
        final allOrders = await orderRepository!.getAllOrders();
        final Map<String, List<IndividualOrder>> ordersByCustomer = {};
        for (final order in allOrders) {
          if (order.customerId != null) {
            ordersByCustomer.putIfAbsent(order.customerId!, () => []).add(order);
          }
        }
        for (final c in allCustomers) {
          summaries[c.id] = CustomerFinancialHelper.calculate(
            customer: c,
            orders: ordersByCustomer[c.id] ?? [],
            currencyService: CurrencyService.instance,
          );
        }
      }

      final counts = _calculateCounts(allCustomers: allCustomers, summaries: summaries);
      final filtered = _applyFilterAndSearch(
        list: allCustomers,
        summaries: summaries,
        query: currentSearch,
        filter: currentFilter,
      );

      emit(CustomersLoaded(
        allCustomers: allCustomers,
        customers: filtered,
        searchQuery: currentSearch,
        activeFilter: currentFilter,
        summaries: summaries,
        filterCounts: counts,
      ));
    } catch (e) {
      emit(CustomersError('فشل تحميل العملاء: $e'));
    }
  }

  void _onSearchCustomers(SearchCustomers event, Emitter<CustomersState> emit) {
    if (state is CustomersLoaded) {
      final loaded = state as CustomersLoaded;
      final filtered = _applyFilterAndSearch(
        list: loaded.allCustomers,
        summaries: loaded.summaries,
        query: event.query,
        filter: loaded.activeFilter,
      );
      emit(loaded.copyWith(
        searchQuery: event.query,
        customers: filtered,
      ));
    }
  }

  void _onFilterCustomers(FilterCustomersEvent event, Emitter<CustomersState> emit) {
    if (state is CustomersLoaded) {
      final loaded = state as CustomersLoaded;
      final filtered = _applyFilterAndSearch(
        list: loaded.allCustomers,
        summaries: loaded.summaries,
        query: loaded.searchQuery,
        filter: event.filter,
      );
      emit(loaded.copyWith(
        activeFilter: event.filter,
        customers: filtered,
      ));
    }
  }

  List<Customer> _applyFilterAndSearch({
    required List<Customer> list,
    required Map<String, CustomerFinancialSummary> summaries,
    required String query,
    required CustomerListFilter filter,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    return list.where((customer) {
      if (cleanQuery.isNotEmpty) {
        final nameMatches = customer.name.toLowerCase().contains(cleanQuery);
        final phoneMatches = customer.phone != null && customer.phone!.contains(cleanQuery);
        final whatsappMatches = customer.whatsapp != null && customer.whatsapp!.contains(cleanQuery);
        if (!nameMatches && !phoneMatches && !whatsappMatches) {
          return false;
        }
      }

      return CustomerFinancialHelper.matchesFilter(
        customer: customer,
        summary: summaries[customer.id],
        filter: filter,
      );
    }).toList();
  }

  Map<CustomerListFilter, int> _calculateCounts({
    required List<Customer> allCustomers,
    required Map<String, CustomerFinancialSummary> summaries,
  }) {
    final counts = <CustomerListFilter, int>{};
    for (final filter in CustomerListFilter.values) {
      counts[filter] = allCustomers.where((customer) {
        return CustomerFinancialHelper.matchesFilter(
          customer: customer,
          summary: summaries[customer.id],
          filter: filter,
        );
      }).length;
    }
    return counts;
  }

  Future<void> _onCreateCustomer(CreateCustomerEvent event, Emitter<CustomersState> emit) async {
    await repository.saveCustomer(event.customer);
    add(const LoadCustomers());
  }

  Future<void> _onUpdateCustomer(UpdateCustomerEvent event, Emitter<CustomersState> emit) async {
    await repository.updateCustomer(event.customer);
    add(const LoadCustomers());
  }

  Future<void> _onDeleteCustomer(DeleteCustomerEvent event, Emitter<CustomersState> emit) async {
    await repository.deleteCustomer(event.customerId);
    add(const LoadCustomers());
  }
}

