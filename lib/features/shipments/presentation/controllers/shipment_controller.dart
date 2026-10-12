import 'package:flutter/foundation.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../domain/repositories/shipment_repository.dart';

class ShipmentController extends ChangeNotifier {
  final ShipmentRepository repository;

  bool _isLoading = false;
  List<ConsolidatedShipment> _shipments = [];
  String _searchQuery = '';

  ShipmentController({required this.repository});

  bool get isLoading => _isLoading;
  List<ConsolidatedShipment> get shipments => _shipments;
  String get searchQuery => _searchQuery;

  Future<void> loadShipments() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_searchQuery.trim().isEmpty) {
        _shipments = await repository.getAllShipments();
      } else {
        _shipments = await repository.searchShipments(_searchQuery.trim());
      }
    } catch (e) {
      debugPrint('Error loading shipments: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    _searchQuery = query;
    loadShipments();
  }

  Future<void> saveShipment(ConsolidatedShipment shipment, List<String> orderIds) async {
    await repository.saveShipment(shipment, orderIds);
    await loadShipments();
  }

  Future<void> updateShipment(ConsolidatedShipment shipment, List<String> orderIds) async {
    await repository.updateShipment(shipment, orderIds);
    await loadShipments();
  }

  Future<void> deleteShipment(String id) async {
    await repository.deleteShipment(id);
    await loadShipments();
  }

  Future<void> advanceShipmentStatus(String shipmentId, String newStatus) async {
    await repository.updateShipmentStatus(shipmentId, newStatus);
    await loadShipments();
  }
}
