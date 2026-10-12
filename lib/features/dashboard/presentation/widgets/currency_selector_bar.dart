import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/saudi_riyal_icon.dart';

/// شريط مبدل العملات بتصميم iOS Segmented Control الأنيق مع إزالة أي ازدحام أو تكرار بصري
class CurrencySelectorBar extends StatelessWidget {
  final CurrencyService currencyService;
  final ValueChanged<String>? onCurrencyChanged;
  final String? activeCurrency;

  const CurrencySelectorBar({
    super.key,
    required this.currencyService,
    this.onCurrencyChanged,
    this.activeCurrency,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: currencyService,
      builder: (context, _) {
        final currentActive = (activeCurrency ?? currencyService.activeDisplayCurrency).toUpperCase();
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceMuted : const Color(0xFFF0F1F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppColors.darkBorderSubtle : const Color(0xFFE2E4EB),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              _buildSegment(
                context: context,
                title: 'currency_yer'.i18n(),
                symbolWidget: const Text(
                  'ر.ي',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                currencyCode: AppConstants.currencyYer,
                isActive: currentActive == AppConstants.currencyYer,
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildSegment(
                context: context,
                title: 'currency_sar'.i18n(),
                symbolWidget: SaudiRiyalIcon(
                  width: 14,
                  height: 14,
                  color: currentActive == AppConstants.currencySar
                      ? (isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue)
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                currencyCode: AppConstants.currencySar,
                isActive: currentActive == AppConstants.currencySar,
                isDark: isDark,
              ),
              const SizedBox(width: 4),
              _buildSegment(
                context: context,
                title: 'currency_usd'.i18n(),
                symbolWidget: const Text(
                  '\$',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                currencyCode: AppConstants.currencyUsd,
                isActive: currentActive == AppConstants.currencyUsd,
                isDark: isDark,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required String title,
    required Widget symbolWidget,
    required String currencyCode,
    required bool isActive,
    required bool isDark,
  }) {
    final activeTextColor = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final inactiveTextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final activeBg = isDark ? AppColors.darkSurfaceCard : Colors.white;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            currencyService.setDisplayCurrency(currencyCode);
            onCurrencyChanged?.call(currencyCode);
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isActive ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                DefaultTextStyle(
                  style: TextStyle(
                    color: isActive ? activeTextColor : inactiveTextColor,
                  ),
                  child: IconTheme(
                    data: IconThemeData(
                      color: isActive ? activeTextColor : inactiveTextColor,
                    ),
                    child: symbolWidget,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? activeTextColor : inactiveTextColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
