import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';

/// بطاقة منبثقة سفلية لتسديد دفعة أو جزء من مديونية طلب معين
class SettlePartialDebtSheet extends StatefulWidget {
  final IndividualOrder order;
  final Future<void> Function(double amountPaid, String newStatus) onConfirmPayment;

  const SettlePartialDebtSheet({
    super.key,
    required this.order,
    required this.onConfirmPayment,
  });

  static Future<void> show(
    BuildContext context, {
    required IndividualOrder order,
    required Future<void> Function(double amountPaid, String newStatus) onConfirmPayment,
  }) {
    return showAppModalSheet(
      context: context,
      title: 'customer_pay_part_title'.i18n(),
      subtitle: 'customer_pay_part_subtitle'.i18n(),
      child: SettlePartialDebtSheet(
        order: order,
        onConfirmPayment: onConfirmPayment,
      ),
    );
  }

  @override
  State<SettlePartialDebtSheet> createState() => _SettlePartialDebtSheetState();
}

class _SettlePartialDebtSheetState extends State<SettlePartialDebtSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _isSubmitting = false;

  double get _remainingDebt => widget.order.remainingDebt;
  double get _currentInputAmount => double.tryParse(_amountController.text) ?? 0.0;
  double get _expectedNewRemaining => (_remainingDebt - _currentInputAmount).clamp(0.0, double.infinity);

  @override
  void initState() {
    super.initState();
    // اقتراح مبدئي كامل الدين أو نصفه إن كان كبيراً
    _amountController = TextEditingController(text: _remainingDebt > 0 ? _remainingDebt.toStringAsFixed(0) : '0');
    _amountController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onTextChanged);
    _amountController.dispose();
    super.dispose();
  }

  void _setPercentage(double fraction) {
    final amt = (_remainingDebt * fraction);
    _amountController.text = (amt % 1 == 0) ? amt.toInt().toString() : amt.toStringAsFixed(2);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payAmount = _currentInputAmount;
    if (payAmount <= 0) return;

    final newTotalPaid = widget.order.paidAmount + payAmount;
    final isFullyPaid = newTotalPaid >= widget.order.totalSellPrice;
    final newStatus = isFullyPaid ? AppConstants.paymentPrepaid : AppConstants.paymentPartial;

    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirmPayment(payAmount, newStatus);
      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // بطاقة ملخص مديونية الطلب الحالي
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                width: 0.8,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'order_number'.trParams({'id': widget.order.orderNumber}),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                    AppBadge(
                      label: AppConstants.getPaymentStatusLabel(widget.order.paymentStatus),
                      color: widget.order.paymentStatus == AppConstants.paymentPrepaid
                          ? AppColors.primaryGreen
                          : AppColors.statusDanger,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'customer_current_paid'.i18n(),
                      style: TextStyle(fontSize: 12, color: context.textSecondary),
                    ),
                    CurrencyPriceDisplay(
                      amount: widget.order.paidAmount,
                      currency: widget.order.currency,
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'customer_remaining_debt_on_order'.i18n(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    CurrencyPriceDisplay(
                      amount: _remainingDebt,
                      currency: widget.order.currency,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.statusDanger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // خيارات سريعة للنسب المئوية
          Row(
            children: [
              Expanded(
                child: AppFilterChip(
                  label: 'customer_quick_percentage_25'.i18n(),
                  isSelected: (_remainingDebt * 0.25 - _currentInputAmount).abs() < 0.1,
                  onSelected: (_) => _setPercentage(0.25),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppFilterChip(
                  label: 'customer_quick_percentage_50'.i18n(),
                  isSelected: (_remainingDebt * 0.50 - _currentInputAmount).abs() < 0.1,
                  onSelected: (_) => _setPercentage(0.50),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppFilterChip(
                  label: 'customer_quick_percentage_75'.i18n(),
                  isSelected: (_remainingDebt * 0.75 - _currentInputAmount).abs() < 0.1,
                  onSelected: (_) => _setPercentage(0.75),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppFilterChip(
                  label: 'customer_quick_percentage_100'.i18n(),
                  isSelected: (_remainingDebt - _currentInputAmount).abs() < 0.1,
                  activeColor: AppColors.primaryGreen,
                  onSelected: (_) => _setPercentage(1.0),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // حقل إدخال مبلغ الدفعة
          AppTextField(
            controller: _amountController,
            label: 'customer_pay_amount_label'.i18n(),
            hint: '0.00',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            prefixIcon: Icons.payments_outlined,
            inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'validation_amount_required'.i18n();
              }
              final parsed = double.tryParse(val);
              if (parsed == null || parsed <= 0) {
                return 'validation_amount_positive'.i18n();
              }
              return null;
            },
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 12),

          // معاينة الدين المتبقي بعد السداد أو الرصيد الدائن الفائض
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _currentInputAmount > _remainingDebt
                  ? AppColors.primaryBlue.withValues(alpha: 0.1)
                  : (_expectedNewRemaining == 0
                      ? AppColors.primaryGreen.withValues(alpha: 0.1)
                      : AppColors.statusWarning.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      _currentInputAmount > _remainingDebt
                          ? Icons.account_balance_wallet_outlined
                          : (_expectedNewRemaining == 0
                              ? Icons.check_circle_outline_rounded
                              : Icons.info_outline_rounded),
                      size: 16,
                      color: _currentInputAmount > _remainingDebt
                          ? AppColors.primaryBlue
                          : (_expectedNewRemaining == 0 ? AppColors.primaryGreen : AppColors.statusWarning),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _currentInputAmount > _remainingDebt
                          ? 'customer_surplus_credit'.i18n()
                          : 'customer_new_remaining_debt'.i18n(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _currentInputAmount > _remainingDebt
                            ? AppColors.primaryBlue
                            : (_expectedNewRemaining == 0 ? AppColors.primaryGreen : context.textPrimary),
                      ),
                    ),
                  ],
                ),
                CurrencyPriceDisplay(
                  amount: _currentInputAmount > _remainingDebt
                      ? (_currentInputAmount - _remainingDebt)
                      : _expectedNewRemaining,
                  currency: widget.order.currency,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: _currentInputAmount > _remainingDebt
                        ? AppColors.primaryBlue
                        : (_expectedNewRemaining == 0 ? AppColors.primaryGreen : AppColors.statusWarning),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // زر تأكيد السداد
          AppPrimaryButton(
            onPressed: _isSubmitting ? null : _submit,
            isLoading: _isSubmitting,
            label: 'customer_confirm_payment_btn'.i18n(),
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }
}
