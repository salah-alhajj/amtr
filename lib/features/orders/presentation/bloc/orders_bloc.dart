import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
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

class AdvanceOrderStatusEvent extends OrdersEvent {
  final String orderId;
  final String targetStatus;
  const AdvanceOrderStatusEvent(this.orderId, this.targetStatus);
}

class RevertOrderStatusEvent extends OrdersEvent {
  final String orderId;
  final String previousStatus;
  const RevertOrderStatusEvent(this.orderId, this.previousStatus);
}

class ReorderEvent extends OrdersEvent {
  final IndividualOrder sourceOrder;
  const ReorderEvent(this.sourceOrder);
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
  late final StreamSubscription<DataDomain> _syncSub;
  bool _isSelfMutating = false;

  OrdersBloc({required this.repository}) : super(const OrdersInitial()) {
    on<LoadOrders>(_onLoadOrders);
    on<FilterOrders>(_onFilterOrders);
    on<SearchOrders>(_onSearchOrders);
    on<CreateOrderEvent>(_onCreateOrder);
    on<UpdateOrderEvent>(_onUpdateOrder);
    on<DeleteOrderEvent>(_onDeleteOrder);
    on<RecordPaymentEvent>(_onRecordPayment);
    on<AdvanceOrderStatusEvent>(_onAdvanceOrderStatus);
    on<RevertOrderStatusEvent>(_onRevertOrderStatus);
    on<ReorderEvent>(_onReorder);
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!isClosed &&
          !_isSelfMutating &&
          state is OrdersLoaded &&
          (domain == DataDomain.orders || domain == DataDomain.payments)) {
        add(const LoadOrders());
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

  static String? getNextStatus(String currentStatus, {bool? isProductiveFamily}) {
    final pfMode =
        isProductiveFamily ?? PreferencesService.instance.isProductiveFamilyMode;
    if (pfMode) {
      switch (currentStatus) {
        case AppConstants.orderStatusPending:
          return AppConstants.orderStatusPurchased;
        case AppConstants.orderStatusPurchased:
          return AppConstants.orderStatusReady;
        case AppConstants.orderStatusInCargo:
          return AppConstants.orderStatusReady;
        case AppConstants.orderStatusReady:
          return AppConstants.orderStatusDelivered;
        default:
          return null;
      }
    }
    switch (currentStatus) {
      case AppConstants.orderStatusPending:
        return AppConstants.orderStatusPurchased;
      case AppConstants.orderStatusPurchased:
        return AppConstants.orderStatusInCargo;
      case AppConstants.orderStatusInCargo:
        return AppConstants.orderStatusReady;
      case AppConstants.orderStatusReady:
        return AppConstants.orderStatusDelivered;
      default:
        return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<IndividualOrder> _applyFilterAndSearch(
    List<IndividualOrder> list,
    String filter,
    String query,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return list.where((order) {
      if (filter == 'today') {
        final isToday = _isSameDay(order.createdAt, now) ||
            (order.expectedDeliveryDate != null &&
                _isSameDay(order.expectedDeliveryDate!, now));
        if (!isToday || order.orderStatus == AppConstants.orderStatusDelivered) {
          return false;
        }
      }
      if (filter == 'new' && order.orderStatus != AppConstants.orderStatusPending) {
        return false;
      }
      if (filter == 'preparing' &&
          order.orderStatus != AppConstants.orderStatusPurchased) {
        return false;
      }
      if (filter == 'ready' && order.orderStatus != AppConstants.orderStatusReady) {
        return false;
      }
      if (filter == 'occasions') {
        final hasOccasion =
            order.occasionLabel != null && order.occasionLabel!.trim().isNotEmpty;
        final isUpcomingDelivery = order.expectedDeliveryDate != null &&
            !order.expectedDeliveryDate!.isBefore(todayStart);
        if (!hasOccasion && !isUpcomingDelivery) {
          return false;
        }
      }
      if (filter == 'debt' && order.paymentStatus != AppConstants.paymentDebt) {
        return false;
      }
      if (filter == 'partial' && order.paymentStatus != AppConstants.paymentPartial) {
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
    final prevFilter =
        state is OrdersLoaded ? (state as OrdersLoaded).selectedFilter : 'all';
    final prevQuery =
        state is OrdersLoaded ? (state as OrdersLoaded).searchQuery : '';
    if (state is! OrdersLoaded) {
      emit(const OrdersLoading());
    }
    try {
      final orders = await repository.getAllOrders();
      final filtered = _applyFilterAndSearch(orders, prevFilter, prevQuery);
      emit(OrdersLoaded(
        allOrders: orders,
        displayedOrders: filtered,
        selectedFilter: prevFilter,
        searchQuery: prevQuery,
      ));
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
    await _runSelfMutation(() => repository.saveOrder(event.order, event.items));
    add(const LoadOrders());
  }

  Future<void> _onUpdateOrder(UpdateOrderEvent event, Emitter<OrdersState> emit) async {
    await _runSelfMutation(() => repository.updateOrder(event.order, event.items));
    add(const LoadOrders());
  }

  Future<void> _onDeleteOrder(DeleteOrderEvent event, Emitter<OrdersState> emit) async {
    await _runSelfMutation(() => repository.deleteOrder(event.orderId));
    add(const LoadOrders());
  }

  Future<void> _onRecordPayment(RecordPaymentEvent event, Emitter<OrdersState> emit) async {
    await _runSelfMutation(() => repository.updatePaymentStatus(event.orderId, event.newStatus, event.paidAmount));
    add(const LoadOrders());
  }

  Future<void> _onAdvanceOrderStatus(
    AdvanceOrderStatusEvent event,
    Emitter<OrdersState> emit,
  ) async {
    await _updateOrderStatusOptimistic(event.orderId, event.targetStatus, emit);
  }

  Future<void> _onRevertOrderStatus(
    RevertOrderStatusEvent event,
    Emitter<OrdersState> emit,
  ) async {
    await _updateOrderStatusOptimistic(event.orderId, event.previousStatus, emit);
  }

  Future<void> _onReorder(
    ReorderEvent event,
    Emitter<OrdersState> emit,
  ) async {
    final source = event.sourceOrder;
    const uuid = Uuid();
    final newOrderId = uuid.v4();
    final newOrderNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
    final productRepo = ProductRepositoryImpl();

    final List<OrderItem> newItems = [];
    for (final item in source.items) {
      double costPrice = item.costPrice;
      double? sellPrice = item.sellPrice;

      if (item.productId != null && item.productId!.isNotEmpty) {
        final product = await productRepo.getProductById(item.productId!);
        if (product != null) {
          if (product.currency != item.currency) {
            costPrice = CurrencyService.instance.convert(
              amount: product.costPrice,
              fromCurrency: product.currency,
              toCurrency: item.currency,
            );
            sellPrice = CurrencyService.instance.convert(
              amount: product.sellPrice,
              fromCurrency: product.currency,
              toCurrency: item.currency,
            );
          } else {
            costPrice = product.costPrice;
            sellPrice = product.sellPrice;
          }
        }
      }

      newItems.add(
        item.copyWith(
          id: uuid.v4(),
          orderId: newOrderId,
          costPrice: costPrice,
          sellPrice: sellPrice,
        ),
      );
    }

    final newPaymentStatus = source.paymentStatus == AppConstants.paymentPrepaid
        ? AppConstants.paymentDebt
        : source.paymentStatus;

    final newOrder = IndividualOrder(
      id: newOrderId,
      orderNumber: newOrderNumber,
      customerId: source.customerId,
      customerName: source.customerName,
      shipmentId: null,
      paymentStatus: newPaymentStatus,
      orderStatus: AppConstants.orderStatusPending,
      createdAt: DateTime.now(),
      paidAmount: 0.0,
      additionalCost: source.additionalCost,
      discount: source.discount,
      deliveryFee: source.deliveryFee,
      deliveryType: source.deliveryType,
      deliveryAddress: source.deliveryAddress,
      isQuickOrder: source.isQuickOrder,
      occasionLabel: source.occasionLabel,
      currency: source.currency,
      notes: source.notes,
      items: newItems,
    );

    await _runSelfMutation(() => repository.saveOrder(newOrder, newItems));
    add(const LoadOrders());
  }

  Future<void> _updateOrderStatusOptimistic(
    String orderId,
    String newStatus,
    Emitter<OrdersState> emit,
  ) async {
    if (state is! OrdersLoaded) {
      final existing = await repository.getOrderById(orderId);
      if (existing == null) return;
      final updated = existing.copyWith(
        orderStatus: newStatus,
        actualDeliveryDate: newStatus == AppConstants.orderStatusDelivered
            ? (existing.actualDeliveryDate ?? DateTime.now())
            : existing.actualDeliveryDate,
      );
      await _runSelfMutation(() => repository.updateOrder(updated, updated.items));
      add(const LoadOrders());
      return;
    }

    final current = state as OrdersLoaded;
    IndividualOrder? updatedOrder;
    final updatedAll = current.allOrders.map((order) {
      if (order.id != orderId) return order;
      updatedOrder = order.copyWith(
        orderStatus: newStatus,
        actualDeliveryDate: newStatus == AppConstants.orderStatusDelivered
            ? (order.actualDeliveryDate ?? DateTime.now())
            : order.actualDeliveryDate,
      );
      return updatedOrder!;
    }).toList();

    if (updatedOrder == null) return;

    final filtered = _applyFilterAndSearch(
      updatedAll,
      current.selectedFilter,
      current.searchQuery,
    );
    emit(current.copyWith(allOrders: updatedAll, displayedOrders: filtered));

    try {
      await _runSelfMutation(() => repository.updateOrder(updatedOrder!, updatedOrder!.items));
    } catch (e) {
      // التراجع عن التحديث المتفائل عند فشل الحفظ
      final revertedFiltered = _applyFilterAndSearch(
        current.allOrders,
        current.selectedFilter,
        current.searchQuery,
      );
      emit(current.copyWith(
        allOrders: current.allOrders,
        displayedOrders: revertedFiltered,
      ));
    }
  }
}
