import '../../../core/constants.dart';
import '../../../core/services/currency_service.dart';
import '../../../models/customer.dart';
import '../../../models/individual_order.dart';
import '../../../models/product.dart';
import '../../orders/data/repositories/order_repository_impl.dart';
import '../../orders/domain/repositories/order_repository.dart';
import '../../products/data/repositories/product_repository_impl.dart';
import '../../products/domain/repositories/product_repository.dart';
import '../data/repositories/customer_repository_impl.dart';
import 'repositories/customer_repository.dart';

/// تذكير ذكي لإعادة طلب منتج استهلاكي لدى عميل حان موعد تجديده
class SmartReorderNudge {
  final Customer customer;
  final IndividualOrder lastOrder;
  final Product product;
  final int daysSinceLastOrder;
  final int cycleDays;

  const SmartReorderNudge({
    required this.customer,
    required this.lastOrder,
    required this.product,
    required this.daysSinceLastOrder,
    required this.cycleDays,
  });

  /// عدد الأيام التي تجاوزت دورة إعادة الطلب المعتادة
  int get overdueDays => daysSinceLastOrder - cycleDays;
}

/// ملخص تقادم مديونية العميل بالريال اليمني وأقدم دين غير مسدد بالأيام
class CustomerDebtAging {
  final double remainingDebtYer;
  final int oldestUnpaidDays;
  final int unpaidOrdersCount;

  const CustomerDebtAging({
    required this.remainingDebtYer,
    required this.oldestUnpaidDays,
    required this.unpaidOrdersCount,
  });

  bool get hasOverdueDebt => remainingDebtYer > 0 && oldestUnpaidDays > 0;
}

/// محرك تذكيرات إعادة الطلب الذكية وتحليل تقادم مديونيات العملاء
class SmartReorderService {
  final ProductRepository _productRepo;
  final OrderRepository _orderRepo;
  final CustomerRepository _customerRepo;
  final CurrencyService _currencyService;

  SmartReorderService({
    ProductRepository? productRepo,
    OrderRepository? orderRepo,
    CustomerRepository? customerRepo,
    CurrencyService? currencyService,
  }) : _productRepo = productRepo ?? ProductRepositoryImpl(),
       _orderRepo = orderRepo ?? OrderRepositoryImpl(),
       _customerRepo = customerRepo ?? CustomerRepositoryImpl(),
       _currencyService = currencyService ?? CurrencyService.instance;

  /// إرجاع العملاء المستحقين لتذكير إعادة الطلب مرتبين من الأكثر تأخراً
  Future<List<SmartReorderNudge>> getDueReorderNudges({
    DateTime? now,
    int limit = 5,
  }) async {
    if (limit <= 0) return const [];
    final referenceNow = now ?? DateTime.now();

    final results = await Future.wait([
      _productRepo.getAllProducts(),
      _orderRepo.getAllOrders(),
      _customerRepo.getAllCustomers(),
    ]);

    final products = results[0] as List<Product>;
    final orders = results[1] as List<IndividualOrder>;
    final customers = results[2] as List<Customer>;

    final Map<String, Product> cycleProductsById = {
      for (final p in products)
        if (p.reorderCycleDays > 0) p.id: p,
    };
    if (cycleProductsById.isEmpty) return const [];

    final Map<String, Customer> customersById = {
      for (final c in customers) c.id: c,
    };

    final Map<String, List<IndividualOrder>> deliveredByCustomer = {};
    final Map<String, List<IndividualOrder>> activeByCustomer = {};

    for (final order in orders) {
      final customerId = order.customerId;
      if (customerId == null || customerId.isEmpty) continue;
      if (!customersById.containsKey(customerId)) continue;
      if (order.courierStatus == AppConstants.courierStatusReturned) continue;

      if (order.orderStatus == AppConstants.orderStatusDelivered) {
        deliveredByCustomer.putIfAbsent(customerId, () => []).add(order);
      } else {
        activeByCustomer.putIfAbsent(customerId, () => []).add(order);
      }
    }

    final List<SmartReorderNudge> nudges = [];

    for (final entry in deliveredByCustomer.entries) {
      final customer = customersById[entry.key];
      if (customer == null) continue;

      final deliveredOrders = List<IndividualOrder>.from(entry.value)
        ..sort((a, b) {
          final aDate = a.actualDeliveryDate ?? a.createdAt;
          final bDate = b.actualDeliveryDate ?? b.createdAt;
          return bDate.compareTo(aDate);
        });

      IndividualOrder? latestCycleOrder;
      List<Product> matchedProducts = const [];

      for (final order in deliveredOrders) {
        final found = <Product>[];
        final seenIds = <String>{};
        for (final item in order.items) {
          final pid = item.productId;
          if (pid == null || pid.isEmpty || seenIds.contains(pid)) continue;
          final product = cycleProductsById[pid];
          if (product != null) {
            seenIds.add(pid);
            found.add(product);
          }
        }
        if (found.isNotEmpty) {
          latestCycleOrder = order;
          matchedProducts = found;
          break;
        }
      }

      if (latestCycleOrder == null || matchedProducts.isEmpty) continue;

      final deliveredDate =
          latestCycleOrder.actualDeliveryDate ?? latestCycleOrder.createdAt;
      final daysSince = referenceNow.difference(deliveredDate).inDays;
      final activeOrders = activeByCustomer[customer.id] ?? const [];

      SmartReorderNudge? bestForCustomer;
      for (final product in matchedProducts) {
        if (daysSince < product.reorderCycleDays) continue;

        final hasNewerActiveOrder = activeOrders.any((activeOrder) {
          if (activeOrder.createdAt.isBefore(deliveredDate)) return false;
          return activeOrder.items.any((it) => it.productId == product.id);
        });
        if (hasNewerActiveOrder) continue;

        final candidate = SmartReorderNudge(
          customer: customer,
          lastOrder: latestCycleOrder,
          product: product,
          daysSinceLastOrder: daysSince,
          cycleDays: product.reorderCycleDays,
        );

        if (bestForCustomer == null ||
            candidate.overdueDays > bestForCustomer.overdueDays) {
          bestForCustomer = candidate;
        }
      }

      if (bestForCustomer != null) {
        nudges.add(bestForCustomer);
      }
    }

    nudges.sort((a, b) {
      final overdueCompare = b.overdueDays.compareTo(a.overdueDays);
      if (overdueCompare != 0) return overdueCompare;
      return b.daysSinceLastOrder.compareTo(a.daysSinceLastOrder);
    });

    if (nudges.length <= limit) return nudges;
    return nudges.sublist(0, limit);
  }

  /// احتساب إجمالي المديونية المتبقية بالريال اليمني وعمر أقدم طلب غير مسدد بالأيام
  CustomerDebtAging computeDebtAging(
    List<IndividualOrder> customerOrders, {
    DateTime? now,
  }) {
    final referenceNow = now ?? DateTime.now();
    double remainingDebtYer = 0.0;
    int unpaidOrdersCount = 0;
    DateTime? earliestUnpaidDate;

    for (final order in customerOrders) {
      if (order.remainingDebt <= 0.001) continue;
      unpaidOrdersCount++;
      remainingDebtYer += _currencyService.toBaseYer(
        order.remainingDebt,
        order.currency,
      );

      final anchorDate = order.debtDueDate ?? order.createdAt;
      if (earliestUnpaidDate == null ||
          anchorDate.isBefore(earliestUnpaidDate)) {
        earliestUnpaidDate = anchorDate;
      }
    }

    if (unpaidOrdersCount == 0 || earliestUnpaidDate == null) {
      return const CustomerDebtAging(
        remainingDebtYer: 0.0,
        oldestUnpaidDays: 0,
        unpaidOrdersCount: 0,
      );
    }

    final diffDays = referenceNow.difference(earliestUnpaidDate).inDays;
    return CustomerDebtAging(
      remainingDebtYer: remainingDebtYer,
      oldestUnpaidDays: diffDays > 0 ? diffDays : 0,
      unpaidOrdersCount: unpaidOrdersCount,
    );
  }
}
