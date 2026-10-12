import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';

/// بطاقة تحديد وإلحاق طلب فردي داخل حمولة الشحنة المجمعة
class OrderAssignmentCard extends StatelessWidget {
  final IndividualOrder order;
  final bool isSelected;
  final ValueChanged<bool?> onToggle;

  const OrderAssignmentCard({
    super.key,
    required this.order,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      onTap: () => onToggle(!isSelected),
      child: Row(
        children: [
          Checkbox(
            value: isSelected,
            activeColor: AppColors.primaryGreen,
            onChanged: onToggle,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#${order.orderNumber} - ${order.customerName ?? "customer_quick_default".i18n()}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'order_items_and_status_fmt'.trParams({
                    'count': order.items.length.toString(),
                    'status': AppConstants.getPaymentStatusLabel(order.paymentStatus),
                  }),
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          CurrencyPriceDisplay(
            amount: order.totalSellPrice,
            currency: order.currency,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primaryGreen),
          ),
        ],
      ),
    );
  }
}
