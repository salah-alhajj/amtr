import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';

class OrderCard extends StatelessWidget {
  final IndividualOrder order;
  final VoidCallback onTap;
  final VoidCallback? onWhatsAppShare;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onWhatsAppShare,
  });

  @override
  Widget build(BuildContext context) {
    return AppAnimatedCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        order.customerName ?? 'order_guest_customer'.i18n(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(
                label: AppConstants.getPaymentStatusLabel(order.paymentStatus),
                color: AppConstants.getPaymentStatusColor(order.paymentStatus),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 14, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(
                'order_detailed_items_count'.trParams({'count': order.items.length.toString()}),
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
              const Spacer(),
              if (order.expectedDeliveryDate != null) ...[
                Icon(Icons.event_outlined, size: 14, color: context.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${order.expectedDeliveryDate!.year}/${order.expectedDeliveryDate!.month}/${order.expectedDeliveryDate!.day}',
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: context.borderDivider),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_sell_price_to_customer'.i18n(),
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  if (order.isFullyPriced)
                    CurrencyPriceDisplay(
                      amount: order.totalSellPrice,
                      currency: order.currency,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryGreen,
                      ),
                    )
                  else
                    Text(
                      'order_pricing_pending'.i18n(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.statusWarning,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  if (onWhatsAppShare != null) ...[
                    AppIconButton(
                      customIcon: const WhatsAppIcon(size: 18),
                      color: AppColors.primaryGreen,
                      size: 34,
                      tooltip: 'order_share_whatsapp'.i18n(),
                      onPressed: onWhatsAppShare,
                    ),
                    const SizedBox(width: 6),
                  ],
                  // سهم التقدم لليسار في RTL
                  const ForwardChevron(),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
