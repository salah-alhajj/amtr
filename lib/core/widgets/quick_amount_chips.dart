import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../localization/localization.dart';
import '../theme/app_colors.dart';
import 'currency_price_display.dart';

/// أزرار مساعدة لإدخال مبالغ سريعة (مثل +500، +1,000، +5,000، +10,000) مع معاينة فورية بالفاصلة
/// لتقليل أخطاء الأصفار الزائدة أو الناقصة على الشاشات الصغيرة
class QuickAmountChips extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final VoidCallback? onChanged;

  const QuickAmountChips({
    super.key,
    required this.controller,
    required this.currency,
    this.onChanged,
  });

  List<int> _stepsForCurrency() {
    if (currency.toUpperCase() == AppConstants.currencyYer.toUpperCase()) {
      return const [500, 1000, 5000, 10000];
    }
    return const [10, 50, 100, 500];
  }

  void _addStep(int step) {
    final current = double.tryParse(controller.text.trim()) ?? 0.0;
    final next = current + step;
    final formatted =
        next % 1 == 0 ? next.toInt().toString() : next.toStringAsFixed(2);
    controller.text = formatted;
    controller.selection = TextSelection.collapsed(offset: formatted.length);
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _stepsForCurrency();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final parsed = double.tryParse(value.text.trim()) ?? 0.0;
            if (parsed < 1000) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    '${'quick_amount_preview_label'.i18n()} ',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.textSecondary,
                    ),
                  ),
                  Flexible(
                    child: CurrencyPriceDisplay(
                      amount: parsed,
                      currency: currency,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: steps.map((step) {
            final label = '+${NumberFormat('#,##0', 'en').format(step)}';
            return ActionChip(
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
              backgroundColor: isDark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.surfaceMuted,
              side: BorderSide(color: context.borderSubtle, width: 0.8),
              label: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              onPressed: () => _addStep(step),
            );
          }).toList(),
        ),
      ],
    );
  }
}
