import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';

abstract class OrderRepository {
  Future<List<IndividualOrder>> getAllOrders();
  Future<IndividualOrder?> getOrderById(String id);
  Future<List<IndividualOrder>> getOrdersByCustomerId(String customerId);
  Future<List<IndividualOrder>> getOrdersByShipmentId(String shipmentId);
  Future<List<IndividualOrder>> getUnassignedOrders(); // الطلبات التي لم تُضم لشحنة مجمعة بعد
  Future<void> saveOrder(IndividualOrder order, List<OrderItem> items);
  Future<void> updateOrder(IndividualOrder order, List<OrderItem> items);
  Future<void> deleteOrder(String id);
  Future<void> updatePaymentStatus(String orderId, String status, double paidAmount);
  Future<void> assignOrderToShipment(String orderId, String? shipmentId);
  Future<List<IndividualOrder>> searchOrders(String query);
}
