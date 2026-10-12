import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization/localization.dart';
import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/design_system.dart';
import '../../models/consolidated_shipment.dart';
import '../../models/customer.dart';
import '../../models/individual_order.dart';
import '../customers/domain/repositories/customer_repository.dart';
import '../customers/presentation/screens/customer_details_screen.dart';
import '../orders/domain/repositories/order_repository.dart';
import '../orders/presentation/screens/order_details_screen.dart';
import '../shipments/domain/repositories/shipment_repository.dart';
import '../shipments/presentation/screens/shipment_details_screen.dart';

class GlobalSearchDelegate extends SearchDelegate {
  final OrderRepository orderRepo;
  final ShipmentRepository shipmentRepo;
  final CustomerRepository customerRepo;

  GlobalSearchDelegate({
    required this.orderRepo,
    required this.shipmentRepo,
    required this.customerRepo,
  }) : super(
         searchFieldLabel: 'search_global_hint'.i18n(),
         searchFieldStyle: const TextStyle(
           fontFamily: 'IBMPlexSansArabic',
           fontSize: 14,
           color: AppColors.textPrimary,
         ),
       );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: context.surfaceCard,
        iconTheme: IconThemeData(color: context.primaryBlue),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: context.textTertiary,
          fontSize: 14,
          fontFamily: 'IBMPlexSansArabic',
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear_rounded, color: context.textSecondary),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    // في واجهة RTL العودة للخلف تكون عبر الأيقونة المعاكسة
    return IconButton(
      icon: BackChevron(size: 18, color: context.primaryBlue),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(
              'search_initial_instruction'.i18n(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final cleanQuery = query.trim();
    final currencyService = CurrencyService.instance;

    return FutureBuilder(
      future: Future.wait([
        customerRepo.searchCustomers(cleanQuery),
        orderRepo.searchOrders(cleanQuery),
        shipmentRepo.searchShipments(cleanQuery),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final customers = (snapshot.data?[0] as List<Customer>?) ?? [];
        final orders = (snapshot.data?[1] as List<IndividualOrder>?) ?? [];
        final shipments =
            (snapshot.data?[2] as List<ConsolidatedShipment>?) ?? [];

        if (customers.isEmpty && orders.isEmpty && shipments.isEmpty) {
          return Center(
            child: Text(
              'search_no_results'.i18n(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (customers.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_customers_header'.trParams({
                  'count': '${customers.length}',
                }),
              ),
              ...customers.map(
                (c) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerDetailsScreen(initialCustomer: c),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        c.name.isNotEmpty ? c.name[0] : 'ع',
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      c.phone ?? 'customer_no_phone'.i18n(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const ForwardChevron(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (orders.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_orders_header'.trParams({'count': '${orders.length}'}),
              ),
              ...orders.map(
                (o) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(orderId: o.id),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${o.orderNumber} - ${o.customerName ?? 'customer_quick_default'.i18n()}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'order_items_and_status_fmt'.trParams({
                                'count': '${o.items.length}',
                                'status': AppConstants.getPaymentStatusLabel(
                                  o.paymentStatus,
                                ),
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          Text(
                            currencyService.formatAmount(
                              o.totalSellPrice,
                              currencyCode: o.currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const ForwardChevron(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (shipments.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_shipments_header'.trParams({
                  'count': '${shipments.length}',
                }),
              ),
              ...shipments.map(
                (s) => AppleCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShipmentDetailsScreen(shipmentId: s.id),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${s.shipmentNumber} - ${s.title}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'shipment_orders_and_status_fmt'.trParams({
                                'count': '${s.orders.length}',
                                'status': AppConstants.getShipmentStatusLabel(
                                  s.status,
                                ),
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.textSecondary,
        ),
      ),
    );
  }
}
