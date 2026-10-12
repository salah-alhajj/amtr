import 'package:flutter/foundation.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';
import '../../domain/entities/dashboard_stats.dart';

class DashboardController extends ChangeNotifier {
  final OrderRepository orderRepo;
  final ShipmentRepository shipmentRepo;
  final CustomerRepository customerRepo;
  final CurrencyService currencyService;

  bool _isLoading = false;
  DashboardStats _stats = DashboardStats.empty();
  List<IndividualOrder> _recentOrders = [];
  List<ConsolidatedShipment> _activeShipments = [];

  DashboardController({
    required this.orderRepo,
    required this.shipmentRepo,
    required this.customerRepo,
    CurrencyService? currency,
  }) : currencyService = currency ?? CurrencyService.instance;

  bool get isLoading => _isLoading;
  DashboardStats get stats => _stats;
  List<IndividualOrder> get recentOrders => _recentOrders;
  List<ConsolidatedShipment> get activeShipments => _activeShipments;

  Future<void> loadDashboardData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final orders = await orderRepo.getAllOrders();
      final shipments = await shipmentRepo.getAllShipments();
      final customers = await customerRepo.getAllCustomers();

      double totalDebtsYer = 0.0;
      double collectedCapitalYer = 0.0;
      double remainingCapitalYer = 0.0;
      double totalProfitYer = 0.0;
      int debtorsCount = 0;
      int pendingOrdersCount = 0;

      final Set<String> debtorCustomerIds = {};

      for (final order in orders) {
        // حساب المبالغ بالعملة الأساسية (ريال يمني)
        final sellPriceYer = currencyService.toBaseYer(order.totalSellPrice, order.currency);
        final costPriceYer = currencyService.toBaseYer(order.totalCostPrice, order.currency);
        final paidYer = currencyService.toBaseYer(order.paidAmount, order.currency);

        final debtYer = (sellPriceYer > paidYer) ? (sellPriceYer - paidYer) : 0.0;
        totalDebtsYer += debtYer;
        collectedCapitalYer += paidYer;
        remainingCapitalYer += costPriceYer;

        if (debtYer > 0) {
          if (order.customerId != null) {
            debtorCustomerIds.add(order.customerId!);
          } else {
            debtorsCount++;
          }
        }

        if (order.orderStatus != AppConstants.orderStatusDelivered) {
          pendingOrdersCount++;
        }
      }

      debtorsCount += debtorCustomerIds.length;

      // حساب صافي الأرباح من الشحنات المجمعة
      for (final shipment in shipments) {
        totalProfitYer += shipment.calculateNetProfitInYer(currencyService);
      }

      // حساب صافي الأرباح من الطلبات المستقلة غير الملحقة بشحنة
      for (final order in orders.where((o) => o.shipmentId == null || o.shipmentId!.isEmpty)) {
        final sellYer = currencyService.toBaseYer(order.totalSellPrice, order.currency);
        final costYer = currencyService.toBaseYer(order.totalCostPrice, order.currency);
        totalProfitYer += (sellYer - costYer);
      }

      final totalCapitalYer = collectedCapitalYer + remainingCapitalYer;

      _stats = DashboardStats(
        totalDebtsInYer: totalDebtsYer,
        collectedCapitalInYer: collectedCapitalYer,
        remainingCapitalInYer: remainingCapitalYer,
        totalCapitalInYer: totalCapitalYer,
        netProfitInYer: totalProfitYer,
        totalOrdersCount: orders.length,
        pendingOrdersCount: pendingOrdersCount,
        activeShipmentsCount: shipments.where((s) => s.status != AppConstants.shipmentDistribution).length,
        totalCustomersCount: customers.length,
        debtorsCount: debtorsCount,
      );

      _recentOrders = orders.take(5).toList();
      _activeShipments = shipments
          .where((s) => s.status != AppConstants.shipmentDistribution)
          .take(3)
          .toList();
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
