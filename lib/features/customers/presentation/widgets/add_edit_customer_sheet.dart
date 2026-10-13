import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../domain/customer_financial_helper.dart';

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
    final currentLang = LocalizationHelper.currentLanguage;
    final initialPhone = widget.customerToEdit?.phone;
    final initialWhatsapp = widget.customerToEdit?.whatsapp;

    _nameCtrl = TextEditingController(text: widget.customerToEdit?.name ?? '');
    _phoneCtrl = TextEditingController(
      text: initialPhone != null
          ? YemenPhoneHelper.localizeDigits(initialPhone, languageCode: currentLang)
          : '',
    );
    _whatsappCtrl = TextEditingController(
      text: initialWhatsapp != null
          ? YemenPhoneHelper.localizeDigits(initialWhatsapp, languageCode: currentLang)
          : '',
    );
    _notesCtrl = TextEditingController(
      text: CustomerFinancialHelper.cleanUserNotes(widget.customerToEdit?.notes),
    );

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
    final cleanNotes = _notesCtrl.text.trim();

    final phone = rawPhone.isNotEmpty ? YemenPhoneHelper.cleanPhoneNumber(rawPhone) : null;
    final whatsapp = rawWhatsapp.isNotEmpty ? YemenPhoneHelper.cleanPhoneNumber(rawWhatsapp) : null;

    // الحفاظ على كائن التسوية المالية اليدوية دون فقدان أو تشويه
    final override = CustomerFinancialHelper.parseOverride(widget.customerToEdit?.notes);
    final mergedNotes = CustomerFinancialHelper.encodeNotesWithOverride(
      cleanNotes.isNotEmpty ? cleanNotes : null,
      override,
    );
    final finalNotes = (override.hasActiveOverride || cleanNotes.isNotEmpty)
        ? (mergedNotes.isNotEmpty ? mergedNotes : null)
        : null;

    final customer = widget.customerToEdit != null
        ? Customer(
            id: widget.customerToEdit!.id,
            name: name,
            phone: phone,
            whatsapp: whatsapp,
            notes: finalNotes,
            createdAt: widget.customerToEdit!.createdAt,
          )
        : Customer(
            id: const Uuid().v4(),
            name: name,
            phone: phone,
            whatsapp: whatsapp,
            notes: finalNotes,
          );

    widget.onSave(customer);
    Navigator.pop(context);
  }

  Future<String?> _selectPhoneFromList(BuildContext context, List<Phone> phones) {
    return showAppModalSheet<String>(
      context: context,
      title: 'contacts_select_phone_title'.i18n(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: phones.map((p) {
          final raw = p.number;
          final formatted = YemenPhoneHelper.formatForDisplay(raw, context: context) ?? raw;
          final label = p.label.customLabel ?? p.label.label.name;
          return ListTile(
            leading: const Icon(Icons.phone_rounded, color: AppColors.primaryBlue),
            title: Text(formatted, textDirection: TextDirection.ltr),
            subtitle: Text(label),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            onTap: () => Navigator.pop(context, raw),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickContactFor(TextEditingController controller) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      AppToast.showInfo(context, 'contacts_pick_tooltip'.i18n());
      return;
    }

    try {
      final hasPermission = await FlutterContacts.permissions.has(PermissionType.read);
      if (!hasPermission) {
        if (!mounted) return;
        final shouldRequest = await AppConfirmationDialog.show(
          context,
          title: 'contacts_permission_title'.i18n(),
          message: 'contacts_permission_desc'.i18n(),
          confirmLabel: 'contacts_permission_request_btn'.i18n(),
          cancelLabel: 'common_cancel'.i18n(),
          icon: Icons.perm_contact_calendar_rounded,
          iconColor: AppColors.primaryBlue,
        );

        if (shouldRequest != true) return;

        final status = await FlutterContacts.permissions.request(PermissionType.read);
        if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
          if (mounted) {
            AppToast.showError(context, 'contacts_permission_denied'.i18n());
          }
          return;
        }
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone, ContactProperty.name},
      );

      if (contact == null || !mounted) return;

      if (contact.phones.isEmpty) {
        AppToast.showInfo(context, 'contacts_no_phone_found'.i18n());
        return;
      }

      String? chosenNumber;
      if (contact.phones.length == 1) {
        chosenNumber = contact.phones.first.number;
      } else {
        chosenNumber = await _selectPhoneFromList(context, contact.phones);
        if (chosenNumber == null || !mounted) return;
      }

      final cleaned = YemenPhoneHelper.cleanPhoneNumber(chosenNumber);
      final localized = YemenPhoneHelper.localizeDigits(
        cleaned.isNotEmpty ? cleaned : chosenNumber,
        context: context,
      );

      setState(() {
        controller.text = localized;
        if (_nameCtrl.text.trim().isEmpty &&
            contact.displayName != null &&
            contact.displayName!.trim().isNotEmpty) {
          _nameCtrl.text = contact.displayName!.trim();
        }
      });
    } catch (e) {
      debugPrint('Error picking contact: $e');
    }
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
            helperText: phoneOpLabel,
            inputFormatters: AppFormatters.phoneNumber(),
            validator: (val) => AppValidators.phone(val, isRequired: false),
            textInputAction: TextInputAction.next,
            suffix: Padding(
              padding: const EdgeInsetsDirectional.only(end: 4),
              child: IconButton(
                icon: const Icon(Icons.contacts_rounded, size: 20, color: AppColors.primaryBlue),
                tooltip: 'contacts_pick_tooltip'.i18n(),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                onPressed: () => _pickContactFor(_phoneCtrl),
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _whatsappCtrl,
            keyboardType: TextInputType.phone,
            label: 'customer_whatsapp_label'.i18n(),
            hint: 'customer_whatsapp_hint'.i18n(),
            prefixWidget: const WhatsAppIcon(size: 18),
            helperText: waOpLabel,
            inputFormatters: AppFormatters.phoneNumber(),
            validator: (val) => AppValidators.phone(val, isRequired: false),
            textInputAction: TextInputAction.next,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.contacts_rounded, size: 20, color: AppColors.primaryBlue),
                  tooltip: 'contacts_pick_tooltip'.i18n(),
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _pickContactFor(_whatsappCtrl),
                ),
                const SizedBox(width: 4),
                AppSecondaryButton(
                  height: 28,
                  borderRadius: 6,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  onPressed: () {
                    if (_phoneCtrl.text.trim().isNotEmpty) {
                      setState(() => _whatsappCtrl.text = _phoneCtrl.text.trim());
                    }
                  },
                  label: 'customer_copy_phone_to_whatsapp'.i18n(),
                ),
                const SizedBox(width: 6),
              ],
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
