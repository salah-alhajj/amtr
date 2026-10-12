import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';

import '../../../../core/utils/yemen_phone_helper.dart';

/// نافذة منبثقة سفلية لإضافة أو تعديل بيانات العميل بتصميم آبل الموحد
class AddEditCustomerSheet extends StatefulWidget {
  final Customer? customerToEdit;
  final ValueChanged<Customer> onSave;

  const AddEditCustomerSheet({
    super.key,
    this.customerToEdit,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    Customer? customerToEdit,
    required ValueChanged<Customer> onSave,
  }) {
    return showAppModalSheet(
      context: context,
      title: customerToEdit != null ? 'customer_edit_title'.i18n() : 'customer_add_title'.i18n(),
      subtitle: 'customer_sheet_subtitle'.i18n(),
      child: AddEditCustomerSheet(
        customerToEdit: customerToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditCustomerSheet> createState() => _AddEditCustomerSheetState();
}

class _AddEditCustomerSheetState extends State<AddEditCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _whatsappCtrl;
  late final TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.customerToEdit?.name ?? '');
    _phoneCtrl = TextEditingController(text: widget.customerToEdit?.phone ?? '');
    _whatsappCtrl = TextEditingController(text: widget.customerToEdit?.whatsapp ?? '');
    _notesCtrl = TextEditingController(text: widget.customerToEdit?.notes ?? '');

    _phoneCtrl.addListener(_onFieldChanged);
    _whatsappCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _phoneCtrl.removeListener(_onFieldChanged);
    _whatsappCtrl.removeListener(_onFieldChanged);
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final rawPhone = _phoneCtrl.text.trim();
    final rawWhatsapp = _whatsappCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    final phone = rawPhone.isNotEmpty ? YemenPhoneHelper.cleanPhoneNumber(rawPhone) : null;
    final whatsapp = rawWhatsapp.isNotEmpty ? YemenPhoneHelper.cleanPhoneNumber(rawWhatsapp) : null;

    final customer = widget.customerToEdit != null
        ? Customer(
            id: widget.customerToEdit!.id,
            name: name,
            phone: phone,
            whatsapp: whatsapp,
            notes: notes.isNotEmpty ? notes : null,
            createdAt: widget.customerToEdit!.createdAt,
          )
        : Customer(
            id: const Uuid().v4(),
            name: name,
            phone: phone,
            whatsapp: whatsapp,
            notes: notes.isNotEmpty ? notes : null,
          );

    widget.onSave(customer);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final phoneOp = YemenPhoneHelper.getOperator(_phoneCtrl.text);
    final phoneOpLabel = phoneOp != YemenTelecomOperator.unknown ? YemenPhoneHelper.getOperatorLabel(phoneOp) : null;

    final waOp = YemenPhoneHelper.getOperator(_whatsappCtrl.text);
    final waOpLabel = waOp != YemenTelecomOperator.unknown ? YemenPhoneHelper.getOperatorLabel(waOp) : null;

    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameCtrl,
            label: 'customer_name_label'.i18n(),
            hint: 'customer_name_hint'.i18n(),
            prefixIcon: Icons.person_outline_rounded,
            inputFormatters: AppFormatters.personName(),
            validator: AppValidators.customerName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            label: 'customer_phone_label'.i18n(),
            hint: 'customer_phone_hint'.i18n(),
            prefixIcon: Icons.phone_outlined,
            helperText: phoneOpLabel != null ? '📱 $phoneOpLabel' : null,
            inputFormatters: AppFormatters.phoneNumber(),
            validator: (val) => AppValidators.phone(val, isRequired: false),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _whatsappCtrl,
            keyboardType: TextInputType.phone,
            label: 'customer_whatsapp_label'.i18n(),
            hint: 'customer_whatsapp_hint'.i18n(),
            prefixWidget: const WhatsAppIcon(size: 18),
            helperText: waOpLabel != null ? '💬 $waOpLabel' : null,
            inputFormatters: AppFormatters.phoneNumber(),
            validator: (val) => AppValidators.phone(val, isRequired: false),
            textInputAction: TextInputAction.next,
            suffix: TextButton(
              onPressed: () {
                if (_phoneCtrl.text.trim().isNotEmpty) {
                  setState(() => _whatsappCtrl.text = _phoneCtrl.text.trim());
                }
              },
              child: Text(
                'customer_copy_phone_to_whatsapp'.i18n(),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _notesCtrl,
            maxLines: 2,
            label: 'customer_notes_label'.i18n(),
            hint: 'customer_notes_hint'.i18n(),
            prefixIcon: Icons.notes_rounded,
            inputFormatters: AppFormatters.notes(),
            validator: AppValidators.notes,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          AppPrimaryButton(
            onPressed: _handleSubmit,
            label: widget.customerToEdit != null ? 'customer_save_changes'.i18n() : 'customer_confirm_add'.i18n(),
            icon: widget.customerToEdit != null ? Icons.check_rounded : Icons.person_add_alt_1_rounded,
          ),
        ],
      ),
    );
  }
}
