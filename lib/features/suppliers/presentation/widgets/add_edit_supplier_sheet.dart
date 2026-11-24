import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/supplier.dart';

/// نافذة إضافة أو تعديل مورد
class AddEditSupplierSheet extends StatefulWidget {
  final Supplier? supplierToEdit;
  final ValueChanged<Supplier>? onSave;

  const AddEditSupplierSheet({
    super.key,
    this.supplierToEdit,
    this.onSave,
  });

  static Future<Supplier?> show(
    BuildContext context, {
    Supplier? supplierToEdit,
    ValueChanged<Supplier>? onSave,
  }) {
    return showAppModalSheet<Supplier>(
      context: context,
      title: supplierToEdit == null
          ? 'supplier_add_title'.i18n()
          : 'supplier_edit_title'.i18n(),
      child: AddEditSupplierSheet(
        supplierToEdit: supplierToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditSupplierSheet> createState() => _AddEditSupplierSheetState();
}

class _AddEditSupplierSheetState extends State<AddEditSupplierSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  late String _category;

  @override
  void initState() {
    super.initState();
    final s = widget.supplierToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _whatsappController = TextEditingController(text: s?.whatsapp ?? '');
    _addressController = TextEditingController(text: s?.address ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
    _category = s?.category ?? AppConstants.supplierCategories.last;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    final supplier = Supplier(
      id: widget.supplierToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      whatsapp: _whatsappController.text.trim().isEmpty
          ? null
          : _whatsappController.text.trim(),
      category: _category,
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.supplierToEdit?.createdAt,
    );

    widget.onSave?.call(supplier);
    Navigator.pop(context, supplier);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            label: 'supplier_name_label'.i18n(),
            hint: 'supplier_name_hint'.i18n(),
            prefixIcon: Icons.local_shipping_outlined,
            validator: AppValidators.itemName,
          ),
          const SizedBox(height: 12),
          AppDropdownField<String>(
            label: 'supplier_category_label'.i18n(),
            value: _category,
            items: AppConstants.supplierCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c.i18n())))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _category = val);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _phoneController,
                  label: 'customer_phone_label'.i18n(),
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: _whatsappController,
                  label: 'customer_whatsapp_label'.i18n(),
                  prefixIcon: Icons.chat_outlined,
                  keyboardType: TextInputType.phone,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _addressController,
            label: 'supplier_address_label'.i18n(),
            prefixIcon: Icons.location_on_outlined,
          ),
          const SizedBox(height: 12),
          AppTextField(
            controller: _notesController,
            label: 'common_notes'.i18n(),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
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
