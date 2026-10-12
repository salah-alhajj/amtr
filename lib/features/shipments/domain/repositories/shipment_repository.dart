import '../../../../models/consolidated_shipment.dart';

abstract class ShipmentRepository {
  Future<List<ConsolidatedShipment>> getAllShipments();
  Future<ConsolidatedShipment?> getShipmentById(String id);
  Future<void> saveShipment(ConsolidatedShipment shipment, List<String> orderIds);
  Future<void> updateShipment(ConsolidatedShipment shipment, List<String> orderIds);
  Future<void> deleteShipment(String id);
  Future<void> updateShipmentStatus(String shipmentId, String newStatus);
  Future<void> removeOrderFromShipment(String shipmentId, String orderId);
  Future<void> updateIndividualOrderStatus(String orderId, String newStatus);
  Future<void> verifyAllOrdersInShipment(String shipmentId, String targetStatus);
  Future<List<ConsolidatedShipment>> searchShipments(String query);
}
