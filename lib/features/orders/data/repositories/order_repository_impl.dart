import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../domain/repositories/order_repository.dart';

class OrderRepositoryImpl implements OrderRepository {
  final AppDatabase dbHelper;

  OrderRepositoryImpl({AppDatabase? db}) : dbHelper = db ?? AppDatabase.instance;

  /// تطبيق فروقات المخزون ذرياً داخل معاملة SQLite للمنتجات المفعّل لها تتبع المخزون ومكوّنات الباقات
  Future<bool> _applyStockDeltasInTxn(
    Transaction txn,
    Map<String, int> stockDeltas,
  ) async {
    final expandedDeltas = <String, int>{};

    for (final entry in stockDeltas.entries) {
      final productId = entry.key;
      final delta = entry.value;
      if (productId.isEmpty || delta == 0) continue;

      expandedDeltas[productId] = (expandedDeltas[productId] ?? 0) + delta;

      final rows = await txn.query(
        'products',
        columns: ['isBundle'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isNotEmpty && (rows.first['isBundle'] as num?)?.toInt() == 1) {
        final bundleItems = await txn.query(
          'product_bundle_items',
          columns: ['componentProductId', 'quantity'],
          where: 'bundleProductId = ?',
          whereArgs: [productId],
        );
        for (final bItem in bundleItems) {
          final compId = bItem['componentProductId'] as String?;
          final compQty = (bItem['quantity'] as num?)?.toInt() ?? 1;
          if (compId != null && compId.isNotEmpty && compQty > 0) {
            expandedDeltas[compId] =
                (expandedDeltas[compId] ?? 0) + (delta * compQty);
          }
        }
      }
    }

    bool stockChanged = false;
    for (final entry in expandedDeltas.entries) {
      final productId = entry.key;
      final delta = entry.value;
      if (productId.isEmpty || delta == 0) continue;

      final rows = await txn.query(
        'products',
        columns: ['stockQuantity', 'trackStock'],
        where: 'id = ?',
        whereArgs: [productId],
        limit: 1,
      );
      if (rows.isEmpty) continue;

      final trackStock = (rows.first['trackStock'] as num?)?.toInt() == 1;
      if (!trackStock) continue;

      final currentQty = (rows.first['stockQuantity'] as num?)?.toInt() ?? 0;
      final updatedQty = (currentQty + delta).clamp(0, 999999);
      await txn.update(
        'products',
        {'stockQuantity': updatedQty},
        where: 'id = ?',
        whereArgs: [productId],
      );
      stockChanged = true;
    }
    return stockChanged;
  }

  /// تطبيق فروقات مخزون المتغيرات (product_variants) ذرياً داخل معاملة SQLite
  Future<bool> _applyVariantStockDeltasInTxn(
    Transaction txn,
    Map<String, int> variantDeltas,
  ) async {
    bool changed = false;
    for (final entry in variantDeltas.entries) {
      final variantId = entry.key;
      final delta = entry.value;
      if (variantId.isEmpty || delta == 0) continue;

      final rows = await txn.query(
        'product_variants',
        columns: ['stockQuantity'],
        where: 'id = ?',
        whereArgs: [variantId],
        limit: 1,
      );
      if (rows.isEmpty) continue;

      final currentQty = (rows.first['stockQuantity'] as num?)?.toInt() ?? 0;
      final updatedQty = (currentQty + delta).clamp(0, 999999);
      await txn.update(
        'product_variants',
        {'stockQuantity': updatedQty},
        where: 'id = ?',
        whereArgs: [variantId],
      );
      changed = true;
    }
    return changed;
  }

  /// تجميع بنود الطلبات باستعلام واحد بدلاً من N+1 استعلام
  Future<List<IndividualOrder>> _hydrateOrders(
    dynamic db,
    List<Map<String, dynamic>> orderMaps,
  ) async {
    if (orderMaps.isEmpty) return [];
    final orderIds = orderMaps.map((m) => m['id'] as String).toList();
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final itemMaps = await db.rawQuery(
      'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
      orderIds,
    ) as List<Map<String, dynamic>>;

    final Map<String, List<OrderItem>> itemsByOrder = {};
    for (final itemMap in itemMaps) {
      final item = OrderItem.fromMap(itemMap);
      itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
    }

    return orderMaps
        .map(
          (map) => IndividualOrder.fromMap(
            map,
            items: itemsByOrder[map['id'] as String] ?? const [],
          ),
        )
        .toList();
  }

  @override
  Future<List<IndividualOrder>> getAllOrders() async {
    final db = await dbHelper.database;
    final orderMaps = await db.query('orders', orderBy: 'createdAt DESC');
    return _hydrateOrders(db, orderMaps);
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
    return _hydrateOrders(db, orderMaps);
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
    return _hydrateOrders(db, orderMaps);
  }

  @override
  Future<List<IndividualOrder>> getUnassignedOrders() async {
    final db = await dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where: "shipmentId IS NULL OR shipmentId = ''",
      orderBy: 'createdAt DESC',
    );
    return _hydrateOrders(db, orderMaps);
  }

  @override
  Future<void> saveOrder(IndividualOrder order, List<OrderItem> items) async {
    final db = await dbHelper.database;
    bool stockChanged = false;
    await db.transaction((txn) async {
      await txn.insert('orders', order.toMap());
      final stockDeltas = <String, int>{};
      final variantDeltas = <String, int>{};
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
        final pid = item.productId;
        if (pid != null && pid.isNotEmpty) {
          stockDeltas[pid] = (stockDeltas[pid] ?? 0) - item.quantity;
        }
        final vid = item.variantId;
        if (vid != null && vid.isNotEmpty) {
          variantDeltas[vid] = (variantDeltas[vid] ?? 0) - item.quantity;
        }
      }
      if (stockDeltas.isNotEmpty) {
        stockChanged = await _applyStockDeltasInTxn(txn, stockDeltas);
      }
      if (variantDeltas.isNotEmpty) {
        final vChanged = await _applyVariantStockDeltasInTxn(txn, variantDeltas);
        stockChanged = stockChanged || vChanged;
      }
      if (order.paidAmount > 0) {
        await txn.insert('payment_transactions', {
          'id': const Uuid().v4(),
          'orderId': order.id,
          'customerId': order.customerId,
          'amount': order.paidAmount,
          'currency': order.currency,
          'paymentMethod': AppConstants.paymentMethodCash,
          'paidAt': order.createdAt.toIso8601String(),
          'notes': order.orderNumber,
        });
      }
    });
    DataSyncBus.instance.notify(DataDomain.orders);
    if (order.paidAmount > 0) {
      DataSyncBus.instance.notify(DataDomain.payments);
    }
    if (stockChanged) {
      DataSyncBus.instance.notify(DataDomain.products);
    }
  }

  @override
  Future<void> updateOrder(IndividualOrder order, List<OrderItem> items) async {
    final db = await dbHelper.database;
    bool addedPayment = false;
    bool stockChanged = false;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'orders',
        columns: ['paidAmount'],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );
      final prevPaid = existing.isNotEmpty
          ? ((existing.first['paidAmount'] as num?)?.toDouble() ?? 0.0)
          : 0.0;

      final existingItemRows = await txn.query(
        'order_items',
        columns: ['productId', 'variantId', 'quantity'],
        where: 'orderId = ?',
        whereArgs: [order.id],
      );
      final oldQtyByProduct = <String, int>{};
      final oldQtyByVariant = <String, int>{};
      for (final row in existingItemRows) {
        final qty = (row['quantity'] as num?)?.toInt() ?? 0;
        final pid = row['productId'] as String?;
        if (pid != null && pid.isNotEmpty) {
          oldQtyByProduct[pid] = (oldQtyByProduct[pid] ?? 0) + qty;
        }
        final vid = row['variantId'] as String?;
        if (vid != null && vid.isNotEmpty) {
          oldQtyByVariant[vid] = (oldQtyByVariant[vid] ?? 0) + qty;
        }
      }

      final newQtyByProduct = <String, int>{};
      final newQtyByVariant = <String, int>{};
      for (final item in items) {
        final pid = item.productId;
        if (pid != null && pid.isNotEmpty) {
          newQtyByProduct[pid] = (newQtyByProduct[pid] ?? 0) + item.quantity;
        }
        final vid = item.variantId;
        if (vid != null && vid.isNotEmpty) {
          newQtyByVariant[vid] = (newQtyByVariant[vid] ?? 0) + item.quantity;
        }
      }

      final stockDeltas = <String, int>{};
      final allProductIds = {...oldQtyByProduct.keys, ...newQtyByProduct.keys};
      for (final pid in allProductIds) {
        final oldQty = oldQtyByProduct[pid] ?? 0;
        final newQty = newQtyByProduct[pid] ?? 0;
        final delta = oldQty - newQty;
        if (delta != 0) {
          stockDeltas[pid] = delta;
        }
      }

      final variantDeltas = <String, int>{};
      final allVariantIds = {...oldQtyByVariant.keys, ...newQtyByVariant.keys};
      for (final vid in allVariantIds) {
        final oldQty = oldQtyByVariant[vid] ?? 0;
        final newQty = newQtyByVariant[vid] ?? 0;
        final delta = oldQty - newQty;
        if (delta != 0) {
          variantDeltas[vid] = delta;
        }
      }

      await txn.update(
        'orders',
        order.toMap(),
        where: 'id = ?',
        whereArgs: [order.id],
      );

      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [order.id]);
      for (final item in items) {
        await txn.insert('order_items', item.toMap());
      }

      if (stockDeltas.isNotEmpty) {
        stockChanged = await _applyStockDeltasInTxn(txn, stockDeltas);
      }
      if (variantDeltas.isNotEmpty) {
        final vChanged = await _applyVariantStockDeltasInTxn(txn, variantDeltas);
        stockChanged = stockChanged || vChanged;
      }

      final delta = order.paidAmount - prevPaid;
      if (delta.abs() > 0.0001) {
        addedPayment = true;
        await txn.insert('payment_transactions', {
          'id': const Uuid().v4(),
          'orderId': order.id,
          'customerId': order.customerId,
          'amount': delta,
          'currency': order.currency,
          'paymentMethod': AppConstants.paymentMethodCash,
          'paidAt': DateTime.now().toIso8601String(),
          'notes': order.orderNumber,
        });
      }
    });
    DataSyncBus.instance.notify(DataDomain.orders);
    if (addedPayment) {
      DataSyncBus.instance.notify(DataDomain.payments);
    }
    if (stockChanged) {
      DataSyncBus.instance.notify(DataDomain.products);
    }
  }

  @override
  Future<void> deleteOrder(String id) async {
    final db = await dbHelper.database;
    bool stockChanged = false;
    await db.transaction((txn) async {
      final existingItemRows = await txn.query(
        'order_items',
        columns: ['productId', 'variantId', 'quantity'],
        where: 'orderId = ?',
        whereArgs: [id],
      );
      final stockDeltas = <String, int>{};
      final variantDeltas = <String, int>{};
      for (final row in existingItemRows) {
        final qty = (row['quantity'] as num?)?.toInt() ?? 0;
        final pid = row['productId'] as String?;
        if (pid != null && pid.isNotEmpty) {
          stockDeltas[pid] = (stockDeltas[pid] ?? 0) + qty;
        }
        final vid = row['variantId'] as String?;
        if (vid != null && vid.isNotEmpty) {
          variantDeltas[vid] = (variantDeltas[vid] ?? 0) + qty;
        }
      }
      if (stockDeltas.isNotEmpty) {
        stockChanged = await _applyStockDeltasInTxn(txn, stockDeltas);
      }
      if (variantDeltas.isNotEmpty) {
        final vChanged = await _applyVariantStockDeltasInTxn(txn, variantDeltas);
        stockChanged = stockChanged || vChanged;
      }

      await txn.delete('payment_transactions', where: 'orderId = ?', whereArgs: [id]);
      await txn.delete('order_items', where: 'orderId = ?', whereArgs: [id]);
      await txn.delete('orders', where: 'id = ?', whereArgs: [id]);
    });
    DataSyncBus.instance.notify(DataDomain.orders);
    DataSyncBus.instance.notify(DataDomain.payments);
    if (stockChanged) {
      DataSyncBus.instance.notify(DataDomain.products);
    }
  }

  @override
  Future<void> updatePaymentStatus(
    String orderId,
    String status,
    double paidAmount,
  ) async {
    final db = await dbHelper.database;
    bool addedPayment = false;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'orders',
        columns: ['paidAmount', 'customerId', 'currency', 'orderNumber'],
        where: 'id = ?',
        whereArgs: [orderId],
        limit: 1,
      );

      double prevPaid = 0.0;
      String? customerId;
      String currency = AppConstants.currencyYer;
      String? orderNumber;
      if (existing.isNotEmpty) {
        prevPaid = (existing.first['paidAmount'] as num?)?.toDouble() ?? 0.0;
        customerId = existing.first['customerId'] as String?;
        currency =
            (existing.first['currency'] as String?) ?? AppConstants.currencyYer;
        orderNumber = existing.first['orderNumber'] as String?;
      }

      await txn.update(
        'orders',
        {
          'paymentStatus': status,
          'paidAmount': paidAmount,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      final delta = paidAmount - prevPaid;
      if (delta > 0.0001 || delta < -0.0001) {
        addedPayment = true;
        await txn.insert('payment_transactions', {
          'id': const Uuid().v4(),
          'orderId': orderId,
          'customerId': customerId,
          'amount': delta,
          'currency': currency,
          'paymentMethod': AppConstants.paymentMethodCash,
          'paidAt': DateTime.now().toIso8601String(),
          'notes': orderNumber,
        });
      }
    });
    DataSyncBus.instance.notify(DataDomain.orders);
    if (addedPayment) {
      DataSyncBus.instance.notify(DataDomain.payments);
    }
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
    DataSyncBus.instance.notify(DataDomain.orders);
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
    return _hydrateOrders(db, orderMaps);
  }
}
