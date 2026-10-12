import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';

/// بطاقة ملخص الحسبة المالية وفاتورة الطلب
class OrderFinancialSummaryCard extends StatelessWidget {
  final IndividualOrder order;
  final VoidCallback onUpdatePayment;

  const OrderFinancialSummaryCard({
    super.key,
    required this.order,
    required this.onUpdatePayment,
  });

  @override
  Widget build(BuildContext context) {
    return AppleCard(
      backgroundColor: context.surfaceCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_financial_summary_title'.i18n(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildRow(
            context,
            'order_total_cost_price'.i18n(),
            amount: order.totalCostPrice,
            currencyCode: order.currency,
          ),
          if (order.additionalCost > 0) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _buildRow(
                context,
                'order_items_cost_only'.i18n(),
                amount: order.itemsCostOnly,
                currencyCode: order.currency,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12),
              child: _buildRow(
                context,
                'order_additional_cost'.i18n(),
                amount: order.additionalCost,
                currencyCode: order.currency,
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildRow(
            context,
            'order_total_sell_price'.i18n(),
            amount: order.isFullyPriced ? order.totalSellPrice : null,
            currencyCode: order.currency,
            textValue: order.isFullyPriced ? null : 'order_pricing_pending'.i18n(),
            highlight: true,
          ),
          const SizedBox(height: 8),
          _buildRow(
            context,
            'order_paid_deposit'.i18n(),
            amount: order.paidAmount,
            currencyCode: order.currency,
          ),
          const SizedBox(height: 8),
          _buildRow(
            context,
            'order_remaining_debt'.i18n(),
            amount: order.remainingDebt,
            currencyCode: order.currency,
            isDanger: order.remainingDebt > 0,
          ),
          const Divider(height: 20),
          _buildRow(
            context,
            'order_estimated_profit'.i18n(),
            amount: order.rawProfit,
            currencyCode: order.currency,
            highlight: true,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 16),
          AppPrimaryButton(
            onPressed: onUpdatePayment,
            icon: Icons.payment_rounded,
            label: 'order_update_payment_btn'.i18n(),
            backgroundColor: AppColors.primaryGreen,
            height: 44,
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String label, {
    double? amount,
    String? currencyCode,
    String? textValue,
    bool highlight = false,
    bool isDanger = false,
    Color? color,
  }) {
    final effectiveColor = color ?? (isDanger ? AppColors.statusDanger : context.textPrimary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: highlight ? context.textPrimary : context.textSecondary,
            fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        if (amount != null && currencyCode != null)
          CurrencyPriceDisplay(
            amount: amount,
            currency: currencyCode,
            style: TextStyle(
              fontSize: highlight ? 14 : 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: effectiveColor,
            ),
          )
        else
          Text(
            textValue ?? '',
            style: TextStyle(
              fontSize: highlight ? 14 : 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.w600,
              color: effectiveColor,
            ),
          ),
      ],
    );
  }
}
