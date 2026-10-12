import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';

/// صف أزرار الإجراءات السريعة في لوحة التحكم
class DashboardActionsRow extends StatelessWidget {
  final VoidCallback onNewOrder;
  final VoidCallback onNewShipment;
  final VoidCallback onOpenCustomers;

  const DashboardActionsRow({
    super.key,
    required this.onNewOrder,
    required this.onNewShipment,
    required this.onOpenCustomers,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionShortcut(
            label: 'new_order'.i18n(),
            icon: Icons.add_shopping_cart_rounded,
            color: AppColors.primaryBlue,
            onTap: onNewOrder,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionShortcut(
            label: 'action_new_consolidated_shipment'.i18n(),
            icon: Icons.local_shipping_rounded,
            color: AppColors.primaryGreen,
            onTap: onNewShipment,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildActionShortcut(
            label: 'nav_customers'.i18n(),
            icon: Icons.people_alt_rounded,
            color: AppColors.deepNavy,
            onTap: onOpenCustomers,
          ),
        ),
      ],
    );
  }

  Widget _buildActionShortcut({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppleCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
