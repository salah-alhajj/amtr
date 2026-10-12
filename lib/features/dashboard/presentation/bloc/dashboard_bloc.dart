import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';
import '../../domain/entities/dashboard_stats.dart';

// --- Events (أحداث البلوك) ---
abstract class DashboardEvent {
  const DashboardEvent();
}

class LoadDashboardData extends DashboardEvent {
  const LoadDashboardData();
}

class ChangeDisplayCurrency extends DashboardEvent {
  final String currencyCode;
  const ChangeDisplayCurrency(this.currencyCode);
}

// --- States (حالات البلوك) ---
abstract class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  final DashboardStats stats;
  final List<IndividualOrder> recentOrders;
  final List<ConsolidatedShipment> activeShipments;
  final String activeCurrency;

  const DashboardLoaded({
    required this.stats,
    required this.recentOrders,
    required this.activeShipments,
    required this.activeCurrency,
  });

  DashboardLoaded copyWith({
    DashboardStats? stats,
    List<IndividualOrder>? recentOrders,
    List<ConsolidatedShipment>? activeShipments,
    String? activeCurrency,
  }) {
    return DashboardLoaded(
      stats: stats ?? this.stats,
      recentOrders: recentOrders ?? this.recentOrders,
      activeShipments: activeShipments ?? this.activeShipments,
      activeCurrency: activeCurrency ?? this.activeCurrency,
    );
  }
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
}

// --- BLoC (متحكم إدارة الحالة ببلوك نقي دون أي مولد كود) ---
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  final OrderRepository orderRepo;
  final ShipmentRepository shipmentRepo;
  final CustomerRepository customerRepo;
  final CurrencyService currencyService;

  DashboardBloc({
    required this.orderRepo,
    required this.shipmentRepo,
    required this.customerRepo,
    CurrencyService? currency,
  })  : currencyService = currency ?? CurrencyService.instance,
        super(const DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<ChangeDisplayCurrency>(_onChangeDisplayCurrency);
  }

  Future<void> _onLoadDashboardData(
    LoadDashboardData event,
    Emitter<DashboardState> emit,
  ) async {
    emit(const DashboardLoading());

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

      for (final shipment in shipments) {
        totalProfitYer += shipment.calculateNetProfitInYer(currencyService);
      }

      for (final order in orders.where((o) => o.shipmentId == null || o.shipmentId!.isEmpty)) {
        final sellYer = currencyService.toBaseYer(order.totalSellPrice, order.currency);
        final costYer = currencyService.toBaseYer(order.totalCostPrice, order.currency);
        totalProfitYer += (sellYer - costYer);
      }

      final totalCapitalYer = collectedCapitalYer + remainingCapitalYer;

      final stats = DashboardStats(
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

      final recentOrders = orders.take(5).toList();
      final activeShipments = shipments
          .where((s) => s.status != AppConstants.shipmentDistribution)
          .take(3)
          .toList();

      emit(DashboardLoaded(
        stats: stats,
        recentOrders: recentOrders,
        activeShipments: activeShipments,
        activeCurrency: currencyService.activeDisplayCurrency,
      ));
    } catch (e) {
      emit(DashboardError('فشل تحميل بيانات لوحة التحكم: $e'));
    }
  }

  void _onChangeDisplayCurrency(
    ChangeDisplayCurrency event,
    Emitter<DashboardState> emit,
  ) {
    currencyService.setDisplayCurrency(event.currencyCode);
    if (state is DashboardLoaded) {
      final current = state as DashboardLoaded;
      emit(current.copyWith(activeCurrency: event.currencyCode));
    }
  }
}
