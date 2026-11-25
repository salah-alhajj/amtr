import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/business/business_mode_cubit.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../cashbox/presentation/screens/cashbox_screen.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../customers/domain/smart_reorder_service.dart';
import '../../../customers/presentation/screens/customers_list_screen.dart';
import '../../../expenses/presentation/screens/expenses_list_screen.dart';
import '../../../manufacturing/presentation/screens/daily_prep_shopping_screen.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../orders/presentation/screens/add_edit_order_screen.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../../../orders/presentation/screens/orders_list_screen.dart';
import '../../../orders/presentation/widgets/order_card.dart';
import '../../../orders/presentation/widgets/quick_order_sheet.dart';
import '../../../products/presentation/screens/products_list_screen.dart';
import '../../../reports/presentation/screens/monthly_report_screen.dart';
import '../../../search/global_search_delegate.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../shipments/data/repositories/shipment_repository_impl.dart';
import '../../../shipments/domain/repositories/shipment_repository.dart';
import '../../../shipments/presentation/screens/add_edit_shipment_screen.dart';
import '../../../shipments/presentation/screens/shipment_details_screen.dart';
import '../../../shipments/presentation/screens/shipments_list_screen.dart';
import '../../../shipments/presentation/widgets/shipment_card.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
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
  final SmartReorderService _smartReorderService = SmartReorderService();

  List<SmartReorderNudge> _reorderNudges = const [];
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadReorderNudges();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (domain == DataDomain.orders ||
          domain == DataDomain.products ||
          domain == DataDomain.customers) {
        _loadReorderNudges();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _loadReorderNudges() async {
    try {
      final nudges = await _smartReorderService.getDueReorderNudges(limit: 3);
      if (!mounted) return;
      setState(() => _reorderNudges = nudges);
    } catch (_) {}
  }

  Future<void> _sendReorderWhatsApp(SmartReorderNudge nudge) async {
    final msg = WhatsAppTemplateEngine.buildSmartReorderNudgeMessage(
      customerName: nudge.customer.name,
      productName: nudge.product.name,
      daysSinceLastOrder: nudge.daysSinceLastOrder,
    );
    try {
      await SharePlus.instance.share(ShareParams(text: msg));
    } catch (_) {}
  }

  void _repeatReorderOrder(SmartReorderNudge nudge) {
    try {
      context.read<OrdersBloc>().add(ReorderEvent(nudge.lastOrder));
      AppToast.showSuccess(
        context,
        'home_smart_reorder_repeat_success'.trParams({
          'customer': nudge.customer.name,
        }),
      );
    } catch (_) {}
  }

  BusinessModeState _readBusinessModeState(BuildContext context) {
    try {
      return context.watch<BusinessModeCubit>().state;
    } catch (_) {
      final prefs = PreferencesService.instance;
      return BusinessModeState(
        businessMode: prefs.getBusinessMode(),
        businessName: prefs.getBusinessName(),
        businessPhone: prefs.getBusinessPhone(),
        businessAddress: prefs.getBusinessAddress(),
        invoiceFooterNote: prefs.getInvoiceFooterNote(),
        defaultCurrency: prefs.getDefaultCurrency(),
        multiCurrencyEnabled: prefs.isMultiCurrencyEnabled(),
        features: prefs.getFeatureFlags(),
      );
    }
  }

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
    final businessState = _readBusinessModeState(context);
    final isProductiveFamily = businessState.isProductiveFamily;
    final multiCurrencyEnabled = businessState.multiCurrencyEnabled;

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
        title: Text(
          businessState.businessName.trim().isNotEmpty
              ? businessState.businessName.trim()
              : 'app_name'.i18n(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MonthlyReportScreen()),
              );
            },
            tooltip: 'monthly_report_title'.i18n(),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, size: 22),
            onPressed: _openSearch,
            tooltip: 'search_orders_hint'.i18n(),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () {
              if (isProductiveFamily) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              } else {
                _navigateToTab(4, fallbackScreen: const SettingsScreen());
              }
            },
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
            final netCashInHand = _currencyService.fromBaseYer(stats.netCashInHandInYer, activeCurrency);
            final remaining = _currencyService.fromBaseYer(stats.remainingCapitalInYer, activeCurrency);
            final totalCapital = _currencyService.fromBaseYer(stats.totalCapitalInYer, activeCurrency);
            final totalExpenses = _currencyService.fromBaseYer(stats.totalExpensesInYer, activeCurrency);
            final netProfit = _currencyService.fromBaseYer(stats.netProfitInYer, activeCurrency);

            final weeklySales = stats.weeklySalesInYer.map((s) => _currencyService.fromBaseYer(s, activeCurrency)).toList();
            final weeklySalesDayLabels = stats.weeklySalesDayKeys.map((k) => k.i18n()).toList();
            final todaySales = weeklySales.isNotEmpty ? weeklySales.last : 0.0;

            return RefreshIndicator(
              onRefresh: () async {
                context.read<DashboardBloc>().add(const LoadDashboardData());
                await _loadReorderNudges();
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  if (multiCurrencyEnabled) ...[
                    // مبدل العملات بتصميم iOS
                    CurrencySelectorBar(
                      currencyService: _currencyService,
                      activeCurrency: activeCurrency,
                      onCurrencyChanged: (newCurrency) {
                        context.read<DashboardBloc>().add(ChangeDisplayCurrency(newCurrency));
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // بطاقة صافي الأرباح الرئيسية
                  NetProfitHeroCard(
                    netProfit: netProfit,
                    activeCurrency: activeCurrency,
                    subtitle: isProductiveFamily ? 'pf_profit_subtitle'.i18n() : null,
                  ),

                  if (stats.todayOrdersCount > 0 || stats.lowStockCount > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (stats.todayOrdersCount > 0)
                          Expanded(
                            child: AppStatusBanner(
                              message: 'dashboard_today_orders_alert'.trParams({
                                'count': stats.todayOrdersCount.toString(),
                              }),
                              icon: Icons.today_rounded,
                              tintColor: AppColors.primaryBlue,
                              onTap: () {
                                try {
                                  context.read<OrdersBloc>().add(const FilterOrders('today'));
                                } catch (_) {}
                                _navigateToTab(
                                  1,
                                  fallbackScreen: const OrdersListScreen(),
                                );
                              },
                            ),
                          ),
                        if (stats.todayOrdersCount > 0 && stats.lowStockCount > 0)
                          const SizedBox(width: 8),
                        if (stats.lowStockCount > 0)
                          Expanded(
                            child: AppStatusBanner(
                              message: 'dashboard_low_stock_alert'.trParams({
                                'count': stats.lowStockCount.toString(),
                              }),
                              icon: Icons.warning_amber_rounded,
                              tintColor: AppColors.statusDanger,
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ProductsListScreen(),
                                  ),
                                );
                                if (context.mounted) {
                                  context
                                      .read<DashboardBloc>()
                                      .add(const LoadDashboardData());
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                  ],

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

                  // شبكة البطاقات الأربع
                  if (isProductiveFamily)
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.22,
                      children: [
                        StatCard(
                          title: 'pf_home_today_sales'.i18n(),
                          amount: todaySales,
                          currency: activeCurrency,
                          icon: Icons.point_of_sale_rounded,
                          iconColor: AppColors.primaryBlue,
                          onTap: () => _navigateToTab(
                            1,
                            fallbackScreen: const OrdersListScreen(),
                          ),
                        ),
                        StatCard(
                          title: 'pf_home_cash_in_hand'.i18n(),
                          amount: netCashInHand,
                          currency: activeCurrency,
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: netCashInHand >= 0
                              ? AppColors.primaryGreen
                              : AppColors.statusDanger,
                          onTap: () => _navigateToTab(
                            3,
                            fallbackScreen: const CashBoxScreen(),
                          ),
                        ),
                        StatCard(
                          title: 'pf_home_business_expenses'.i18n(),
                          amount: totalExpenses,
                          currency: activeCurrency,
                          icon: Icons.receipt_long_rounded,
                          iconColor: AppColors.statusDanger,
                          onTap: () => _navigateToTab(
                            3,
                            fallbackScreen: const CashBoxScreen(),
                          ),
                        ),
                        StatCard(
                          title: 'pf_home_pending_from_customers'.i18n(),
                          amount: debts,
                          currency: activeCurrency,
                          icon: Icons.people_outline_rounded,
                          iconColor: AppColors.statusWarning,
                          subtitle: 'dashboard_debtors_count'.trParams({
                            'count': stats.debtorsCount.toString(),
                          }),
                          onTap: () => _navigateToTab(
                            4,
                            fallbackScreen: const CustomersListScreen(),
                          ),
                        ),
                      ],
                    )
                  else
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.22,
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
                  if (isProductiveFamily)
                    _buildProductiveFamilyShortcuts(context)
                  else
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
                      onOpenCatalog: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                        );
                        if (context.mounted) {
                          context.read<DashboardBloc>().add(const LoadDashboardData());
                        }
                      },
                      onOpenExpenses: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ExpensesListScreen()),
                        );
                        if (context.mounted) {
                          context.read<DashboardBloc>().add(const LoadDashboardData());
                        }
                      },
                    ),

                  const SizedBox(height: 12),

                  if (_reorderNudges.isNotEmpty) ...[
                    _buildSmartReorderCard(context),
                    const SizedBox(height: 12),
                  ],

                  if (businessState.features.dailyPrep) ...[
                    AppCard(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DailyPrepAndShoppingScreen(),
                          ),
                        );
                      },
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.checklist_rtl_rounded,
                              size: 20,
                              color: AppColors.statusWarning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'prep_screen_title'.i18n(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'drawer_prep_shopping_sub'.i18n(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 15,
                            color: context.textSecondary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  AppCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const MonthlyReportScreen(),
                        ),
                      );
                    },
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.vibrantTeal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.bar_chart_rounded,
                            size: 20,
                            color: AppColors.vibrantTeal,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'monthly_report_title'.i18n(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 15,
                          color: context.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  if (businessState.features.shipments) ...[
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
                  ],

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

  Widget _buildSmartReorderCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const accentColor = AppColors.primaryGreen;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.autorenew_rounded,
                  size: 18,
                  color: accentColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'home_smart_reorder_title'.i18n(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(_reorderNudges.length, (index) {
            final nudge = _reorderNudges[index];
            final isLast = index == _reorderNudges.length - 1;
            return Container(
              margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceMuted
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: context.borderDivider,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_smart_reorder_item_fmt'.trParams({
                      'customer': nudge.customer.name,
                      'product': nudge.product.name,
                      'days': nudge.daysSinceLastOrder.toString(),
                    }),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _sendReorderWhatsApp(nudge),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primaryGreen,
                          side: BorderSide(
                            color: AppColors.primaryGreen.withValues(alpha: 0.45),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_rounded,
                              size: 15,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'home_smart_reorder_wa_btn'.i18n(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _repeatReorderOrder(nudge),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          minimumSize: const Size(0, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.replay_rounded, size: 15),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'home_smart_reorder_repeat_btn'.i18n(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProductiveFamilyShortcuts(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildShortcutItem(
            context: context,
            label: 'quick_order_title'.i18n(),
            icon: Icons.bolt_rounded,
            color: AppColors.primaryBlue,
            onTap: () async {
              final res = await QuickOrderSheet.show(context);
              if (res == true && context.mounted) {
                context.read<DashboardBloc>().add(const LoadDashboardData());
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShortcutItem(
            context: context,
            label: 'nav_catalog'.i18n(),
            icon: Icons.storefront_rounded,
            color: AppColors.vibrantTeal,
            onTap: () => _navigateToTab(
              2,
              fallbackScreen: const ProductsListScreen(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShortcutItem(
            context: context,
            label: 'nav_cashbox'.i18n(),
            icon: Icons.account_balance_wallet_rounded,
            color: AppColors.primaryGreen,
            onTap: () => _navigateToTab(
              3,
              fallbackScreen: const CashBoxScreen(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildShortcutItem(
            context: context,
            label: 'nav_customers'.i18n(),
            icon: Icons.people_alt_rounded,
            color: AppColors.deepNavy,
            onTap: () => _navigateToTab(
              4,
              fallbackScreen: const CustomersListScreen(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

