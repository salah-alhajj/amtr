import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/consolidated_shipment.dart';

class ShipmentCard extends StatelessWidget {
  final ConsolidatedShipment shipment;
  final VoidCallback onTap;

  const ShipmentCard({
    super.key,
    required this.shipment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService.instance;
    final activeCurrency = currencyService.activeDisplayCurrency;
    final netProfit = shipment.calculateNetProfitIn(targetCurrency: activeCurrency);
    final isProfitable = netProfit >= 0;

    final currentStep = AppConstants.getShipmentStatusStepIndex(shipment.status);

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
                        color: AppColors.primaryGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${shipment.shipmentNumber}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shipment.title,
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
                label: AppConstants.getShipmentStatusLabel(shipment.status),
                color: currentStep == 2 ? AppColors.primaryGreen : AppColors.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // مؤشر محطات الوصول الثلاث (Apple Style Stepper)
          _buildTimelineSteps(context, currentStep),

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
                    'shipment_card_orders_cost_fmt'.trParams({
                      'count': shipment.orders.length.toString(),
                      'cost': currencyService.formatAmount(shipment.transportCost, currencyCode: shipment.transportCostCurrency),
                    }),
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        'shipment_card_net_profit_prefix'.i18n(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.textSecondary),
                      ),
                      const SizedBox(width: 4),
                      CurrencyPriceDisplay(
                        amount: netProfit,
                        currency: activeCurrency,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isProfitable ? AppColors.primaryGreen : AppColors.statusDanger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const ForwardChevron(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSteps(BuildContext context, int currentStep) {
    final steps = [
      AppConstants.shipmentDispatched,
      AppConstants.shipmentCheckpoint,
      AppConstants.shipmentDistribution,
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentStep;
        final isCurrent = index == currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: isCompleted ? AppColors.primaryGreen : context.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppConstants.getShipmentStatusLabel(steps[index]),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color: isCompleted ? context.textPrimary : context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < steps.length - 1) const SizedBox(width: 4),
            ],
          ),
        );
      }),
    );
  }
}
