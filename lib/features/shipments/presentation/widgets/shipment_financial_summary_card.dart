import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';
import '../../../../core/widgets/saudi_riyal_icon.dart';
import '../../../../models/consolidated_shipment.dart';

/// بطاقة ملخص الحسبة المالية وتدقيق صافي الأرباح للشحنة المجمعة
class ShipmentFinancialSummaryCard extends StatelessWidget {
  final ConsolidatedShipment shipment;
  final String viewCurrency;
  final ValueChanged<String> onCurrencyChanged;

  const ShipmentFinancialSummaryCard({
    super.key,
    required this.shipment,
    required this.viewCurrency,
    required this.onCurrencyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService.instance;

    // الحسبة المالية
    final totalClientSellYer = shipment.calculateTotalClientSellPriceInYer(currencyService);
    final totalCostYer = shipment.calculateTotalOriginalCostInYer(currencyService);
    final transportCostYer = shipment.calculateTransportCostInYer(currencyService);
    final netProfitYer = shipment.calculateNetProfitInYer(currencyService);

    // تحويل الأرقام إلى العملة المعروضة حالياً
    final totalClientSell = currencyService.fromBaseYer(totalClientSellYer, viewCurrency);
    final totalCost = currencyService.fromBaseYer(totalCostYer, viewCurrency);
    final transportCost = currencyService.fromBaseYer(transportCostYer, viewCurrency);
    final netProfit = currencyService.fromBaseYer(netProfitYer, viewCurrency);

    return AppleCard(
      gradient: context.isDarkMode
          ? const LinearGradient(
              colors: [AppColors.darkSurfaceCard, AppColors.darkSurfaceMuted],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            )
          : const LinearGradient(
              colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
      border: Border.all(
        color: AppColors.primaryGreen.withValues(alpha: 0.3),
        width: 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'shipment_profit_calc_title'.i18n(),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              // أزرار تبديل عملة الحسبة
              Row(
                children: [
                  _buildCurrencyChip(
                    context,
                    label: AppConstants.yerSymbol,
                    code: AppConstants.currencyYer,
                  ),
                  const SizedBox(width: 4),
                  _buildCurrencyChip(
                    context,
                    code: AppConstants.currencySar,
                    customWidget: SaudiRiyalIcon(
                      width: 13,
                      height: 12,
                      color: viewCurrency == AppConstants.currencySar ? Colors.white : context.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildCurrencyChip(
                    context,
                    label: AppConstants.usdSymbol,
                    code: AppConstants.currencyUsd,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildAuditRow(
            context,
            'shipment_total_client_sales'.i18n(),
            currencyService.formatAmount(totalClientSell, currencyCode: viewCurrency),
          ),
          const SizedBox(height: 6),
          _buildAuditRow(
            context,
            'shipment_deduct_cost_price'.i18n(),
            currencyService.formatAmount(totalCost, currencyCode: viewCurrency),
          ),
          const SizedBox(height: 6),
          _buildAuditRow(
            context,
            'shipment_deduct_transport_cost'.i18n(),
            currencyService.formatAmount(transportCost, currencyCode: viewCurrency),
            subtitle: 'shipment_paid_transport_fmt'.trParams({
              'amount': shipment.transportCost.toString(),
              'currency': AppConstants.getCurrencySymbol(shipment.transportCostCurrency),
            }),
          ),

          const Divider(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'shipment_actual_net_profit'.i18n(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                currencyService.formatAmount(netProfit, currencyCode: viewCurrency),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: netProfit >= 0 ? AppColors.primaryGreen : AppColors.statusDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyChip(
    BuildContext context, {
    String? label,
    Widget? customWidget,
    required String code,
  }) {
    final isSelected = viewCurrency == code;

    return GestureDetector(
      onTap: () => onCurrencyChanged(code),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryGreen : context.surfaceCard,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppColors.primaryGreen : context.borderSubtle,
          ),
        ),
        child: customWidget ??
            Text(
              label ?? code,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : context.textSecondary,
              ),
            ),
      ),
    );
  }

  Widget _buildAuditRow(BuildContext context, String label, String value, {String? subtitle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(width: 4),
              Text(subtitle, style: TextStyle(fontSize: 10, color: context.textTertiary)),
            ],
          ],
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
