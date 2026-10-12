import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';
import '../../../../core/widgets/currency_price_display.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../../../../core/utils/yemen_phone_helper.dart';

/// نافذة منبثقة سفلية لعرض تفاصيل ديون وطلبات العميل
class CustomerOrdersSheet extends StatelessWidget {
  final Customer customer;
  final List<IndividualOrder> orders;
  final double totalDebt;
  final String activeCurrency;

  const CustomerOrdersSheet({
    super.key,
    required this.customer,
    required this.orders,
    required this.totalDebt,
    required this.activeCurrency,
  });

  static void show(
    BuildContext context, {
    required Customer customer,
    required List<IndividualOrder> orders,
    required double totalDebt,
    required String activeCurrency,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerOrdersSheet(
        customer: customer,
        orders: orders,
        totalDebt: totalDebt,
        activeCurrency: activeCurrency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.scaffoldBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  if (customer.phone != null)
                    Text(
                      YemenPhoneHelper.formatForDisplay(customer.phone!) ?? customer.phone!,
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppleCard(
            backgroundColor: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceWhite,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'customer_total_outstanding_debt'.i18n(),
                  style: TextStyle(fontSize: 13, color: context.textPrimary),
                ),
                CurrencyPriceDisplay(
                  amount: totalDebt,
                  currency: activeCurrency,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: totalDebt > 0 ? AppColors.statusDanger : AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'customer_orders_history_title'.trParams({'count': orders.length.toString()}),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: orders.isEmpty
                ? EmptyStateView.section(
                    icon: Icons.inventory_2_outlined,
                    title: 'customer_no_orders_recorded'.i18n(),
                    subtitle: 'common_empty'.i18n(),
                  )
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (ctx, idx) {
                      final o = orders[idx];
                      return AppleCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)),
                          );
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${o.orderNumber}',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary),
                                ),
                                Text(
                                  'order_items_and_status_fmt'.trParams({
                                    'count': o.items.length.toString(),
                                    'status': AppConstants.getPaymentStatusLabel(o.paymentStatus),
                                  }),
                                  style: TextStyle(fontSize: 11, color: context.textSecondary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CurrencyPriceDisplay(
                                  amount: o.totalSellPrice,
                                  currency: o.currency,
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                                ),
                                const SizedBox(width: 8),
                                const ForwardChevron(),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
