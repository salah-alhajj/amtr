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
  final List<ConsolidatedShipment> shipments;
  final String searchQuery;

  const ShipmentsLoaded({
    required this.shipments,
    this.searchQuery = '',
  });

  ShipmentsLoaded copyWith({
    List<ConsolidatedShipment>? shipments,
    String? searchQuery,
  }) {
    return ShipmentsLoaded(
      shipments: shipments ?? this.shipments,
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
    on<SearchShipments>(_onSearchShipments);
    on<CreateShipmentEvent>(_onCreateShipment);
    on<UpdateShipmentEvent>(_onUpdateShipment);
    on<DeleteShipmentEvent>(_onDeleteShipment);
    on<AdvanceShipmentStatusEvent>(_onAdvanceStatus);
  }

  Future<void> _onLoadShipments(LoadShipments event, Emitter<ShipmentsState> emit) async {
    emit(const ShipmentsLoading());
    try {
      final list = await repository.getAllShipments();
      emit(ShipmentsLoaded(shipments: list));
    } catch (e) {
      emit(ShipmentsError('فشل تحميل الشحنات: $e'));
    }
  }

  Future<void> _onSearchShipments(SearchShipments event, Emitter<ShipmentsState> emit) async {
    emit(const ShipmentsLoading());
    try {
      final list = event.query.trim().isEmpty
          ? await repository.getAllShipments()
          : await repository.searchShipments(event.query.trim());
      emit(ShipmentsLoaded(shipments: list, searchQuery: event.query));
    } catch (e) {
      emit(ShipmentsError('خطأ أثناء البحث: $e'));
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
}
