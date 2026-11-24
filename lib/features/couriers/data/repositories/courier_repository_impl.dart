import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/courier.dart';
import '../../../../models/courier_settlement.dart';
import '../../../../models/expense.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';

/// ملخص العهدة المالية الحالية لمندوب توصيل (بالريال اليمني YER)
class CourierCustodySummary {
  final Courier courier;
  final int activeOrdersCount;
  final int deliveredUnsettledCount;
  final int returnedUnsettledCount;
  final double expectedCollectYer;
  final double collectedCashYer;
  final double deliveryFeesYer;
  final double returnFeesYer;
  final double netDueFromCourierYer;

  const CourierCustodySummary({
    required this.courier,
    this.activeOrdersCount = 0,
    this.deliveredUnsettledCount = 0,
    this.returnedUnsettledCount = 0,
    this.expectedCollectYer = 0.0,
    this.collectedCashYer = 0.0,
    this.deliveryFeesYer = 0.0,
    this.returnFeesYer = 0.0,
    this.netDueFromCourierYer = 0.0,
  });

  double get totalFeesYer => deliveryFeesYer + returnFeesYer;
  int get settleableOrdersCount =>
      deliveredUnsettledCount + returnedUnsettledCount;
}

/// مستودع إدارة مندوبي التوصيل وعهدة التحصيل النقدي (COD) والمرتجعات والتسويات
class CourierRepositoryImpl {
  final AppDatabase _dbHelper;
  static const String _courierCodNotePrefix = 'courier_cod:';

  CourierRepositoryImpl({AppDatabase? db})
      : _dbHelper = db ?? AppDatabase.instance;

  /// تجميع بنود الطلبات باستعلام واحد لتفادي مشكلة N+1
  Future<List<IndividualOrder>> _hydrateOrders(
    DatabaseExecutor db,
    List<Map<String, dynamic>> orderMaps,
  ) async {
    if (orderMaps.isEmpty) return [];
    final orderIds = orderMaps.map((m) => m['id'] as String).toList();
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final itemMaps = await db.rawQuery(
      'SELECT * FROM order_items WHERE orderId IN ($placeholders)',
      orderIds,
    );

    final itemsByOrder = <String, List<OrderItem>>{};
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

  /// حساب المبلغ النقدي الفعلي المحصّل بواسطة المندوب لكل طلب مسلّم (بالريال اليمني YER)
  /// يميز بدقة بين الدفعات المسجلة قبل خروج المندوب (العربون أو الدفع المسبق)
  /// وبين التحصيل النقدي الفعلي عند التسليم، مع دعم fallback آمن للسجلات المدرجة مباشرة.
  Future<Map<String, double>> _computeCollectedByCourierYer(
    DatabaseExecutor db,
    List<IndividualOrder> deliveredOrders,
  ) async {
    final result = <String, double>{};
    if (deliveredOrders.isEmpty) return result;

    final cs = CurrencyService.instance;
    final orderIds = deliveredOrders.map((o) => o.id).toList();
    final placeholders = List.filled(orderIds.length, '?').join(',');
    final txRows = await db.rawQuery(
      'SELECT orderId, amount, currency, notes FROM payment_transactions WHERE orderId IN ($placeholders)',
      orderIds,
    );

    final hasAnyTxByOrder = <String, bool>{};
    final courierTxSumYerByOrder = <String, double>{};
    final hasCourierTxByOrder = <String, bool>{};

    for (final row in txRows) {
      final oid = row['orderId'] as String?;
      if (oid == null || oid.isEmpty) continue;
      hasAnyTxByOrder[oid] = true;
      final notes = (row['notes'] as String?) ?? '';
      if (notes.startsWith(_courierCodNotePrefix)) {
        hasCourierTxByOrder[oid] = true;
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
        final currency =
            (row['currency'] as String?) ?? AppConstants.currencyYer;
        courierTxSumYerByOrder[oid] =
            (courierTxSumYerByOrder[oid] ?? 0.0) + cs.toBaseYer(amount, currency);
      }
    }

    for (final order in deliveredOrders) {
      if (hasCourierTxByOrder[order.id] == true) {
        result[order.id] = courierTxSumYerByOrder[order.id] ?? 0.0;
      } else if (hasAnyTxByOrder[order.id] == true) {
        // الطلب كان مدفوعاً قبل تسليمه للمندوب ولم يحصّل المندوب نقداً إضافياً
        result[order.id] = 0.0;
      } else {
        result[order.id] = cs.toBaseYer(order.paidAmount, order.currency);
      }
    }

    return result;
  }

  Future<List<Courier>> getAllCouriers() async {
    final db = await _dbHelper.database;
    final maps = await db.query('couriers', orderBy: 'createdAt DESC');
    return maps.map(Courier.fromMap).toList();
  }

  Future<Courier?> getCourierById(String id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'couriers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Courier.fromMap(maps.first);
  }

  Future<void> saveCourier(Courier courier) async {
    final db = await _dbHelper.database;
    await db.insert(
      'couriers',
      courier.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DataSyncBus.instance.notify(DataDomain.couriers);
  }

  Future<void> deleteCourier(String id) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'courierId': null,
          'courierStatus': AppConstants.courierStatusNone,
          'courierFee': 0.0,
          'isSettledWithCourier': 0,
        },
        where: 'courierId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'courier_settlements',
        where: 'courierId = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'couriers',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
    DataSyncBus.instance.notify(DataDomain.couriers);
    DataSyncBus.instance.notify(DataDomain.orders);
  }

  Future<List<IndividualOrder>> getCourierOrders(
    String courierId, {
    bool unsettledOnly = true,
  }) async {
    final db = await _dbHelper.database;
    final where = unsettledOnly
        ? 'courierId = ? AND isSettledWithCourier = 0'
        : 'courierId = ?';
    final orderMaps = await db.query(
      'orders',
      where: where,
      whereArgs: [courierId],
      orderBy: 'createdAt DESC',
    );
    return _hydrateOrders(db, orderMaps);
  }

  /// الطلبات غير المسلّمة للعميل والجاهزة للإسناد إلى مندوب
  Future<List<IndividualOrder>> getAssignableOrders() async {
    final db = await _dbHelper.database;
    final orderMaps = await db.query(
      'orders',
      where:
          "orderStatus != ? AND (courierId IS NULL OR courierId = '' OR courierStatus = ? OR (courierStatus = ? AND isSettledWithCourier = 1))",
      whereArgs: [
        AppConstants.orderStatusDelivered,
        AppConstants.courierStatusNone,
        AppConstants.courierStatusReturned,
      ],
      orderBy: 'createdAt DESC',
    );
    return _hydrateOrders(db, orderMaps);
  }

  Future<CourierCustodySummary> getCustodySummary(Courier courier) async {
    final db = await _dbHelper.database;
    final unsettledOrders = await getCourierOrders(
      courier.id,
      unsettledOnly: true,
    );
    return _buildCustodySummary(db, courier, unsettledOrders);
  }

  Future<CourierCustodySummary> _buildCustodySummary(
    DatabaseExecutor db,
    Courier courier,
    List<IndividualOrder> unsettledOrders,
  ) async {
    final cs = CurrencyService.instance;
    int activeCount = 0;
    int deliveredCount = 0;
    int returnedCount = 0;
    double expectedCollectYer = 0.0;
    double deliveryFeesYer = 0.0;
    double returnFeesYer = 0.0;
    final deliveredOrders = <IndividualOrder>[];

    for (final order in unsettledOrders) {
      switch (order.courierStatus) {
        case AppConstants.courierStatusAssigned:
          activeCount++;
          expectedCollectYer += cs.toBaseYer(
            order.remainingDebt,
            order.currency,
          );
          break;
        case AppConstants.courierStatusDelivered:
          deliveredCount++;
          deliveredOrders.add(order);
          deliveryFeesYer += cs.toBaseYer(order.courierFee, courier.currency);
          break;
        case AppConstants.courierStatusReturned:
          returnedCount++;
          returnFeesYer += cs.toBaseYer(order.courierFee, courier.currency);
          break;
      }
    }

    final collectedMap = await _computeCollectedByCourierYer(
      db,
      deliveredOrders,
    );
    double collectedCashYer = 0.0;
    for (final value in collectedMap.values) {
      collectedCashYer += value;
    }

    final netDueFromCourierYer =
        collectedCashYer - deliveryFeesYer - returnFeesYer;

    return CourierCustodySummary(
      courier: courier,
      activeOrdersCount: activeCount,
      deliveredUnsettledCount: deliveredCount,
      returnedUnsettledCount: returnedCount,
      expectedCollectYer: expectedCollectYer,
      collectedCashYer: collectedCashYer,
      deliveryFeesYer: deliveryFeesYer,
      returnFeesYer: returnFeesYer,
      netDueFromCourierYer: netDueFromCourierYer,
    );
  }

  Future<List<CourierCustodySummary>> getAllCustodySummaries() async {
    final couriers = await getAllCouriers();
    if (couriers.isEmpty) return [];

    final db = await _dbHelper.database;
    final allUnsettledMaps = await db.query(
      'orders',
      where:
          "courierId IS NOT NULL AND courierId != '' AND isSettledWithCourier = 0",
      orderBy: 'createdAt DESC',
    );
    final allUnsettled = await _hydrateOrders(db, allUnsettledMaps);

    final ordersByCourier = <String, List<IndividualOrder>>{};
    for (final order in allUnsettled) {
      final cid = order.courierId;
      if (cid != null && cid.isNotEmpty) {
        ordersByCourier.putIfAbsent(cid, () => []).add(order);
      }
    }

    final summaries = <CourierCustodySummary>[];
    for (final courier in couriers) {
      final orders = ordersByCourier[courier.id] ?? const [];
      summaries.add(await _buildCustodySummary(db, courier, orders));
    }
    return summaries;
  }

  Future<List<CourierSettlement>> getSettlements(String courierId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'courier_settlements',
      where: 'courierId = ?',
      whereArgs: [courierId],
      orderBy: 'settledAt DESC',
    );
    return maps.map(CourierSettlement.fromMap).toList();
  }

  Future<void> assignOrdersToCourier({
    required String courierId,
    required List<String> orderIds,
    required double defaultFee,
  }) async {
    if (orderIds.isEmpty) return;
    final db = await _dbHelper.database;
    final safeFee = defaultFee < 0 ? 0.0 : defaultFee;

    await db.transaction((txn) async {
      for (final orderId in orderIds) {
        await txn.update(
          'orders',
          {
            'courierId': courierId,
            'courierStatus': AppConstants.courierStatusAssigned,
            'orderStatus': AppConstants.orderStatusInCargo,
            'courierFee': safeFee,
            'isSettledWithCourier': 0,
          },
          where: 'id = ?',
          whereArgs: [orderId],
        );
      }
    });

    DataSyncBus.instance.notify(DataDomain.couriers);
    DataSyncBus.instance.notify(DataDomain.orders);
  }

  Future<void> markOrderDeliveredByCourier({
    required IndividualOrder order,
    required double collectedAmount,
    required double courierFee,
  }) async {
    final db = await _dbHelper.database;
    final nowIso = DateTime.now().toIso8601String();
    final safeCollected = collectedAmount < 0 ? 0.0 : collectedAmount;
    final safeFee = courierFee < 0 ? 0.0 : courierFee;

    await db.transaction((txn) async {
      final existing = await txn.query(
        'orders',
        columns: [
          'paidAmount',
          'paymentStatus',
          'currency',
          'customerId',
          'orderNumber',
          'courierId',
        ],
        where: 'id = ?',
        whereArgs: [order.id],
        limit: 1,
      );

      final prevPaid = existing.isNotEmpty
          ? ((existing.first['paidAmount'] as num?)?.toDouble() ??
              order.paidAmount)
          : order.paidAmount;
      final existingStatus = existing.isNotEmpty
          ? ((existing.first['paymentStatus'] as String?) ??
              order.paymentStatus)
          : order.paymentStatus;
      final currency = existing.isNotEmpty
          ? ((existing.first['currency'] as String?) ?? order.currency)
          : order.currency;
      final customerId = existing.isNotEmpty
          ? (existing.first['customerId'] as String?)
          : order.customerId;
      final orderNumber = existing.isNotEmpty
          ? ((existing.first['orderNumber'] as String?) ?? order.orderNumber)
          : order.orderNumber;
      final courierId = existing.isNotEmpty
          ? ((existing.first['courierId'] as String?) ?? order.courierId)
          : order.courierId;

      final totalSell = order.totalSellPrice;
      final double newPaid;
      if (existingStatus == AppConstants.paymentCod && prevPaid <= 0.0001) {
        newPaid = totalSell > 0
            ? safeCollected.clamp(0.0, totalSell)
            : safeCollected;
      } else {
        final rawPaid = prevPaid + safeCollected;
        newPaid = totalSell > 0 ? rawPaid.clamp(0.0, totalSell) : rawPaid;
      }

      final newlyCollected =
          (newPaid - prevPaid) > 0.0001 ? (newPaid - prevPaid) : 0.0;

      String newPaymentStatus = existingStatus;
      if (totalSell > 0 && newPaid >= totalSell - 0.01) {
        newPaymentStatus = AppConstants.paymentPrepaid;
      } else if (newPaid > 0.0001) {
        newPaymentStatus = AppConstants.paymentPartial;
      }

      await txn.update(
        'orders',
        {
          'courierStatus': AppConstants.courierStatusDelivered,
          'orderStatus': AppConstants.orderStatusDelivered,
          'actualDeliveryDate': nowIso,
          'courierFee': safeFee,
          'paidAmount': newPaid,
          'paymentStatus': newPaymentStatus,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      if (newlyCollected > 0.0001) {
        await txn.insert('payment_transactions', {
          'id': const Uuid().v4(),
          'orderId': order.id,
          'customerId': customerId,
          'amount': newlyCollected,
          'currency': currency,
          'paymentMethod': AppConstants.paymentMethodCash,
          'paidAt': nowIso,
          'notes': '$_courierCodNotePrefix${courierId ?? ''}:$orderNumber',
        });
      }
    });

    DataSyncBus.instance.notify(DataDomain.couriers);
    DataSyncBus.instance.notify(DataDomain.orders);
    DataSyncBus.instance.notify(DataDomain.payments);
  }

  Future<void> markOrderReturnedByCourier({
    required IndividualOrder order,
    required bool restoreStock,
    required double returnFee,
  }) async {
    final db = await _dbHelper.database;
    final safeFee = returnFee < 0 ? 0.0 : returnFee;

    await db.transaction((txn) async {
      await txn.update(
        'orders',
        {
          'courierStatus': AppConstants.courierStatusReturned,
          'courierFee': safeFee,
          'orderStatus': AppConstants.orderStatusPending,
        },
        where: 'id = ?',
        whereArgs: [order.id],
      );

      if (restoreStock) {
        final itemRows = await txn.query(
          'order_items',
          columns: ['productId', 'quantity'],
          where: 'orderId = ?',
          whereArgs: [order.id],
        );

        final qtyByProduct = <String, int>{};
        for (final row in itemRows) {
          final pid = row['productId'] as String?;
          final qty = (row['quantity'] as num?)?.toInt() ?? 0;
          if (pid != null && pid.isNotEmpty && qty > 0) {
            qtyByProduct[pid] = (qtyByProduct[pid] ?? 0) + qty;
          }
        }

        for (final entry in qtyByProduct.entries) {
          final prodRows = await txn.query(
            'products',
            columns: ['stockQuantity', 'trackStock'],
            where: 'id = ?',
            whereArgs: [entry.key],
            limit: 1,
          );
          if (prodRows.isEmpty) continue;
          final trackStock =
              (prodRows.first['trackStock'] as num?)?.toInt() == 1;
          if (!trackStock) continue;

          final currentQty =
              (prodRows.first['stockQuantity'] as num?)?.toInt() ?? 0;
          final updatedQty = (currentQty + entry.value).clamp(0, 999999);
          await txn.update(
            'products',
            {'stockQuantity': updatedQty},
            where: 'id = ?',
            whereArgs: [entry.key],
          );
        }
      }

      final customerId = order.customerId;
      if (customerId != null && customerId.isNotEmpty) {
        await txn.rawUpdate(
          'UPDATE customers SET returnCount = COALESCE(returnCount, 0) + 1 WHERE id = ?',
          [customerId],
        );
      }
    });

    DataSyncBus.instance.notify(DataDomain.couriers);
    DataSyncBus.instance.notify(DataDomain.orders);
    DataSyncBus.instance.notify(DataDomain.products);
    DataSyncBus.instance.notify(DataDomain.customers);
  }

  Future<CourierSettlement> settleCourier({
    required Courier courier,
    String? notes,
  }) async {
    final db = await _dbHelper.database;
    final cs = CurrencyService.instance;
    final now = DateTime.now();

    late CourierSettlement settlement;

    await db.transaction((txn) async {
      final orderMaps = await txn.query(
        'orders',
        where:
            'courierId = ? AND isSettledWithCourier = 0 AND courierStatus IN (?, ?)',
        whereArgs: [
          courier.id,
          AppConstants.courierStatusDelivered,
          AppConstants.courierStatusReturned,
        ],
        orderBy: 'createdAt DESC',
      );

      final settleableOrders = await _hydrateOrders(txn, orderMaps);
      final deliveredOrders = <IndividualOrder>[];
      double deliveryFeesYer = 0.0;
      double returnFeesYer = 0.0;

      for (final order in settleableOrders) {
        if (order.courierStatus == AppConstants.courierStatusDelivered) {
          deliveredOrders.add(order);
          deliveryFeesYer += cs.toBaseYer(order.courierFee, courier.currency);
        } else if (order.courierStatus == AppConstants.courierStatusReturned) {
          returnFeesYer += cs.toBaseYer(order.courierFee, courier.currency);
        }
      }

      final collectedMap = await _computeCollectedByCourierYer(
        txn,
        deliveredOrders,
      );
      double collectedCashYer = 0.0;
      for (final value in collectedMap.values) {
        collectedCashYer += value;
      }

      final netRemittedYer =
          collectedCashYer - deliveryFeesYer - returnFeesYer;

      final trimmedNotes =
          (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null;

      settlement = CourierSettlement(
        id: const Uuid().v4(),
        courierId: courier.id,
        orderCount: settleableOrders.length,
        collectedCashYer: collectedCashYer,
        deliveryFeesYer: deliveryFeesYer,
        returnFeesYer: returnFeesYer,
        netRemittedYer: netRemittedYer,
        notes: trimmedNotes,
        settledAt: now,
      );

      if (settleableOrders.isNotEmpty) {
        final ids = settleableOrders.map((o) => o.id).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          'UPDATE orders SET isSettledWithCourier = 1 WHERE id IN ($placeholders)',
          ids,
        );
      }

      await txn.insert('courier_settlements', settlement.toMap());

      final totalFeesYer = deliveryFeesYer + returnFeesYer;
      if (totalFeesYer > 0.0001) {
        final expense = Expense(
          id: const Uuid().v4(),
          title: 'courier_settlement_expense_title'.trParams({
            'name': courier.name,
          }),
          category: 'exp_cat_delivery',
          expenseType: AppConstants.expenseTypeBusiness,
          amount: totalFeesYer,
          currency: AppConstants.currencyYer,
          expenseDate: now,
          notes: trimmedNotes ??
              'courier_settlement_expense_notes'.trParams({
                'count': settleableOrders.length.toString(),
              }),
          createdAt: now,
        );
        await txn.insert('expenses', expense.toMap());
      }
    });

    DataSyncBus.instance.notify(DataDomain.couriers);
    DataSyncBus.instance.notify(DataDomain.orders);
    DataSyncBus.instance.notify(DataDomain.expenses);
    DataSyncBus.instance.notify(DataDomain.payments);

    return settlement;
  }
}
