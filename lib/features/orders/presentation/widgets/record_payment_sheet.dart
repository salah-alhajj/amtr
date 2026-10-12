import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';

/// بطاقة منبثقة لتحديث حالة الدفع وسداد المبالغ للطلب بنظام آبل الموحد
class RecordPaymentSheet extends StatefulWidget {
  final IndividualOrder order;
  final Future<void> Function(String paymentStatus, double paidAmount) onSave;

  const RecordPaymentSheet({
    super.key,
    required this.order,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required IndividualOrder order,
    required Future<void> Function(String paymentStatus, double paidAmount) onSave,
  }) {
    return showAppModalSheet(
      context: context,
      title: 'payment_sheet_title'.i18n(),
      subtitle: 'payment_sheet_subtitle'.i18n(),
      child: RecordPaymentSheet(order: order, onSave: onSave),
    );
  }

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _paidController;
  late String _selectedStatus;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _paidController = TextEditingController(text: widget.order.paidAmount.toString());
    _selectedStatus = widget.order.paymentStatus;
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final paid = double.tryParse(_paidController.text) ?? 0.0;
    setState(() => _isSubmitting = true);
    await widget.onSave(_selectedStatus, paid);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDropdownField<String>(
            value: _selectedStatus,
            label: 'order_payment_status_label'.i18n(),
            items: [
              DropdownMenuItem(
                value: AppConstants.paymentPrepaid,
                child: Text(
                  AppConstants.getPaymentStatusLabel(AppConstants.paymentPrepaid),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                ),
              ),
              DropdownMenuItem(
                value: AppConstants.paymentDebt,
                child: Text(
                  AppConstants.getPaymentStatusLabel(AppConstants.paymentDebt),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                ),
              ),
              DropdownMenuItem(
                value: AppConstants.paymentCod,
                child: Text(
                  AppConstants.getPaymentStatusLabel(AppConstants.paymentCod),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                ),
              ),
              DropdownMenuItem(
                value: AppConstants.paymentPartial,
                child: Text(
                  AppConstants.getPaymentStatusLabel(AppConstants.paymentPartial),
                  style: const TextStyle(fontFamily: AppTheme.fontFamily),
                ),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedStatus = val);
            },
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _paidController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            label: 'payment_sheet_amount_paid'.trParams({
              'symbol': AppConstants.getCurrencySymbol(widget.order.currency),
            }),
            hint: '0.00',
            prefixIcon: Icons.payments_outlined,
            inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
            validator: (val) => AppValidators.paidAmount(
              val,
              allowEmpty: false,
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: _isSubmitting ? null : _submit,
            isLoading: _isSubmitting,
            label: 'payment_sheet_save_btn'.i18n(),
            icon: Icons.check_circle_outline_rounded,
          ),
        ],
      ),
    );
  }
}
