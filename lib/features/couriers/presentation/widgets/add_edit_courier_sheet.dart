import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/courier.dart';

/// نافذة إضافة أو تعديل بيانات مندوب التوصيل
class AddEditCourierSheet extends StatefulWidget {
  final Courier? courierToEdit;
  final ValueChanged<Courier>? onSave;

  const AddEditCourierSheet({
    super.key,
    this.courierToEdit,
    this.onSave,
  });

  static Future<Courier?> show(
    BuildContext context, {
    Courier? courierToEdit,
    ValueChanged<Courier>? onSave,
  }) {
    return showAppModalSheet<Courier>(
      context: context,
      title: courierToEdit == null
          ? 'courier_add_title'.i18n()
          : 'courier_edit_title'.i18n(),
      child: AddEditCourierSheet(
        courierToEdit: courierToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditCourierSheet> createState() => _AddEditCourierSheetState();
}

class _AddEditCourierSheetState extends State<AddEditCourierSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _defaultFeeController;
  late final TextEditingController _notesController;
  late String _currency;

  @override
  void initState() {
    super.initState();
    final c = widget.courierToEdit;
    _nameController = TextEditingController(text: c?.name ?? '');
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _whatsappController = TextEditingController(text: c?.whatsapp ?? '');
    _defaultFeeController = TextEditingController(
      text: c != null && c.defaultFee > 0
          ? (c.defaultFee % 1 == 0
              ? c.defaultFee.toStringAsFixed(0)
              : c.defaultFee.toString())
          : '',
    );
    _notesController = TextEditingController(text: c?.notes ?? '');
    _currency = c?.currency ?? PreferencesService.instance.getDefaultCurrency();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _defaultFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    final parsedFee =
        double.tryParse(_defaultFeeController.text.trim()) ?? 0.0;

    final courier = Courier(
      id: widget.courierToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      whatsapp: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
      defaultFee: parsedFee < 0 ? 0.0 : parsedFee,
      currency: _currency,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.courierToEdit?.createdAt,
    );

    widget.onSave?.call(courier);
    Navigator.pop(context, courier);
  }

  @override
  Widget build(BuildContext context) {
    final showCurrency = PreferencesService.instance.isMultiCurrencyEnabled();
    final feeField = AppTextField(
      controller: _defaultFeeController,
      label: 'courier_default_fee_label'.i18n(),
      hint: 'courier_default_fee_hint'.i18n(),
      prefixIcon: Icons.delivery_dining_outlined,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return null;
        return AppValidators.positiveAmount(val, allowZero: true);
      },
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.80,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _nameController,
                      label: 'courier_name_label'.i18n(),
                      hint: 'courier_name_hint'.i18n(),
                      prefixIcon: Icons.person_outline_rounded,
                      validator: AppValidators.itemName,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _phoneController,
                            label: 'customer_phone_label'.i18n(),
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: AppFormatters.phoneNumber(),
                            validator: (v) =>
                                AppValidators.phone(v, isRequired: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppTextField(
                            controller: _whatsappController,
                            label: 'customer_whatsapp_label'.i18n(),
                            prefixIcon: Icons.chat_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: AppFormatters.phoneNumber(),
                            validator: (v) =>
                                AppValidators.phone(v, isRequired: false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (showCurrency)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: feeField),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: AppDropdownField<String>(
                              label: 'currency_label'.i18n(),
                              value: _currency,
                              items: [
                                DropdownMenuItem(
                                  value: AppConstants.currencyYer,
                                  child: Text('currency_yer'.i18n()),
                                ),
                                DropdownMenuItem(
                                  value: AppConstants.currencySar,
                                  child: Text('currency_sar'.i18n()),
                                ),
                                DropdownMenuItem(
                                  value: AppConstants.currencyUsd,
                                  child: Text('currency_usd'.i18n()),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _currency = val);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      feeField,
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notesController,
                      label: 'common_notes'.i18n(),
                      maxLines: 2,
                      inputFormatters: AppFormatters.notes(),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppPrimaryButton(
              onPressed: _submit,
              icon: Icons.check_circle_outline_rounded,
              label: 'common_save'.i18n(),
              backgroundColor: AppColors.primaryBlue,
            ),
          ],
        ),
      ),
    );
  }
}
