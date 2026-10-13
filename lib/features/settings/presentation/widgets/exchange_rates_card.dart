import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// بطاقة ضبط وتعديل أسعار صرف العملات مقابل العملة القاعدة (الريال اليمني)
class ExchangeRatesCard extends StatefulWidget {
  final TextEditingController sarController;
  final TextEditingController usdController;
  final VoidCallback onSave;

  const ExchangeRatesCard({
    super.key,
    required this.sarController,
    required this.usdController,
    required this.onSave,
  });

  @override
  State<ExchangeRatesCard> createState() => _ExchangeRatesCardState();
}

class _ExchangeRatesCardState extends State<ExchangeRatesCard> {
  final _formKey = GlobalKey<FormState>();

  void _handleSave() {
    if (!_formKey.currentState!.validate()) {
      AppToast.error(context, 'form_validation_failed'.i18n());
      return;
    }
    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.currency_exchange_rounded,
                  color: AppColors.primaryBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'exchange_rates_header'.i18n(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'exchange_rates_explanation'.i18n(),
              style: TextStyle(fontSize: 12, color: context.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: context.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.borderSubtle, width: 0.8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'exchange_base_currency_label'.i18n(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${'currency_yer'.i18n()} (${AppConstants.yerSymbol.toLowerCase().i18n().toUpperCase()})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: widget.sarController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: 'exchange_sar_to_yer_label'.i18n(),
              hint: '0.00',
              prefixWidget: const SaudiRiyalIcon(
                width: 18,
                height: 16,
                color: AppColors.primaryBlue,
              ),
              inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
              validator: AppValidators.exchangeRate,
              textInputAction: TextInputAction.next,
              suffix: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Text(
                    AppConstants.yerSymbol.toLowerCase().i18n().toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: widget.usdController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: 'exchange_usd_to_yer_label'.i18n(),
              hint: '0.00',
              prefixWidget: const Text(
                '\$',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlue,
                ),
              ),
              inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
              validator: AppValidators.exchangeRate,
              textInputAction: TextInputAction.done,
              suffix: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Text(
                    AppConstants.yerSymbol.toLowerCase().i18n().toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            AppPrimaryButton(
              onPressed: _handleSave,
              label: 'exchange_save_rates_btn'.i18n(),
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
