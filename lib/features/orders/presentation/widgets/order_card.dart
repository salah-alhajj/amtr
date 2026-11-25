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
  final VoidCallback? onAdvanceStatus;
  final String? nextStatusLabel;

  const OrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.onWhatsAppShare,
    this.onAdvanceStatus,
    this.nextStatusLabel,
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(
                label: AppConstants.getOrderStatusLabel(order.orderStatus),
                color: AppConstants.getOrderStatusColor(order.orderStatus),
              ),
              AppBadge(
                label: AppConstants.getPaymentStatusLabel(order.paymentStatus),
                color: AppConstants.getPaymentStatusColor(order.paymentStatus),
              ),
              if (order.occasionLabel != null &&
                  order.occasionLabel!.trim().isNotEmpty)
                AppBadge(
                  icon: Icons.celebration_outlined,
                  label: order.occasionLabel!.trim(),
                  color: AppColors.primaryBlue,
                ),
              if (order.isAwaitingDeposit)
                AppBadge(
                  icon: Icons.hourglass_top_rounded,
                  label: 'order_awaiting_deposit_badge'.i18n(),
                  color: AppColors.statusWarning,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 14, color: context.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'order_detailed_items_count'.trParams({'count': order.items.length.toString()}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              ),
              if (order.expectedDeliveryDate != null) ...[
                const SizedBox(width: 8),
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
                  if (onWhatsAppShare != null &&
                      order.orderStatus == AppConstants.orderStatusReady) ...[
                    Material(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: onWhatsAppShare,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const WhatsAppIcon(size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'order_ready_notify_whatsapp'.i18n(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ] else if (onWhatsAppShare != null) ...[
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
          if (onAdvanceStatus != null && nextStatusLabel != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.primaryBlue.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onAdvanceStatus,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'order_next_stage_btn'
                                .trParams({'stage': nextStatusLabel!}),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppColors.primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
