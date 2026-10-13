import 'package:amtr/core/localization/localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../theme/app_colors.dart';
import 'saudi_riyal_icon.dart';

/// ويدجت متقدم لعرض المبالغ النقدية مع الرمز الرسمي المعتمد للعملات
/// يدعم الريال السعودي بالرمز الرسمي SVG أو اليونيكود U+20C1 طبقاً لتعليمات البنك المركزي (SAMA)
class CurrencyPriceDisplay extends StatelessWidget {
  final double amount;
  final String currency;
  final TextStyle? style;
  final double? iconSize;
  final Color? color;
  final int? decimalDigits;
  final bool showSymbol;

  const CurrencyPriceDisplay({
    super.key,
    required this.amount,
    required this.currency,
    this.style,
    this.iconSize,
    this.color,
    this.decimalDigits,
    this.showSymbol = true,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveStyle = (style ?? Theme.of(context).textTheme.bodyMedium)
        ?.copyWith(color: color ?? style?.color);

    final digits = decimalDigits ?? (amount % 1 == 0 ? 0 : 2);
    final formatter = NumberFormat.currency(symbol: '', decimalDigits: digits);
    final formattedAmount = formatter.format(amount).trim();

    if (!showSymbol) {
      return Text(formattedAmount, style: effectiveStyle);
    }

    final isSar = currency.toUpperCase() == AppConstants.currencySar;
    final isYer =
        currency.toUpperCase().substring(0, 3) ==
        AppConstants.currencyYer.toUpperCase();
    final isUsd = currency.toUpperCase() == AppConstants.currencyUsd;

    final fontSize = effectiveStyle?.fontSize ?? 14.0;
    final effectiveIconSize = iconSize ?? (fontSize * 0.95);
    final iconColor = effectiveStyle?.color ?? AppColors.textPrimary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(formattedAmount, style: effectiveStyle),
        const SizedBox(width: 4),
        if (isSar)
          SaudiRiyalIcon(
            width: effectiveIconSize,
            height: effectiveIconSize * 0.9,
            color: iconColor,
          )
        else
          Text(
            isYer ? 'yer'.i18n() : (isUsd ? AppConstants.usdSymbol : currency),
            style: effectiveStyle?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: fontSize * 0.85,
            ),
          ),
      ],
    );
  }
}
