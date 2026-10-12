import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/currency_price_display.dart';

/// بطاقة إجمالي صافي الأرباح الرئيسية بتدرج آبل الأزرق والأخضر
class NetProfitHeroCard extends StatelessWidget {
  final double netProfit;
  final String activeCurrency;

  const NetProfitHeroCard({
    super.key,
    required this.netProfit,
    required this.activeCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      gradient: AppColors.appleGradient,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'net_profit_cumulative_title'.i18n(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'net_profit_actual_badge'.i18n(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CurrencyPriceDisplay(
            amount: netProfit,
            currency: activeCurrency,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
            iconSize: 22,
          ),
          const SizedBox(height: 6),
          Text(
            'net_profit_description'.i18n(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
