import '../../../../core/database/app_database.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final AppDatabase dbHelper;

  OrderRepositoryImpl({AppDatabase? db}) : dbHelper = db ?? AppDatabase.instance;

  @override
  Future<List<IndividualOrder>> getAllOrders() async {
    final db = await dbHelper.database;
    final orderMaps = await db.query('orders', orderBy: 'createdAt DESC');
    final List<IndividualOrder> orders = [];

    for (final map in orderMaps) {
      final orderId = map['id'] as String;
      final itemMaps = await db.query(
        'order_items',
        where: 'orderId = ?',
        whereArgs: [orderId],
      );
      final items = itemMaps.map((e) => OrderItem.fromMap(e)).toList();
      orders.add(IndividualOrder.fromMap(map, items: items));
    }

    return orders;
  }

  @override
  Future<IndividualOrder?> getOrderById(String id) async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (orderMaps.isEmpty) return null;

    final itemMaps = await db.query(
      'order_items',
      where: 'orderId = ?',
      whereArgs: [id],
    );
    final items = itemMaps.map((e) => OrderItem.fromMap(e)).toList();
    return IndividualOrder.fromMap(orderMaps.first, items: items);
  }

  @override
  Future<List<IndividualOrder>> getOrdersByCustomerId(String customerId) async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'customerId = ?',
      whereArgs: [customerId],
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
  Future<List<IndividualOrder>> getOrdersByShipmentId(String shipmentId) async {
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
  Future<List<IndividualOrder>> getUnassignedOrders() async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'shipmentId IS NULL OR shipmentId = ""',
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
  Future<void> saveOrder(IndividualOrder order, List<OrderItem> items) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('orders', order.toMap());
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }
    });
  }

  @override
  Future<void> updateOrder(IndividualOrder order, List<OrderItem> items) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        order.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );

      // تحديث بنود الطلب
      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [order.id]);
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }
    });
  }

  @override
  Future<void> deleteOrder(String id) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [id]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> updatePaymentStatus(String orderId, String status, double paidAmount) async {
    final db = await dbHelper.database;
    await db.update(
      'orders',
      {
        'paymentStatus': status,
        'paidAmount': paidAmount,
      },
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<void> assignOrderToShipment(String orderId, String? shipmentId) async {
    final db = await dbHelper.database;
    await db.update(
      'orders',
      {'shipmentId': shipmentId},
      where: 'id = ?',
      whereArgs: [orderId],
    );
  }

  @override
  Future<List<IndividualOrder>> searchOrders(String query) async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: 'orderNumber LIKE ? OR customerName LIKE ? OR notes LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
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
}
