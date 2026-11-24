import '../../../core/constants.dart';
import '../../../core/database/app_database.dart';
import '../../../core/services/currency_service.dart';
import '../../../models/individual_order.dart';
import '../../../models/order_item.dart';

/// ملخص أداء منتج واحد خلال الشهر
class TopProductInsight {
  final String name;
  final int quantity;
  final double totalSalesYer;
  final double estimatedProfitYer;

  const TopProductInsight({
    required this.name,
    required this.quantity,
    required this.totalSalesYer,
    required this.estimatedProfitYer,
  });
}

/// ملخص مشتريات عميل واحد خلال الشهر
class TopCustomerInsight {
  final String name;
  final int ordersCount;
  final double totalSalesYer;

  const TopCustomerInsight({
    required this.name,
    required this.ordersCount,
    required this.totalSalesYer,
  });
}

/// ملخص الإنفاق مع مورد واحد خلال الشهر
class TopSupplierSpend {
  final String supplierId;
  final String name;
  final double totalSpendYer;
  final int entriesCount;

  const TopSupplierSpend({
    required this.supplierId,
    required this.name,
    required this.totalSpendYer,
    required this.entriesCount,
  });
}

/// تقرير الرؤى المالية والتشغيلية لشهر محدد (محسوب بالعملة الأساسية YER)
class MonthlyInsightsReport {
  final int year;
  final int month;
  final double totalSalesYer;
  final double prevMonthSalesYer;
  final double? salesChangePercent;
  final double businessExpensesYer;
  final double personalDrawingsYer;
  final double netProfitYer;
  final int ordersCount;
  final double cashCollectedYer;
  final List<TopProductInsight> topProducts;
  final List<TopCustomerInsight> topCustomers;
  final Map<String, double> expensesByCategory;
  final double shipmentsTransportCostYer;
  final double resaleSalesYer;
  final double resaleProfitYer;
  final double manufacturedSalesYer;
  final double manufacturedProfitYer;
  final double pettyCashExpensesYer;
  final double recurringExpensesYer;
  final double oneTimeExpensesYer;
  final List<TopSupplierSpend> topSuppliers;
  final double totalWasteLossYer;
  final int wasteLogsCount;

  const MonthlyInsightsReport({
    required this.year,
    required this.month,
    required this.totalSalesYer,
    required this.prevMonthSalesYer,
    required this.salesChangePercent,
    required this.businessExpensesYer,
    required this.personalDrawingsYer,
    required this.netProfitYer,
    required this.ordersCount,
    required this.cashCollectedYer,
    required this.topProducts,
    required this.topCustomers,
    required this.expensesByCategory,
    this.shipmentsTransportCostYer = 0.0,
    this.resaleSalesYer = 0.0,
    this.resaleProfitYer = 0.0,
    this.manufacturedSalesYer = 0.0,
    this.manufacturedProfitYer = 0.0,
    this.pettyCashExpensesYer = 0.0,
    this.recurringExpensesYer = 0.0,
    this.oneTimeExpensesYer = 0.0,
    this.topSuppliers = const [],
    this.totalWasteLossYer = 0.0,
    this.wasteLogsCount = 0,
  });
}

/// خدمة حساب ملخص الشهر البسيط من قاعدة البيانات المحلية SQLite
class MonthlyInsightsService {
  static final MonthlyInsightsService instance = MonthlyInsightsService._();
  MonthlyInsightsService._();

  String _monthPrefix(int year, int month) {
    return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}';
  }

  /// توليد تقرير شهر محدد مع مقارنة بمبيعات الشهر السابق
  Future<MonthlyInsightsReport> generateForMonth(int year, int month) async {
    final db = await AppDatabase.instance.database;
    final currencyService = CurrencyService.instance;

    final currentPrefix = _monthPrefix(year, month);
    final prevDate = DateTime(year, month - 1, 1);
    final prevPrefix = _monthPrefix(prevDate.year, prevDate.month);

    // 1. جلب طلبات الشهر المحدد والشهر السابق
    final currentOrderMaps = await db.query(
      'orders',
      where: 'createdAt LIKE ?',
      whereArgs: ['$currentPrefix%'],
    );
    final prevOrderMaps = await db.query(
      'orders',
      where: 'createdAt LIKE ?',
      whereArgs: ['$prevPrefix%'],
    );

    // 2. جلب بنود الطلبات للشهرين دفعة واحدة لتجنب N+1
    final allOrderIds = <String>[
      for (final m in currentOrderMaps) m['id'] as String,
      for (final m in prevOrderMaps) m['id'] as String,
    ];

    final Map<String, List<OrderItem>> itemsByOrderId = {};
    if (allOrderIds.isNotEmpty) {
      // تقسيم الاستعلام إلى دفعات لتفادي حد متغيرات SQLite
      const chunkSize = 400;
      for (int i = 0; i < allOrderIds.length; i += chunkSize) {
        final chunk = allOrderIds.sublist(
          i,
          i + chunkSize > allOrderIds.length ? allOrderIds.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final itemMaps = await db.query(
          'order_items',
          where: 'orderId IN ($placeholders)',
          whereArgs: chunk,
        );
        for (final row in itemMaps) {
          final item = OrderItem.fromMap(row);
          itemsByOrderId.putIfAbsent(item.orderId, () => []).add(item);
        }
      }
    }

    // 3. حساب مبيعات الشهر السابق
    double prevMonthSalesYer = 0.0;
    for (final map in prevOrderMaps) {
      final id = map['id'] as String;
      final order = IndividualOrder.fromMap(
        map,
        items: itemsByOrderId[id] ?? const [],
      );
      prevMonthSalesYer += currencyService.toBaseYer(
        order.totalSellPrice,
        order.currency,
      );
    }

    // 4. جلب أسماء العملاء الاحتياطية عند عدم حفظ customerName مباشرة في الطلب
    final Map<String, String> customerNamesById = {};
    final customerIdsToLookup = currentOrderMaps
        .where((m) =>
            (m['customerName'] as String?)?.trim().isEmpty != false &&
            (m['customerId'] as String?)?.isNotEmpty == true)
        .map((m) => m['customerId'] as String)
        .toSet()
        .toList();
    if (customerIdsToLookup.isNotEmpty) {
      final placeholders =
          List.filled(customerIdsToLookup.length, '?').join(',');
      final customerRows = await db.query(
        'customers',
        columns: ['id', 'name'],
        where: 'id IN ($placeholders)',
        whereArgs: customerIdsToLookup,
      );
      for (final c in customerRows) {
        final cid = c['id'] as String?;
        final cname = (c['name'] as String?)?.trim();
        if (cid != null && cname != null && cname.isNotEmpty) {
          customerNamesById[cid] = cname;
        }
      }
    }

    // 4.5 جلب تصنيف المنتجات (بيع وشراء مقابل تصنيع وإنتاج) للبنود المرتبطة بالكتالوج
    final Map<String, String> productTypeById = {};
    final Map<String, String> productNameById = {};
    final productIdsToLookup = <String>{};
    for (final m in currentOrderMaps) {
      final id = m['id'] as String;
      for (final item in itemsByOrderId[id] ?? const <OrderItem>[]) {
        final pid = item.productId?.trim();
        if (pid != null && pid.isNotEmpty) {
          productIdsToLookup.add(pid);
        }
      }
    }
    if (productIdsToLookup.isNotEmpty) {
      final pidList = productIdsToLookup.toList();
      const chunkSize = 400;
      for (int i = 0; i < pidList.length; i += chunkSize) {
        final chunk = pidList.sublist(
          i,
          i + chunkSize > pidList.length ? pidList.length : i + chunkSize,
        );
        final placeholders = List.filled(chunk.length, '?').join(',');
        final prodRows = await db.query(
          'products',
          columns: ['id', 'name', 'productType'],
          where: 'id IN ($placeholders)',
          whereArgs: chunk,
        );
        for (final row in prodRows) {
          final pid = row['id'] as String?;
          if (pid == null || pid.isEmpty) continue;
          final pType =
              (row['productType'] as String?) ?? AppConstants.productTypeResale;
          final pName = (row['name'] as String?)?.trim() ?? '';
          productTypeById[pid] = pType;
          if (pName.isNotEmpty) {
            productNameById[pid] = pName;
          }
        }
      }
    }

    // 5. حساب مبيعات الشهر الحالي وأرباحه وأعلى المنتجات وأعلى العملاء
    double totalSalesYer = 0.0;
    double ordersProfitYer = 0.0;
    double resaleSalesYer = 0.0;
    double resaleProfitYer = 0.0;
    double manufacturedSalesYer = 0.0;
    double manufacturedProfitYer = 0.0;

    final Map<String, _ProductAccumulator> productMap = {};
    final Map<String, _CustomerAccumulator> customerMap = {};

    for (final map in currentOrderMaps) {
      final id = map['id'] as String;
      final items = itemsByOrderId[id] ?? const [];
      final order = IndividualOrder.fromMap(map, items: items);

      final orderSalesYer = currencyService.toBaseYer(
        order.totalSellPrice,
        order.currency,
      );
      final orderCostYer = currencyService.toBaseYer(
        order.totalCostPrice,
        order.currency,
      );
      totalSalesYer += orderSalesYer;
      ordersProfitYer += (orderSalesYer - orderCostYer);

      // تجميع المنتجات وفصل البيع والشراء عن التصنيع والإنتاج
      for (final item in items) {
        final cleanName = item.name.trim();
        final pid = item.productId?.trim();
        final hasProductId = pid != null && pid.isNotEmpty;
        if (!hasProductId && cleanName.isEmpty) continue;

        final itemSellYer = item.totalSell != null
            ? currencyService.toBaseYer(item.totalSell!, item.currency)
            : 0.0;
        final itemCostYer = currencyService.toBaseYer(
          item.totalCost,
          item.currency,
        );
        final itemProfitYer =
            item.totalSell != null ? (itemSellYer - itemCostYer) : 0.0;

        final groupKey = hasProductId ? pid : cleanName;
        final displayName = (hasProductId ? productNameById[pid] : null) ??
            (cleanName.isNotEmpty ? cleanName : pid!);

        final acc = productMap.putIfAbsent(
          groupKey,
          () => _ProductAccumulator(displayName),
        );
        acc.quantity += item.quantity;
        acc.totalSalesYer += itemSellYer;
        acc.estimatedProfitYer += itemProfitYer;

        if (hasProductId && productTypeById.containsKey(pid)) {
          if (productTypeById[pid] == AppConstants.productTypeManufactured) {
            manufacturedSalesYer += itemSellYer;
            manufacturedProfitYer += itemProfitYer;
          } else {
            resaleSalesYer += itemSellYer;
            resaleProfitYer += itemProfitYer;
          }
        }
      }

      // تجميع العملاء
      String resolvedCustomerName = (order.customerName ?? '').trim();
      if (resolvedCustomerName.isEmpty && order.customerId != null) {
        resolvedCustomerName = customerNamesById[order.customerId!] ?? '';
      }
      if (resolvedCustomerName.isNotEmpty) {
        final cAcc = customerMap.putIfAbsent(
          resolvedCustomerName,
          () => _CustomerAccumulator(resolvedCustomerName),
        );
        cAcc.ordersCount += 1;
        cAcc.totalSalesYer += orderSalesYer;
      }
    }

    final topProducts = productMap.values
        .map(
          (e) => TopProductInsight(
            name: e.name,
            quantity: e.quantity,
            totalSalesYer: e.totalSalesYer,
            estimatedProfitYer: e.estimatedProfitYer,
          ),
        )
        .toList()
      ..sort((a, b) {
        final cmp = b.totalSalesYer.compareTo(a.totalSalesYer);
        return cmp != 0 ? cmp : b.quantity.compareTo(a.quantity);
      });

    final topCustomers = customerMap.values
        .map(
          (e) => TopCustomerInsight(
            name: e.name,
            ordersCount: e.ordersCount,
            totalSalesYer: e.totalSalesYer,
          ),
        )
        .toList()
      ..sort((a, b) {
        final cmp = b.totalSalesYer.compareTo(a.totalSalesYer);
        return cmp != 0 ? cmp : b.ordersCount.compareTo(a.ordersCount);
      });

    // 6. حساب مصاريف الشهر (فصل مصاريف المشروع عن المسحوبات الشخصية + النثريات والدورية والموردين)
    final expenseMaps = await db.query(
      'expenses',
      where: 'expenseDate LIKE ?',
      whereArgs: ['$currentPrefix%'],
    );

    double businessExpensesYer = 0.0;
    double personalDrawingsYer = 0.0;
    double pettyCashExpensesYer = 0.0;
    double recurringExpensesYer = 0.0;
    double oneTimeExpensesYer = 0.0;
    final Map<String, double> expensesByCategory = {};
    final Map<String, _SupplierSpendAccumulator> supplierSpendMap = {};

    for (final row in expenseMaps) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      final currency =
          (row['currency'] as String?) ?? AppConstants.currencyYer;
      final amountYer = currencyService.toBaseYer(amount, currency);
      final expenseType =
          (row['expenseType'] as String?) ?? AppConstants.expenseTypeBusiness;

      if (expenseType == AppConstants.expenseTypePersonal) {
        personalDrawingsYer += amountYer;
      } else {
        businessExpensesYer += amountYer;
        final category = ((row['category'] as String?) ?? '').trim();
        final catKey = category.isEmpty ? 'exp_cat_other' : category;
        expensesByCategory[catKey] =
            (expensesByCategory[catKey] ?? 0.0) + amountYer;

        final isPettyCash = (row['isPettyCash'] as num?)?.toInt() == 1;
        if (isPettyCash) {
          pettyCashExpensesYer += amountYer;
        }
        final recurrence = (row['recurrence'] as String?) ??
            AppConstants.expenseRecurrenceOnce;
        final parentRuleId = (row['parentRuleId'] as String?)?.trim();
        final isRecurringEntry =
            recurrence != AppConstants.expenseRecurrenceOnce ||
                (parentRuleId != null && parentRuleId.isNotEmpty);
        if (isRecurringEntry) {
          recurringExpensesYer += amountYer;
        } else {
          oneTimeExpensesYer += amountYer;
        }

        final supplierId = (row['supplierId'] as String?)?.trim();
        if (supplierId != null && supplierId.isNotEmpty) {
          final sAcc = supplierSpendMap.putIfAbsent(
            supplierId,
            () => _SupplierSpendAccumulator(supplierId),
          );
          sAcc.totalSpendYer += amountYer;
          sAcc.entriesCount += 1;
        }
      }
    }

    // 6.5 جلب أسماء الموردين الأكثر تعاملاً
    final List<TopSupplierSpend> topSuppliers = [];
    if (supplierSpendMap.isNotEmpty) {
      final supplierIds = supplierSpendMap.keys.toList();
      final placeholders = List.filled(supplierIds.length, '?').join(',');
      final supplierRows = await db.query(
        'suppliers',
        columns: ['id', 'name'],
        where: 'id IN ($placeholders)',
        whereArgs: supplierIds,
      );
      final Map<String, String> supplierNamesById = {};
      for (final s in supplierRows) {
        final sid = s['id'] as String?;
        final sname = (s['name'] as String?)?.trim();
        if (sid != null && sname != null && sname.isNotEmpty) {
          supplierNamesById[sid] = sname;
        }
      }
      for (final acc in supplierSpendMap.values) {
        final name = supplierNamesById[acc.supplierId];
        if (name == null || name.isEmpty) continue;
        topSuppliers.add(
          TopSupplierSpend(
            supplierId: acc.supplierId,
            name: name,
            totalSpendYer: acc.totalSpendYer,
            entriesCount: acc.entriesCount,
          ),
        );
      }
      topSuppliers.sort((a, b) {
        final cmp = b.totalSpendYer.compareTo(a.totalSpendYer);
        return cmp != 0 ? cmp : b.entriesCount.compareTo(a.entriesCount);
      });
    }

    // 6.8 حساب تكاليف نقل الشحنات المنشأة خلال الشهر (لمطابقة صافي الربح مع لوحة التحكم)
    final shipmentMaps = await db.query(
      'shipments',
      columns: ['transportCost', 'transportCostCurrency'],
      where: 'createdAt LIKE ?',
      whereArgs: ['$currentPrefix%'],
    );
    double shipmentsTransportCostYer = 0.0;
    for (final row in shipmentMaps) {
      final transportCost = (row['transportCost'] as num?)?.toDouble() ?? 0.0;
      final transportCurrency =
          (row['transportCostCurrency'] as String?) ?? AppConstants.currencyYer;
      if (transportCost > 0) {
        shipmentsTransportCostYer += currencyService.toBaseYer(
          transportCost,
          transportCurrency,
        );
      }
    }

    // 7. حساب النقد المحصل الفعلي من جدول حركات الدفع
    final paymentMaps = await db.query(
      'payment_transactions',
      where: 'paidAt LIKE ?',
      whereArgs: ['$currentPrefix%'],
    );
    double cashCollectedYer = 0.0;
    for (final row in paymentMaps) {
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      final currency =
          (row['currency'] as String?) ?? AppConstants.currencyYer;
      cashCollectedYer += currencyService.toBaseYer(amount, currency);
    }

    // 8. صافي الربح التشغيلي = ربح طلبات الشهر ناقص مصاريف المشروع وتكلفة نقل الشحنات (دون خصم المسحوبات الشخصية)
    final double netProfitYer =
        ordersProfitYer - businessExpensesYer - shipmentsTransportCostYer;

    // 8.5 جلب سجلات الهالك والتالف للشهر
    final wasteMaps = await db.query(
      'waste_logs',
      columns: ['estimatedLossYer'],
      where: 'loggedAt LIKE ?',
      whereArgs: ['$currentPrefix%'],
    );
    double totalWasteLossYer = 0.0;
    for (final row in wasteMaps) {
      totalWasteLossYer +=
          (row['estimatedLossYer'] as num?)?.toDouble() ?? 0.0;
    }
    final int wasteLogsCount = wasteMaps.length;

    // 9. نسبة التغير عن الشهر السابق
    final double? salesChangePercent = prevMonthSalesYer > 0
        ? ((totalSalesYer - prevMonthSalesYer) / prevMonthSalesYer) * 100.0
        : null;

    return MonthlyInsightsReport(
      year: year,
      month: month,
      totalSalesYer: totalSalesYer,
      prevMonthSalesYer: prevMonthSalesYer,
      salesChangePercent: salesChangePercent,
      businessExpensesYer: businessExpensesYer,
      personalDrawingsYer: personalDrawingsYer,
      netProfitYer: netProfitYer,
      ordersCount: currentOrderMaps.length,
      cashCollectedYer: cashCollectedYer,
      topProducts: topProducts.take(5).toList(),
      topCustomers: topCustomers.take(5).toList(),
      expensesByCategory: expensesByCategory,
      shipmentsTransportCostYer: shipmentsTransportCostYer,
      resaleSalesYer: resaleSalesYer,
      resaleProfitYer: resaleProfitYer,
      manufacturedSalesYer: manufacturedSalesYer,
      manufacturedProfitYer: manufacturedProfitYer,
      pettyCashExpensesYer: pettyCashExpensesYer,
      recurringExpensesYer: recurringExpensesYer,
      oneTimeExpensesYer: oneTimeExpensesYer,
      topSuppliers: topSuppliers.take(5).toList(),
      totalWasteLossYer: totalWasteLossYer,
      wasteLogsCount: wasteLogsCount,
    );
  }
}

class _ProductAccumulator {
  final String name;
  int quantity = 0;
  double totalSalesYer = 0.0;
  double estimatedProfitYer = 0.0;

  _ProductAccumulator(this.name);
}

class _CustomerAccumulator {
  final String name;
  int ordersCount = 0;
  double totalSalesYer = 0.0;

  _CustomerAccumulator(this.name);
}

class _SupplierSpendAccumulator {
  final String supplierId;
  double totalSpendYer = 0.0;
  int entriesCount = 0;

  _SupplierSpendAccumulator(this.supplierId);
}
