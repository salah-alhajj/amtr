import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_card.dart';
import '../widgets/quick_order_sheet.dart';
import 'add_edit_order_screen.dart';
import 'order_details_screen.dart';
import '../../../../models/individual_order.dart';
import '../../../couriers/presentation/screens/couriers_list_screen.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';
import '../../../whatsapp/presentation/widgets/whatsapp_template_sheet.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateOrder(BuildContext context) async {
    final ordersBloc = context.read<OrdersBloc>();
    final bool? res;
    if (PreferencesService.instance.isProductiveFamilyMode) {
      res = await QuickOrderSheet.show(context);
    } else {
      res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AddEditOrderScreen()),
      );
    }
    if (res == true && mounted) {
      ordersBloc.add(const LoadOrders());
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('orders_title'.i18n()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delivery_dining_outlined),
            tooltip: 'couriers_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CouriersListScreen()),
              );
            },
          ),
          BlocBuilder<OrdersBloc, OrdersState>(
            builder: (context, state) {
              final orders = state is OrdersLoaded ? state.displayedOrders : <IndividualOrder>[];
              return IconButton(
                icon: const Icon(Icons.print_outlined),
                tooltip: 'print_orders_list_tooltip'.i18n(),
                onPressed: orders.isEmpty
                    ? null
                    : () {
                        PrintOptionsSheet.show(
                          context,
                          allOrders: orders,
                          title: 'print_default_doc_title'.i18n(),
                        );
                      },
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<OrdersBloc, OrdersState>(
        builder: (context, state) {
          final selectedFilter = state is OrdersLoaded ? state.selectedFilter : 'all';

          return Column(
            children: [
              // حقل البحث السريع المشترك
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'search_orders_hint'.i18n(),
                  onChanged: (val) {
                    context.read<OrdersBloc>().add(SearchOrders(val));
                  },
                  onClear: () {
                    context.read<OrdersBloc>().add(const SearchOrders(''));
                  },
                ),
              ),

              // أشرطة التصفية السريعة (Segmented Pills)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: PreferencesService.instance.isProductiveFamilyMode
                      ? [
                          _buildFilterChip(context, 'status_all'.i18n(), 'all', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_today'.i18n(), 'today', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_new'.i18n(), 'new', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_preparing'.i18n(), 'preparing', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_ready'.i18n(), 'ready', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_occasions'.i18n(), 'occasions', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_debt'.i18n(), 'debt', selectedFilter),
                        ]
                      : [
                          _buildFilterChip(context, 'status_all'.i18n(), 'all', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_debt'.i18n(), 'debt', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_partial'.i18n(), 'partial', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_prepaid'.i18n(), 'prepaid', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_cod'.i18n(), 'cod', selectedFilter),
                          _buildFilterChip(context, 'orders_filter_unassigned'.i18n(), 'unassigned', selectedFilter),
                        ],
                ),
              ),

              const SizedBox(height: 8),

              // شريط السعة الاستيعابية اليومية للمواسم (يظهر فقط عند ضبط سقف > 0)
              _buildDailyOrderCapBanner(context, state),

              // قائمة الطلبات
              Expanded(
                child: _buildBodyContent(context, state),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'orders_fab',
        onPressed: () => _openCreateOrder(context),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text('new_order'.i18n(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context, OrdersState state) {
    if (state is OrdersLoading || state is OrdersInitial) {
      return AppShimmer.list(itemCount: 6);
    }

    if (state is OrdersError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => context.read<OrdersBloc>().add(const LoadOrders()),
      );
    }

    if (state is OrdersLoaded) {
      if (state.displayedOrders.isEmpty) {
        return EmptyStateView(
          icon: Icons.inventory_2_outlined,
          title: 'orders_empty_title'.i18n(),
          subtitle: 'orders_empty_subtitle'.i18n(),
          actionLabel: 'new_order'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () => _openCreateOrder(context),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          context.read<OrdersBloc>().add(const LoadOrders());
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.displayedOrders.length,
          itemBuilder: (context, index) {
            final order = state.displayedOrders[index];
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 200 + (index.clamp(0, 8) * 35)),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: OrderCard(
                order: order,
                nextStatusLabel: () {
                  final next = OrdersBloc.getNextStatus(order.orderStatus);
                  return next != null
                      ? AppConstants.getOrderStatusLabel(next)
                      : null;
                }(),
                onAdvanceStatus: () {
                  final next = OrdersBloc.getNextStatus(order.orderStatus);
                  if (next == null) return null;
                  return () {
                    final previousStatus = order.orderStatus;
                    final ordersBloc = context.read<OrdersBloc>();
                    final messenger = ScaffoldMessenger.of(context);
                    ordersBloc.add(AdvanceOrderStatusEvent(order.id, next));
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        duration: const Duration(seconds: 4),
                        content: Text(
                          'order_stage_updated_undo'.trParams({
                            'stage': AppConstants.getOrderStatusLabel(next),
                          }),
                        ),
                        action: SnackBarAction(
                          label: 'common_undo'.i18n(),
                          onPressed: () {
                            ordersBloc.add(
                              RevertOrderStatusEvent(order.id, previousStatus),
                            );
                          },
                        ),
                      ),
                    );
                  };
                }(),
                onWhatsAppShare: order.orderStatus == AppConstants.orderStatusReady
                    ? () => WhatsAppTemplateSheet.show(
                          context,
                          order: order,
                          initialType: 'ready',
                        )
                    : null,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: order.id)),
                  );
                  if (context.mounted) {
                    context.read<OrdersBloc>().add(const LoadOrders());
                  }
                },
              ),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDailyOrderCapBanner(BuildContext context, OrdersState state) {
    final cap = PreferencesService.instance.getDailyOrderCap();
    if (cap <= 0 || state is! OrdersLoaded) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();
    int todayActiveCount = 0;
    for (final order in state.allOrders) {
      if (order.orderStatus == AppConstants.orderStatusDelivered) continue;
      final targetDate = order.expectedDeliveryDate ?? order.createdAt;
      if (targetDate.year == now.year &&
          targetDate.month == now.month &&
          targetDate.day == now.day) {
        todayActiveCount++;
      }
    }

    final ratio = todayActiveCount / cap;
    final Color barColor;
    if (ratio >= 1.0) {
      barColor = AppColors.statusDanger;
    } else if (ratio >= 0.8) {
      barColor = AppColors.statusWarning;
    } else {
      barColor = AppColors.primaryGreen;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: barColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: barColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 16, color: barColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'orders_daily_cap_title'.i18n(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: barColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$todayActiveCount / $cap',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: barColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: barColor.withValues(alpha: 0.16),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (ratio >= 1.0) ...[
              const SizedBox(height: 4),
              Text(
                'orders_daily_cap_reached'.i18n(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: barColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value, String currentFilter) {
    final isSelected = currentFilter == value;

    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: AppFilterChip(
        label: label,
        isSelected: isSelected,
        onSelected: (_) {
          context.read<OrdersBloc>().add(FilterOrders(value));
        },
      ),
    );
  }
}

