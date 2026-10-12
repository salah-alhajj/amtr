import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../domain/repositories/shipment_repository.dart';

// --- Events ---
abstract class ShipmentsEvent {
  const ShipmentsEvent();
}

class LoadShipments extends ShipmentsEvent {
  const LoadShipments();
}

class SearchShipments extends ShipmentsEvent {
  final String query;
  const SearchShipments(this.query);
}

class FilterShipments extends ShipmentsEvent {
  final String status;
  const FilterShipments(this.status);
}

class CreateShipmentEvent extends ShipmentsEvent {
  final ConsolidatedShipment shipment;
  final List<String> orderIds;
  const CreateShipmentEvent(this.shipment, this.orderIds);
}

class UpdateShipmentEvent extends ShipmentsEvent {
  final ConsolidatedShipment shipment;
  final List<String> orderIds;
  const UpdateShipmentEvent(this.shipment, this.orderIds);
}

class DeleteShipmentEvent extends ShipmentsEvent {
  final String shipmentId;
  const DeleteShipmentEvent(this.shipmentId);
}

class AdvanceShipmentStatusEvent extends ShipmentsEvent {
  final String shipmentId;
  final String newStatus;
  const AdvanceShipmentStatusEvent(this.shipmentId, this.newStatus);
}

class RemoveOrderFromShipmentEvent extends ShipmentsEvent {
  final String shipmentId;
  final String orderId;
  const RemoveOrderFromShipmentEvent(this.shipmentId, this.orderId);
}

class UpdateIndividualOrderStatusEvent extends ShipmentsEvent {
  final String orderId;
  final String newStatus;
  const UpdateIndividualOrderStatusEvent(this.orderId, this.newStatus);
}

class VerifyAllOrdersInShipmentEvent extends ShipmentsEvent {
  final String shipmentId;
  final String targetStatus;
  const VerifyAllOrdersInShipmentEvent(this.shipmentId, this.targetStatus);
}

// --- States ---
abstract class ShipmentsState {
  const ShipmentsState();
}

class ShipmentsInitial extends ShipmentsState {
  const ShipmentsInitial();
}

class ShipmentsLoading extends ShipmentsState {
  const ShipmentsLoading();
}

class ShipmentsLoaded extends ShipmentsState {
  final List<ConsolidatedShipment> allShipments;
  final List<ConsolidatedShipment> shipments;
  final String selectedFilter;
  final String searchQuery;

  const ShipmentsLoaded({
    required this.allShipments,
    required this.shipments,
    this.selectedFilter = 'all',
    this.searchQuery = '',
  });

  ShipmentsLoaded copyWith({
    List<ConsolidatedShipment>? allShipments,
    List<ConsolidatedShipment>? shipments,
    String? selectedFilter,
    String? searchQuery,
  }) {
    return ShipmentsLoaded(
      allShipments: allShipments ?? this.allShipments,
      shipments: shipments ?? this.shipments,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ShipmentsError extends ShipmentsState {
  final String message;
  const ShipmentsError(this.message);
}

// --- BLoC ---
class ShipmentsBloc extends Bloc<ShipmentsEvent, ShipmentsState> {
  final ShipmentRepository repository;

  ShipmentsBloc({required this.repository}) : super(const ShipmentsInitial()) {
    on<LoadShipments>(_onLoadShipments);
    on<FilterShipments>(_onFilterShipments);
    on<SearchShipments>(_onSearchShipments);
    on<CreateShipmentEvent>(_onCreateShipment);
    on<UpdateShipmentEvent>(_onUpdateShipment);
    on<DeleteShipmentEvent>(_onDeleteShipment);
    on<AdvanceShipmentStatusEvent>(_onAdvanceStatus);
    on<RemoveOrderFromShipmentEvent>(_onRemoveOrder);
    on<UpdateIndividualOrderStatusEvent>(_onUpdateIndividualStatus);
    on<VerifyAllOrdersInShipmentEvent>(_onVerifyAllOrders);
  }

  List<ConsolidatedShipment> _applyFilterAndSearch(
    List<ConsolidatedShipment> list,
    String filter,
    String query,
  ) {
    return list.where((shipment) {
      if (filter != 'all' && shipment.status != filter) {
        return false;
      }
      if (query.trim().isNotEmpty) {
        final clean = query.trim().toLowerCase();
        final matchTracking = (shipment.trackingNumber ?? '').toLowerCase().contains(clean);
        final matchCarrier = (shipment.carrier ?? '').toLowerCase().contains(clean);
        final matchNotes = (shipment.notes ?? '').toLowerCase().contains(clean);
        if (!matchTracking && !matchCarrier && !matchNotes) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _onLoadShipments(LoadShipments event, Emitter<ShipmentsState> emit) async {
    final prevFilter = state is ShipmentsLoaded ? (state as ShipmentsLoaded).selectedFilter : 'all';
    final prevQuery = state is ShipmentsLoaded ? (state as ShipmentsLoaded).searchQuery : '';
    emit(const ShipmentsLoading());
    try {
      final all = await repository.getAllShipments();
      final filtered = _applyFilterAndSearch(all, prevFilter, prevQuery);
      emit(ShipmentsLoaded(
        allShipments: all,
        shipments: filtered,
        selectedFilter: prevFilter,
        searchQuery: prevQuery,
      ));
    } catch (e) {
      emit(ShipmentsError('فشل تحميل الشحنات: $e'));
    }
  }

  void _onFilterShipments(FilterShipments event, Emitter<ShipmentsState> emit) {
    if (state is ShipmentsLoaded) {
      final current = state as ShipmentsLoaded;
      final filtered = _applyFilterAndSearch(current.allShipments, event.status, current.searchQuery);
      emit(current.copyWith(selectedFilter: event.status, shipments: filtered));
    }
  }

  Future<void> _onSearchShipments(SearchShipments event, Emitter<ShipmentsState> emit) async {
    if (state is ShipmentsLoaded) {
      final current = state as ShipmentsLoaded;
      final filtered = _applyFilterAndSearch(current.allShipments, current.selectedFilter, event.query);
      emit(current.copyWith(searchQuery: event.query, shipments: filtered));
    } else {
      emit(const ShipmentsLoading());
      try {
        final all = await repository.getAllShipments();
        final filtered = _applyFilterAndSearch(all, 'all', event.query);
        emit(ShipmentsLoaded(allShipments: all, shipments: filtered, searchQuery: event.query));
      } catch (e) {
        emit(ShipmentsError('خطأ أثناء البحث: $e'));
      }
    }
  }

  Future<void> _onCreateShipment(CreateShipmentEvent event, Emitter<ShipmentsState> emit) async {
    await repository.saveShipment(event.shipment, event.orderIds);
    add(const LoadShipments());
  }

  Future<void> _onUpdateShipment(UpdateShipmentEvent event, Emitter<ShipmentsState> emit) async {
    await repository.updateShipment(event.shipment, event.orderIds);
    add(const LoadShipments());
  }

  Future<void> _onDeleteShipment(DeleteShipmentEvent event, Emitter<ShipmentsState> emit) async {
    await repository.deleteShipment(event.shipmentId);
    add(const LoadShipments());
  }

  Future<void> _onAdvanceStatus(AdvanceShipmentStatusEvent event, Emitter<ShipmentsState> emit) async {
    await repository.updateShipmentStatus(event.shipmentId, event.newStatus);
    add(const LoadShipments());
  }

  Future<void> _onRemoveOrder(RemoveOrderFromShipmentEvent event, Emitter<ShipmentsState> emit) async {
    await repository.removeOrderFromShipment(event.shipmentId, event.orderId);
    add(const LoadShipments());
  }

  Future<void> _onUpdateIndividualStatus(UpdateIndividualOrderStatusEvent event, Emitter<ShipmentsState> emit) async {
    await repository.updateIndividualOrderStatus(event.orderId, event.newStatus);
    add(const LoadShipments());
  }

  Future<void> _onVerifyAllOrders(VerifyAllOrdersInShipmentEvent event, Emitter<ShipmentsState> emit) async {
    await repository.verifyAllOrdersInShipment(event.shipmentId, event.targetStatus);
    add(const LoadShipments());
  }
}
