import '../../../../core/database/app_database.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../domain/repositories/shipment_repository.dart';

class ShipmentRepositoryImpl implements ShipmentRepository {
  final AppDatabase dbHelper;

  ShipmentRepositoryImpl({AppDatabase? db}) : dbHelper = db ?? AppDatabase.instance;

  @override
  Future<List<ConsolidatedShipment>> getAllShipments() async {
    final db = await dbHelper.database;
    final shipmentMaps = await db.query('shipments', orderBy: 'createdAt DESC');
    final List<ConsolidatedShipment> shipments = [];

    for (final map in shipmentMaps) {
      final shipmentId = map['id'] as String;
      final orders = await _getOrdersForShipment(shipmentId);
      shipments.add(ConsolidatedShipment.fromMap(map, orders: orders));
    }

    return shipments;
  }

  @override
  Future<ConsolidatedShipment?> getShipmentById(String id) async {
    final db = await dbHelper.database;
    final shipmentMaps = await db.query(
      'shipments',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (shipmentMaps.isEmpty) return null;

    final orders = await _getOrdersForShipment(id);
    return ConsolidatedShipment.fromMap(shipmentMaps.first, orders: orders);
  }

  Future<List<IndividualOrder>> _getOrdersForShipment(String shipmentId) async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'shipmentId = ?',
      whereArgs: [shipmentId],
      orderBy: 'createdAt DESC',
    );

    final List<IndividualOrder> orders = [];
    for (final map in orderMaps) {
      final orderId = map['id'] as String;
      final itemMaps = await db.query('order_items', where: 'orderId = ?', whereArgs: [orderId]);
      final items = itemMaps.map((e) => OrderItem.fromMap(e)).toList();
      orders.add(IndividualOrder.fromMap(map, items: items));
    }
    return orders;
  }

  @override
  Future<void> saveShipment(ConsolidatedShipment shipment, List<String> orderIds) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('shipments', shipment.toMap());
      for (final orderId in orderIds) {
        await txn.update(
          'orders',
          {'shipmentId': shipment.id},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }
    });
  }

  @override
  Future<void> updateShipment(ConsolidatedShipment shipment, List<String> orderIds) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'shipments',
        shipment.toMap(),
        where: 'id = ?',
        whereArgs: [shipment.id],
      );

      // فك ربط الطلبات السابقة وإعادة ربط المحددة فقط
      await txn.update(
        'orders',
        {'shipmentId': null},
        where: 'shipmentId = ?',
        whereArgs: [shipment.id],
      );

      for (final orderId in orderIds) {
        await txn.update(
          'orders',
          {'shipmentId': shipment.id},
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }
    });
  }

  @override
  Future<void> deleteShipment(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      // فك ربط الطلبات أولاً دون حذفها
      await txn.update(
        'orders',
        {'shipmentId': null},
        where: 'shipmentId = ?',
        whereArgs: [id],
      );
      await txn.delete('shipments', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> updateShipmentStatus(String shipmentId, String newStatus) async {
    final db = await dbHelper.database;
    await db.update(
      'shipments',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [shipmentId],
    );
  }

  @override
  Future<List<ConsolidatedShipment>> searchShipments(String query) async {
    final db = await dbHelper.database;
    final shipmentMaps = await db.query(
      'shipments',
      where: 'shipmentNumber LIKE ? OR title LIKE ? OR carrierName LIKE ? OR trackingNumber LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%', '%$query%'],
      orderBy: 'createdAt DESC',
    );

    final List<ConsolidatedShipment> shipments = [];
    for (final map in shipmentMaps) {
      final shipmentId = map['id'] as String;
      final orders = await _getOrdersForShipment(shipmentId);
      shipments.add(ConsolidatedShipment.fromMap(map, orders: orders));
    }
    return shipments;
  }
}
