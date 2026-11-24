import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier.dart';
import '../../../suppliers/data/repositories/supplier_repository_impl.dart';
import '../../../suppliers/presentation/widgets/add_edit_supplier_sheet.dart';

/// نافذة إضافة أو تعديل مادة خام في مكتبة الموارد
class AddEditMaterialSheet extends StatefulWidget {
  final RawMaterial? materialToEdit;
  final ValueChanged<RawMaterial>? onSave;

  const AddEditMaterialSheet({
    super.key,
    this.materialToEdit,
    this.onSave,
  });

  static Future<RawMaterial?> show(
    BuildContext context, {
    RawMaterial? materialToEdit,
    ValueChanged<RawMaterial>? onSave,
  }) {
    return showAppModalSheet<RawMaterial>(
      context: context,
      title: materialToEdit == null
          ? 'material_add_title'.i18n()
          : 'material_edit_title'.i18n(),
      child: AddEditMaterialSheet(
        materialToEdit: materialToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditMaterialSheet> createState() => _AddEditMaterialSheetState();
}

class _AddEditMaterialSheetState extends State<AddEditMaterialSheet> {
  static const List<String> _unitSuggestions = [
    'كجم',
    'جرام',
    'لتر',
    'مل',
    'علبة',
    'حبة',
    'متر',
  ];

  final _formKey = GlobalKey<FormState>();
  final _supplierRepo = SupplierRepositoryImpl();
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _stockController;
  late final TextEditingController _lowStockThresholdController;
  late final TextEditingController _notesController;

  late String _currency;
  String? _supplierId;
  List<Supplier> _suppliers = const [];

  String _formatNum(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  void initState() {
    super.initState();
    final m = widget.materialToEdit;
    _nameController = TextEditingController(text: m?.name ?? '');
    _unitController = TextEditingController(text: m?.unit ?? 'كجم');
    _costController = TextEditingController(
      text: m != null ? m.unitCost.toString() : '',
    );
    _stockController = TextEditingController(
      text: (m != null && m.stockQuantity > 0) ? _formatNum(m.stockQuantity) : '',
    );
    _lowStockThresholdController = TextEditingController(
      text: (m != null && m.lowStockThreshold > 0)
          ? _formatNum(m.lowStockThreshold)
          : '',
    );
    _notesController = TextEditingController(text: m?.notes ?? '');
    _currency = m?.currency ?? PreferencesService.instance.getDefaultCurrency();
    _supplierId = m?.supplierId;
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final list = await _supplierRepo.getAllSuppliers();
      if (!mounted) return;
      setState(() {
        _suppliers = list;
        if (_supplierId != null && !list.any((s) => s.id == _supplierId)) {
          _supplierId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _quickAddSupplier() async {
    final created = await AddEditSupplierSheet.show(
      context,
      onSave: (s) async {
        await _supplierRepo.createSupplier(s);
      },
    );
    if (created == null || !mounted) return;
    await _loadSuppliers();
    if (!mounted) return;
    setState(() => _supplierId = created.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _stockController.dispose();
    _lowStockThresholdController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final stockQty = double.tryParse(_stockController.text.trim()) ?? 0.0;
    final lowThreshold =
        double.tryParse(_lowStockThresholdController.text.trim()) ?? 0.0;
    final material = RawMaterial(
      id: widget.materialToEdit?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      unit: _unitController.text.trim().isEmpty
          ? 'كجم'
          : _unitController.text.trim(),
      unitCost: cost,
      currency: _currency,
      supplierId: _supplierId,
      stockQuantity: stockQty,
      lowStockThreshold: lowThreshold,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: widget.materialToEdit?.createdAt,
    );

    widget.onSave?.call(material);
    Navigator.pop(context, material);
  }

  @override
  Widget build(BuildContext context) {
    final showCurrency = PreferencesService.instance.isMultiCurrencyEnabled();

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            label: 'material_name_label'.i18n(),
            hint: 'material_name_hint'.i18n(),
            prefixIcon: Icons.science_outlined,
            validator: AppValidators.itemName,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: _unitController,
                  label: 'product_unit_label'.i18n(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: _costController,
                  label: 'material_unit_cost_label'.i18n(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 2),
                ),
              ),
              if (showCurrency) ...[
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
                      if (val != null) setState(() => _currency = val);
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _unitSuggestions.map((u) {
              return ActionChip(
                label: Text(u, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(() => _unitController.text = u),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppDropdownField<String?>(
                  label: 'product_supplier_label'.i18n(),
                  value: _supplierId,
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('supplier_none'.i18n()),
                    ),
                    ..._suppliers.map(
                      (s) => DropdownMenuItem<String?>(
                        value: s.id,
                        child: Text(s.name),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _supplierId = val),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _quickAddSupplier,
                icon: const Icon(Icons.person_add_alt_1_outlined),
                tooltip: 'supplier_add_title'.i18n(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _stockController,
                  label: 'material_stock_qty_label'.i18n(),
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: _lowStockThresholdController,
                  label: 'material_low_stock_threshold_label'.i18n(),
                  hint: '0',
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 3),
                ),
              ),
            ],
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
