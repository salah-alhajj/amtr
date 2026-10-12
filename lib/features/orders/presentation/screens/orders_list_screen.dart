import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_card.dart';
import 'add_edit_order_screen.dart';
import 'order_details_screen.dart';
import '../../../../models/individual_order.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';

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

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('orders_title'.i18n()),
        actions: [
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
                  children: [
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
        onPressed: () async {
          final ordersBloc = context.read<OrdersBloc>();
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEditOrderScreen()),
          );
          if (res == true) {
            ordersBloc.add(const LoadOrders());
          }
        },
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
          onActionPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEditOrderScreen()),
            );
          },
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

