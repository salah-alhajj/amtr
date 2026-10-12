import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

// --- Events ---
abstract class OrdersEvent {
  const OrdersEvent();
}

class LoadOrders extends OrdersEvent {
  const LoadOrders();
}

class FilterOrders extends OrdersEvent {
  final String filter; // all, debt, prepaid, cod, unassigned
  const FilterOrders(this.filter);
}

class SearchOrders extends OrdersEvent {
  final String query;
  const SearchOrders(this.query);
}

class CreateOrderEvent extends OrdersEvent {
  final IndividualOrder order;
  final List<OrderItem> items;
  const CreateOrderEvent(this.order, this.items);
}

class UpdateOrderEvent extends OrdersEvent {
  final IndividualOrder order;
  final List<OrderItem> items;
  const UpdateOrderEvent(this.order, this.items);
}

class DeleteOrderEvent extends OrdersEvent {
  final String orderId;
  const DeleteOrderEvent(this.orderId);
}

class RecordPaymentEvent extends OrdersEvent {
  final String orderId;
  final double paidAmount;
  final String newStatus;
  const RecordPaymentEvent({
    required this.orderId,
    required this.paidAmount,
    required this.newStatus,
  });
}

// --- States ---
abstract class OrdersState {
  const OrdersState();
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<IndividualOrder> allOrders;
  final List<IndividualOrder> displayedOrders;
  final String selectedFilter;
  final String searchQuery;

  const OrdersLoaded({
    required this.allOrders,
    required this.displayedOrders,
    this.selectedFilter = 'all',
    this.searchQuery = '',
  });

  OrdersLoaded copyWith({
    List<IndividualOrder>? allOrders,
    List<IndividualOrder>? displayedOrders,
    String? selectedFilter,
    String? searchQuery,
  }) {
    return OrdersLoaded(
      allOrders: allOrders ?? this.allOrders,
      displayedOrders: displayedOrders ?? this.displayedOrders,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class OrdersError extends OrdersState {
  final String message;
  const OrdersError(this.message);
}

// --- BLoC ---
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrderRepository repository;

  OrdersBloc({required this.repository}) : super(const OrdersInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<FilterOrders>(_onFilterOrders);
    on<SearchOrders>(_onSearchOrders);
    on<CreateOrderEvent>(_onCreateOrder);
    on<UpdateOrderEvent>(_onUpdateOrder);
    on<DeleteOrderEvent>(_onDeleteOrder);
    on<RecordPaymentEvent>(_onRecordPayment);
  }

  List<IndividualOrder> _applyFilterAndSearch(
    List<IndividualOrder> list,
    String filter,
    String query,
  ) {
    return list.where((order) {
      if (filter == 'debt' && order.paymentStatus != AppConstants.paymentDebt) {
        return false;
      }
      if (filter == 'prepaid' && order.paymentStatus != AppConstants.paymentPrepaid) {
        return false;
      }
      if (filter == 'cod' && order.paymentStatus != AppConstants.paymentCod) {
        return false;
      }
      if (filter == 'unassigned' && (order.shipmentId != null && order.shipmentId!.isNotEmpty)) {
        return false;
      }

      if (query.trim().isNotEmpty) {
        final clean = query.trim().toLowerCase();
        final matchNum = order.orderNumber.toLowerCase().contains(clean);
        final matchCust = (order.customerName ?? '').toLowerCase().contains(clean);
        if (!matchNum && !matchCust) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _onLoadOrders(LoadOrders event, Emitter<OrdersState> emit) async {
    emit(const OrdersLoading());
    try {
      final orders = await repository.getAllOrders();
      final filtered = _applyFilterAndSearch(orders, 'all', '');
      emit(OrdersLoaded(allOrders: orders, displayedOrders: filtered));
    } catch (e) {
      emit(OrdersError('فشل تحميل الطلبات: $e'));
    }
  }

  void _onFilterOrders(FilterOrders event, Emitter<OrdersState> emit) {
    if (state is OrdersLoaded) {
      final current = state as OrdersLoaded;
      final filtered = _applyFilterAndSearch(current.allOrders, event.filter, current.searchQuery);
      emit(current.copyWith(selectedFilter: event.filter, displayedOrders: filtered));
    }
  }

  void _onSearchOrders(SearchOrders event, Emitter<OrdersState> emit) {
    if (state is OrdersLoaded) {
      final current = state as OrdersLoaded;
      final filtered = _applyFilterAndSearch(current.allOrders, current.selectedFilter, event.query);
      emit(current.copyWith(searchQuery: event.query, displayedOrders: filtered));
    }
  }

  Future<void> _onCreateOrder(CreateOrderEvent event, Emitter<OrdersState> emit) async {
    await repository.saveOrder(event.order, event.items);
    add(const LoadOrders());
  }

  Future<void> _onUpdateOrder(UpdateOrderEvent event, Emitter<OrdersState> emit) async {
    await repository.updateOrder(event.order, event.items);
    add(const LoadOrders());
  }

  Future<void> _onDeleteOrder(DeleteOrderEvent event, Emitter<OrdersState> emit) async {
    await repository.deleteOrder(event.orderId);
    add(const LoadOrders());
  }

  Future<void> _onRecordPayment(RecordPaymentEvent event, Emitter<OrdersState> emit) async {
    await repository.updatePaymentStatus(event.orderId, event.newStatus, event.paidAmount);
    add(const LoadOrders());
  }
}
