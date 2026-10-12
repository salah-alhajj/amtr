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
        final Map<String, dynamic> updateData = {'shipmentId': shipment.id};
        if (shipment.status == AppConstants.shipmentDispatched ||
            shipment.status == AppConstants.shipmentCheckpoint) {
          updateData['orderStatus'] = AppConstants.orderStatusInCargo;
        } else if (shipment.status == AppConstants.shipmentDistribution) {
          updateData['orderStatus'] = AppConstants.orderStatusReady;
        } else if (shipment.status == AppConstants.shipmentDelivered) {
          updateData['orderStatus'] = AppConstants.orderStatusDelivered;
          updateData['actualDeliveryDate'] = DateTime.now().toIso8601String();
        }
        await txn.update(
          'orders',
          updateData,
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

      // فك ربط الطلبات السابقة التي تم استبعادها
      await txn.update(
        'orders',
        {'shipmentId': null},
        where: 'shipmentId = ?',
        whereArgs: [shipment.id],
      );

      for (final orderId in orderIds) {
        final Map<String, dynamic> updateData = {'shipmentId': shipment.id};
        if (shipment.status == AppConstants.shipmentDispatched ||
            shipment.status == AppConstants.shipmentCheckpoint) {
          updateData['orderStatus'] = AppConstants.orderStatusInCargo;
        } else if (shipment.status == AppConstants.shipmentDistribution) {
          updateData['orderStatus'] = AppConstants.orderStatusReady;
        } else if (shipment.status == AppConstants.shipmentDelivered) {
          updateData['orderStatus'] = AppConstants.orderStatusDelivered;
          updateData['actualDeliveryDate'] = DateTime.now().toIso8601String();
        }
        await txn.update(
          'orders',
          updateData,
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
    await db.transaction((txn) async {
      final Map<String, dynamic> shipmentUpdate = {'status': newStatus};
      if (newStatus == AppConstants.shipmentDelivered) {
        shipmentUpdate['actualDeliveryDate'] = DateTime.now().toIso8601String();
      }

      await txn.update(
        'shipments',
        shipmentUpdate,
        where: 'id = ?',
        whereArgs: [shipmentId],
      );

      // افتراضياً: مزامنة حالة كافة الطلبات الفردية التابعة للشحنة لتطابق حالة الشحنة المجمعة
      if (newStatus == AppConstants.shipmentDispatched ||
          newStatus == AppConstants.shipmentCheckpoint) {
        await txn.update(
          'orders',
          {'orderStatus': AppConstants.orderStatusInCargo},
          where: 'shipmentId = ?',
          whereArgs: [shipmentId],
        );
      } else if (newStatus == AppConstants.shipmentDistribution) {
        await txn.update(
          'orders',
          {'orderStatus': AppConstants.orderStatusReady},
          where: 'shipmentId = ?',
          whereArgs: [shipmentId],
        );
      } else if (newStatus == AppConstants.shipmentDelivered) {
        await txn.update(
          'orders',
          {
            'orderStatus': AppConstants.orderStatusDelivered,
            'actualDeliveryDate': DateTime.now().toIso8601String(),
          },
          where: 'shipmentId = ?',
          whereArgs: [shipmentId],
        );
      }
    });
  }

  @override
  Future<void> removeOrderFromShipment(String shipmentId, String orderId) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'shipmentId': null,
          'orderStatus': AppConstants.orderStatusPurchased,
        },
        where: 'id = ? AND shipmentId = ?',
        whereArgs: [orderId, shipmentId],
      );
    });
  }

  @override
  Future<void> updateIndividualOrderStatus(String orderId, String newStatus) async {
    final db = await dbHelper.database;
    final Map<String, dynamic> updateData = {'orderStatus': newStatus};
    if (newStatus == AppConstants.orderStatusDelivered) {
      updateData['actualDeliveryDate'] = DateTime.now().toIso8601String();
    }
    await db.update(
      'orders',
      updateData,
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> verifyAllOrdersInShipment(String shipmentId, String targetStatus) async {
    final db = await dbHelper.database;
    final Map<String, dynamic> updateData = {'orderStatus': targetStatus};
    if (targetStatus == AppConstants.orderStatusDelivered) {
      updateData['actualDeliveryDate'] = DateTime.now().toIso8601String();
    }
    await db.update(
      'orders',
      updateData,
      where: 'shipmentId = ?',
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
