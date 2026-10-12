import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/presentation/screens/customers_list_screen.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../orders/presentation/screens/add_edit_order_screen.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../../../orders/presentation/screens/orders_list_screen.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../search/global_search_delegate.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../shipments/data/repositories/shipment_repository_impl.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';
import '../../../shipments/presentation/screens/add_edit_shipment_screen.dart';
import '../../../shipments/presentation/screens/shipment_details_screen.dart';
import '../../../shipments/presentation/screens/shipments_list_screen.dart';
import '../../../shipments/presentation/widgets/shipment_card.dart';
import '../bloc/dashboard_bloc.dart';
import '../../../navigation/main_navigation_shell.dart';
import '../widgets/currency_selector_bar.dart';
import '../widgets/dashboard_actions_row.dart';
import '../widgets/dashboard_section_header.dart';
import '../widgets/financial_analytics_card.dart';
import '../widgets/net_profit_hero_card.dart';
import '../widgets/stat_card.dart';

class HomeDashboardScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  final ValueChanged<int>? onNavigateTab;

  const HomeDashboardScreen({
    super.key,
    this.onOpenDrawer,
    this.onNavigateTab,
  });

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final OrderRepository _orderRepo = OrderRepositoryImpl();
  final ShipmentRepository _shipmentRepo = ShipmentRepositoryImpl();
  final CustomerRepository _customerRepo = CustomerRepositoryImpl();
  final CurrencyService _currencyService = CurrencyService.instance;

  void _navigateToTab(int index, {Widget? fallbackScreen}) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(index);
    } else {
      final scope = MainNavigationScope.maybeOf(context);
      if (scope != null) {
        scope.navigateTo(index);
      } else if (fallbackScreen != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => fallbackScreen),
        );
      }
    }
  }

  void _openSearch() {
    showSearch(
      context: context,
      delegate: GlobalSearchDelegate(
        orderRepo: _orderRepo,
        shipmentRepo: _shipmentRepo,
        customerRepo: _customerRepo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, size: 24),
          onPressed: () {
            if (widget.onOpenDrawer != null) {
              widget.onOpenDrawer!();
            } else {
              Scaffold.maybeOf(context)?.openDrawer();
            }
          },
          tooltip: 'main_menu'.i18n(),
        ),
        title: Text('app_name'.i18n()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: _openSearch,
            tooltip: 'search_orders_hint'.i18n(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => _navigateToTab(4, fallbackScreen: const SettingsScreen()),
            tooltip: 'nav_settings'.i18n(),
          ),
        ],
      ),
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardLoading || state is DashboardInitial) {
            return AppShimmer.dashboard();
          }

          if (state is DashboardError) {
            return AppErrorStateView(
              message: state.message,
              onRetry: () => context.read<DashboardBloc>().add(const LoadDashboardData()),
            );
          }

          if (state is DashboardLoaded) {
            final stats = state.stats;
            final activeCurrency = state.activeCurrency;

            final debts = _currencyService.fromBaseYer(stats.totalDebtsInYer, activeCurrency);
            final collected = _currencyService.fromBaseYer(stats.collectedCapitalInYer, activeCurrency);
            final remaining = _currencyService.fromBaseYer(stats.remainingCapitalInYer, activeCurrency);
            final totalCapital = _currencyService.fromBaseYer(stats.totalCapitalInYer, activeCurrency);
            final netProfit = _currencyService.fromBaseYer(stats.netProfitInYer, activeCurrency);

            final weeklySales = stats.weeklySalesInYer.map((s) => _currencyService.fromBaseYer(s, activeCurrency)).toList();
            final weeklySalesDayLabels = stats.weeklySalesDayKeys.map((k) => k.i18n()).toList();

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(const LoadDashboardData());
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // مبدل العملات بتصميم iOS
                  CurrencySelectorBar(
                    currencyService: _currencyService,
                    activeCurrency: activeCurrency,
                    onCurrencyChanged: (newCurrency) {
                      context.read<DashboardBloc>().add(ChangeDisplayCurrency(newCurrency));
                    },
                  ),
                  const SizedBox(height: 16),

                  // بطاقة صافي الأرباح الرئيسية
                  NetProfitHeroCard(
                    netProfit: netProfit,
                    activeCurrency: activeCurrency,
                  ),

                  const SizedBox(height: 16),

                  // بطاقة التحليلات والرسوم البيانية المالية المتقدمة
                  FinancialAnalyticsCard(
                    collectedAmount: collected,
                    remainingAmount: remaining,
                    debtAmount: debts,
                    totalRevenue: totalCapital,
                    activeCurrency: activeCurrency,
                    weeklySales: weeklySales,
                    dayLabels: weeklySalesDayLabels,
                  ),

                  const SizedBox(height: 16),

                  // شبكة البطاقات المالية الأربع
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      StatCard(
                        title: 'dashboard_total_debt'.i18n(),
                        amount: debts,
                        currency: activeCurrency,
                        icon: Icons.money_off_rounded,
                        iconColor: AppColors.statusDanger,
                        subtitle: 'dashboard_debtors_count'.trParams({'count': stats.debtorsCount.toString()}),
                        onTap: () => _navigateToTab(3, fallbackScreen: const CustomersListScreen()),
                      ),
                      StatCard(
                        title: 'dashboard_collected_capital'.i18n(),
                        amount: collected,
                        currency: activeCurrency,
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: AppColors.primaryGreen,
                        subtitle: 'dashboard_cash_collected'.i18n(),
                      ),
                      StatCard(
                        title: 'dashboard_remaining_capital'.i18n(),
                        amount: remaining,
                        currency: activeCurrency,
                        icon: Icons.inventory_2_rounded,
                        iconColor: AppColors.primaryBlue,
                        subtitle: 'dashboard_goods_in_market'.i18n(),
                      ),
                      StatCard(
                        title: 'dashboard_total_capital'.i18n(),
                        amount: totalCapital,
                        currency: activeCurrency,
                        icon: Icons.pie_chart_rounded,
                        iconColor: AppColors.vibrantTeal,
                        subtitle: 'dashboard_total_volume'.i18n(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // أزرار الاختصارات السريعة
                  DashboardActionsRow(
                    onNewOrder: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditOrderScreen()),
                      );
                      if (res == true && context.mounted) {
                        context.read<DashboardBloc>().add(const LoadDashboardData());
                      }
                    },
                    onNewShipment: () async {
                      final res = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddEditShipmentScreen()),
                      );
                      if (res == true && context.mounted) {
                        context.read<DashboardBloc>().add(const LoadDashboardData());
                      }
                    },
                    onOpenCustomers: () => _navigateToTab(3, fallbackScreen: const CustomersListScreen()),
                  ),

                  const SizedBox(height: 24),

                  // قسم الشحنات المجمعة النشطة
                  DashboardSectionHeader(
                    title: 'dashboard_active_shipments_title'.i18n(),
                    onAction: () => _navigateToTab(2, fallbackScreen: const ShipmentsListScreen()),
                  ),
                  const SizedBox(height: 8),

                  if (state.activeShipments.isEmpty)
                    AppCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'dashboard_no_active_shipments'.i18n(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    ...state.activeShipments.map((s) => ShipmentCard(
                          shipment: s,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ShipmentDetailsScreen(shipmentId: s.id)),
                            );
                            if (context.mounted) {
                              context.read<DashboardBloc>().add(const LoadDashboardData());
                            }
                          },
                        )),

                  const SizedBox(height: 20),

                  // قسم أحدث الطلبات الفردية
                  DashboardSectionHeader(
                    title: 'dashboard_recent_orders_title'.i18n(),
                    onAction: () => _navigateToTab(1, fallbackScreen: const OrdersListScreen()),
                  ),
                  const SizedBox(height: 8),

                  if (state.recentOrders.isEmpty)
                    AppCard(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'dashboard_no_recent_orders'.i18n(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    )
                  else
                    ...state.recentOrders.map((o) => OrderCard(
                          order: o,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)),
                            );
                            if (context.mounted) {
                              context.read<DashboardBloc>().add(const LoadDashboardData());
                            }
                          },
                        )),

                  const SizedBox(height: 40),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}

