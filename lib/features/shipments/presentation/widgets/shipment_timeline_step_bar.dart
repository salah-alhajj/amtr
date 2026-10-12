import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';

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
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // أشرطة المحطات الثلاث
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

        if (currentStep < 2) ...[
          const SizedBox(height: 16),
          // أزرار الانتقال للمحطة التالية (السهم دائماً يشير لليسار في الواجهات العربية ←)
          if (currentStep < 1)
            OutlinedButton(
              onPressed: () => onAdvanceStatus(AppConstants.shipmentCheckpoint),
              child: Text('shipment_action_arrived_hub'.i18n(), style: const TextStyle(fontSize: 12)),
            ),
          if (currentStep == 1)
            ElevatedButton(
              onPressed: () => onAdvanceStatus(AppConstants.shipmentDistribution),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
              child: Text('shipment_action_ready_distribution'.i18n(), style: const TextStyle(fontSize: 12)),
            ),
        ],
      ],
    );
  }
}
