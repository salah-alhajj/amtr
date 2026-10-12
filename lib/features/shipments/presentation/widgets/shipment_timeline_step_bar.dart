import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// شريط الخط الزمني لمحطات الشحنة المجمعة مع أزرار التقدم للمحطة التالية
class ShipmentTimelineStepBar extends StatelessWidget {
  final int currentStep;
  final ValueChanged<String> onAdvanceStatus;

  const ShipmentTimelineStepBar({
    super.key,
    required this.currentStep,
    required this.onAdvanceStatus,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      AppConstants.getShipmentStatusLabel(AppConstants.shipmentDispatched),
      AppConstants.getShipmentStatusLabel(AppConstants.shipmentCheckpoint),
      AppConstants.getShipmentStatusLabel(AppConstants.shipmentDistribution),
      AppConstants.getShipmentStatusLabel(AppConstants.shipmentDelivered),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // أشرطة المحطات الأربع
        Row(
          children: List.generate(steps.length, (idx) {
            final isPassed = idx <= currentStep;
            return Expanded(
              child: Column(
                children: [
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: isPassed ? AppColors.primaryGreen : AppColors.borderSubtle,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[idx],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: idx == currentStep ? FontWeight.bold : FontWeight.normal,
                      color: isPassed ? context.textPrimary : context.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }),
        ),

        const SizedBox(height: 16),

        // أزرار الانتقال للمحطة التالية
        if (currentStep == 0)
          AppOutlinedButton(
            onPressed: () => onAdvanceStatus(AppConstants.shipmentCheckpoint),
            label: 'shipment_action_arrived_hub'.i18n(),
            icon: Icons.pin_drop_outlined,
          )
        else if (currentStep == 1)
          AppPrimaryButton(
            onPressed: () => onAdvanceStatus(AppConstants.shipmentDistribution),
            label: 'shipment_action_ready_distribution'.i18n(),
            icon: Icons.local_shipping_outlined,
          )
        else if (currentStep == 2)
          AppPrimaryButton(
            onPressed: () => onAdvanceStatus(AppConstants.shipmentDelivered),
            label: 'shipment_action_complete_delivery'.i18n(),
            icon: Icons.check_circle_outline_rounded,
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded, size: 18, color: AppColors.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  'shipment_completed_badge'.i18n(),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
