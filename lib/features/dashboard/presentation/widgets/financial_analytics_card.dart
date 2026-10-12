import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/charts/financial_charts.dart';

/// بطاقة التحليلات والرسوم البيانية المالية المتقدمة
class FinancialAnalyticsCard extends StatefulWidget {
  final double collectedAmount;
  final double remainingAmount;
  final double debtAmount;
  final double totalRevenue;
  final String activeCurrency;
  final List<double> weeklySales;
  final List<String>? dayLabels;

  const FinancialAnalyticsCard({
    super.key,
    required this.collectedAmount,
    required this.remainingAmount,
    required this.debtAmount,
    required this.totalRevenue,
    required this.activeCurrency,
    required this.weeklySales,
    this.dayLabels,
  });

  @override
  State<FinancialAnalyticsCard> createState() => _FinancialAnalyticsCardState();
}

class _FinancialAnalyticsCardState extends State<FinancialAnalyticsCard> {
  int _selectedTab = 0; // 0: رسم المبيعات المنحني, 1: توزيع التدفق المالي

  @override
  Widget build(BuildContext context) {
    return AppAnimatedCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      size: 18,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'financial_analytics_title'.i18n(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              // مبدل النمط المصغر (Segmented Control)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: context.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderSubtle, width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTabPill('chart_trend'.i18n(), 0),
                    _buildTabPill('chart_distribution'.i18n(), 1),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // محتوى المخطط المختار
          if (_selectedTab == 0) ...[
            BezierSalesChart(
              values: widget.weeklySales.isEmpty
                  ? [widget.totalRevenue * 0.4, widget.totalRevenue * 0.6, widget.totalRevenue * 0.5, widget.totalRevenue * 0.8, widget.totalRevenue]
                  : widget.weeklySales,
              labels: widget.dayLabels ?? [
                'day_saturday'.i18n(),
                'day_sunday'.i18n(),
                'day_monday'.i18n(),
                'day_tuesday'.i18n(),
                'day_wednesday'.i18n(),
                'day_thursday'.i18n(),
                'day_today'.i18n(),
              ],
              currencyCode: widget.activeCurrency,
              primaryColor: AppColors.primaryBlue,
              height: 140,
            ),
          ] else ...[
            CashFlowDonutChart(
              collectedAmount: widget.collectedAmount,
              remainingAmount: widget.remainingAmount,
              debtAmount: widget.debtAmount,
              currencyCode: widget.activeCurrency,
              size: 120,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabPill(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? context.surfaceCard : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primaryBlue : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
