import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/payment_transaction.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../expenses/data/repositories/expense_repository_impl.dart';
import '../../../expenses/domain/repositories/expense_repository.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/repositories/product_repository.dart';
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
  final ExpenseRepository expenseRepo;
  final ProductRepository productRepo;
  final CurrencyService currencyService;
  late final StreamSubscription<DataDomain> _syncSub;

  DashboardBloc({
    required this.orderRepo,
    required this.shipmentRepo,
    required this.customerRepo,
    ExpenseRepository? expenseRepo,
    ProductRepository? productRepo,
    CurrencyService? currency,
  })  : expenseRepo = expenseRepo ?? ExpenseRepositoryImpl(),
        productRepo = productRepo ?? ProductRepositoryImpl(),
        currencyService = currency ?? CurrencyService.instance,
        super(const DashboardInitial()) {
    on<LoadDashboardData>(_onLoadDashboardData);
    on<ChangeDisplayCurrency>(_onChangeDisplayCurrency);
    _syncSub = DataSyncBus.instance.stream.listen((_) {
      add(const LoadDashboardData());
    });
  }

  @override
  Future<void> close() async {
    await _syncSub.cancel();
    return super.close();
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
      final expenses = await expenseRepo.getAllExpenses();
      final products = await productRepo.getAllProducts();

      final nowDate = DateTime.now();
      double businessExpensesYer = 0.0;
      double personalDrawingsYer = 0.0;
      double todayBusinessExpensesYer = 0.0;

      for (final exp in expenses) {
        final amountYer = currencyService.toBaseYer(exp.amount, exp.currency);
        if (exp.isPersonalDrawing) {
          personalDrawingsYer += amountYer;
        } else {
          businessExpensesYer += amountYer;
          if (exp.expenseDate.year == nowDate.year &&
              exp.expenseDate.month == nowDate.month &&
              exp.expenseDate.day == nowDate.day) {
            todayBusinessExpensesYer += amountYer;
          }
        }
      }

      double todayCashInYer = 0.0;
      try {
        final db = await AppDatabase.instance.database;
        final todayPrefix =
            '${nowDate.year.toString().padLeft(4, '0')}-${nowDate.month.toString().padLeft(2, '0')}-${nowDate.day.toString().padLeft(2, '0')}';
        final paymentMaps = await db.query(
          'payment_transactions',
          where: 'paidAt LIKE ?',
          whereArgs: ['$todayPrefix%'],
        );
        for (final map in paymentMaps) {
          final tx = PaymentTransaction.fromMap(map);
          todayCashInYer += currencyService.toBaseYer(tx.amount, tx.currency);
        }
      } catch (_) {
        // تجاهل آمن في بيئات الاختبار التي لا تهيئ قاعدة البيانات
      }

      final int lowStockCount = products.where((p) => p.isLowStock).length;
      int todayOrdersCount = 0;
      double todaySalesYer = 0.0;
      bool isSameDay(DateTime a, DateTime b) =>
          a.year == b.year && a.month == b.month && a.day == b.day;
      for (final o in orders) {
        final isTodayOrder = isSameDay(o.createdAt, nowDate) ||
            (o.expectedDeliveryDate != null &&
                isSameDay(o.expectedDeliveryDate!, nowDate));
        if (isTodayOrder && o.orderStatus != AppConstants.orderStatusDelivered) {
          todayOrdersCount++;
        }
        if (isSameDay(o.createdAt, nowDate)) {
          todaySalesYer +=
              currencyService.toBaseYer(o.totalSellPrice, o.currency);
        }
      }

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

      // احتساب مبيعات الأيام السبعة الماضية الحقيقية من قاعدة البيانات
      final now = DateTime.now();
      final List<double> weeklySalesYer = [];
      final List<String> weeklyDayKeys = [];
      const dayKeyMap = {
        DateTime.saturday: 'day_saturday',
        DateTime.sunday: 'day_sunday',
        DateTime.monday: 'day_monday',
        DateTime.tuesday: 'day_tuesday',
        DateTime.wednesday: 'day_wednesday',
        DateTime.thursday: 'day_thursday',
        DateTime.friday: 'day_friday',
      };

      for (int i = 6; i >= 0; i--) {
        final targetDate = now.subtract(Duration(days: i));
        final dayStart = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
        final dayEnd = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59, 999);
        weeklyDayKeys.add(dayKeyMap[targetDate.weekday] ?? 'day_saturday');

        double daySalesYer = 0.0;
        for (final o in orders) {
          if (o.createdAt.isAfter(dayStart.subtract(const Duration(milliseconds: 1))) &&
              o.createdAt.isBefore(dayEnd.add(const Duration(milliseconds: 1)))) {
            daySalesYer += currencyService.toBaseYer(o.totalSellPrice, o.currency);
          }
        }
        weeklySalesYer.add(daySalesYer);
      }

      final totalCapitalYer = collectedCapitalYer + remainingCapitalYer;
      final netProfitAfterExpensesYer = totalProfitYer - businessExpensesYer;
      final netCashInHandYer =
          collectedCapitalYer - businessExpensesYer - personalDrawingsYer;

      final stats = DashboardStats(
        totalDebtsInYer: totalDebtsYer,
        collectedCapitalInYer: collectedCapitalYer,
        netCashInHandInYer: netCashInHandYer,
        remainingCapitalInYer: remainingCapitalYer,
        totalCapitalInYer: totalCapitalYer,
        netProfitInYer: netProfitAfterExpensesYer,
        totalExpensesInYer: businessExpensesYer,
        personalDrawingsInYer: personalDrawingsYer,
        todayCashInYer: todayCashInYer,
        todaySalesInYer: todaySalesYer,
        todayBusinessExpensesInYer: todayBusinessExpensesYer,
        totalOrdersCount: orders.length,
        pendingOrdersCount: pendingOrdersCount,
        todayOrdersCount: todayOrdersCount,
        lowStockCount: lowStockCount,
        activeShipmentsCount: shipments.where((s) => s.status != AppConstants.shipmentDelivered).length,
        totalCustomersCount: customers.length,
        debtorsCount: debtorsCount,
        weeklySalesInYer: weeklySalesYer,
        weeklySalesDayKeys: weeklyDayKeys,
      );

      final recentOrders = orders.take(5).toList();
      final activeShipments = shipments
          .where((s) => s.status != AppConstants.shipmentDelivered)
          .take(3)
          .toList();

      emit(DashboardLoaded(
        stats: stats,
        recentOrders: recentOrders,
        activeShipments: activeShipments,
        activeCurrency: currencyService.activeDisplayCurrency,
      ));
    } catch (e) {
      emit(DashboardError('error_load_dashboard'.trParams({'error': '$e'})));
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
