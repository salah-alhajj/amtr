import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/expense.dart';
import '../../../../models/supplier.dart';
import '../../../suppliers/data/repositories/supplier_repository_impl.dart';

/// نافذة إضافة أو تعديل مصروف تشغيلي
class AddEditExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final String? initialExpenseType;
  final ValueChanged<Expense> onSave;

  const AddEditExpenseSheet({
    super.key,
    this.expenseToEdit,
    this.initialExpenseType,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    Expense? expenseToEdit,
    String? initialExpenseType,
    required ValueChanged<Expense> onSave,
  }) {
    return showAppModalSheet(
      context: context,
      title: expenseToEdit == null
          ? 'expense_add_title'.i18n()
          : 'expense_edit_title'.i18n(),
      child: AddEditExpenseSheet(
        expenseToEdit: expenseToEdit,
        initialExpenseType: initialExpenseType,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditExpenseSheet> createState() => _AddEditExpenseSheetState();
}

class _ExpenseQuickPreset {
  final String labelKey;
  final String category;
  final IconData icon;
  final bool isPettyCash;

  const _ExpenseQuickPreset({
    required this.labelKey,
    required this.category,
    required this.icon,
    this.isPettyCash = false,
  });
}

class _AddEditExpenseSheetState extends State<AddEditExpenseSheet> {
  static const Color _personalNeutralWarm = Color(0xFFB45309);

  static const List<_ExpenseQuickPreset> _quickPresets = [
    _ExpenseQuickPreset(
      labelKey: 'expense_quick_preset_materials',
      category: 'exp_cat_materials',
      icon: Icons.inventory_2_outlined,
    ),
    _ExpenseQuickPreset(
      labelKey: 'expense_quick_preset_packaging',
      category: 'exp_cat_packaging',
      icon: Icons.all_inbox_outlined,
    ),
    _ExpenseQuickPreset(
      labelKey: 'expense_quick_preset_delivery',
      category: 'exp_cat_delivery',
      icon: Icons.local_shipping_outlined,
    ),
    _ExpenseQuickPreset(
      labelKey: 'expense_quick_preset_petty_cash',
      category: 'exp_cat_petty_cash',
      icon: Icons.bolt_rounded,
      isPettyCash: true,
    ),
    _ExpenseQuickPreset(
      labelKey: 'expense_quick_preset_marketing',
      category: 'exp_cat_marketing',
      icon: Icons.campaign_outlined,
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _supplierRepo = SupplierRepositoryImpl();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  late String _category;
  late String _expenseType;
  late String _currency;
  late DateTime _expenseDate;
  late String _recurrence;
  late bool _isPettyCash;
  String? _supplierId;
  String? _receiptPhotoPath;
  String? _appliedPresetTitle;
  List<Supplier> _suppliers = const [];

  @override
  void initState() {
    super.initState();
    final e = widget.expenseToEdit;
    _titleController = TextEditingController(text: e?.title ?? '');
    _amountController = TextEditingController(
      text: e != null ? e.amount.toString() : '',
    );
    _notesController = TextEditingController(text: e?.notes ?? '');
    _category = e?.category ?? AppConstants.expenseCategories.first;
    _expenseType = e?.expenseType ??
        widget.initialExpenseType ??
        AppConstants.expenseTypeBusiness;
    _currency = e?.currency ?? PreferencesService.instance.getDefaultCurrency();
    _expenseDate = e?.expenseDate ?? DateTime.now();
    _recurrence = e?.recurrence ?? AppConstants.expenseRecurrenceOnce;
    _isPettyCash = e?.isPettyCash ?? false;
    _supplierId = e?.supplierId;
    _receiptPhotoPath = e?.receiptPhotoPath;
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

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _expenseDate = picked);
    }
  }

  void _applyQuickPreset(_ExpenseQuickPreset preset) {
    final presetTitle = preset.labelKey.i18n();
    setState(() {
      final currentTitle = _titleController.text.trim();
      if (currentTitle.isEmpty || currentTitle == _appliedPresetTitle) {
        _titleController.text = presetTitle;
        _appliedPresetTitle = presetTitle;
      }
      _category = preset.category;
      if (preset.isPettyCash) {
        _isPettyCash = true;
      }
    });
  }

  Widget _buildQuickPresetChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'expense_quick_presets_label'.i18n(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: _quickPresets.map((preset) {
            final isSelected = _category == preset.category &&
                (!preset.isPettyCash || _isPettyCash);
            final accentColor = preset.isPettyCash
                ? const Color(0xFFD97706)
                : AppColors.primaryBlue;
            return ActionChip(
              avatar: Icon(
                preset.icon,
                size: 15,
                color: isSelected ? accentColor : context.textSecondary,
              ),
              label: Text(
                preset.labelKey.i18n(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? accentColor : context.textPrimary,
                ),
              ),
              backgroundColor: isSelected
                  ? accentColor.withValues(alpha: 0.14)
                  : context.surfaceMuted,
              side: BorderSide(
                color: isSelected ? accentColor : context.borderSubtle,
                width: isSelected ? 1.2 : 0.8,
              ),
              onPressed: () => _applyQuickPreset(preset),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final expense = Expense(
      id: widget.expenseToEdit?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      category: _category,
      expenseType: _expenseType,
      amount: amount,
      currency: _currency,
      expenseDate: _expenseDate,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      recurrence: _recurrence,
      isPettyCash: _isPettyCash,
      supplierId:
          _expenseType == AppConstants.expenseTypeBusiness ? _supplierId : null,
      receiptPhotoPath: _receiptPhotoPath,
      parentRuleId: widget.expenseToEdit?.parentRuleId,
      createdAt: widget.expenseToEdit?.createdAt,
    );

    widget.onSave(expense);
    Navigator.pop(context);
  }

  Widget _buildExpenseTypeSelector() {
    final isBusiness = _expenseType == AppConstants.expenseTypeBusiness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'expense_type_label'.i18n(),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeOption(
                label: 'expense_type_business'.i18n(),
                icon: Icons.storefront_outlined,
                selected: isBusiness,
                color: AppColors.primaryBlue,
                onTap: () => setState(
                  () => _expenseType = AppConstants.expenseTypeBusiness,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypeOption(
                label: 'expense_type_personal'.i18n(),
                icon: Icons.home_outlined,
                selected: !isBusiness,
                color: _personalNeutralWarm,
                onTap: () => setState(
                  () => _expenseType = AppConstants.expenseTypePersonal,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeOption({
    required String label,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : context.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : context.borderSubtle,
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? color : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCurrency = PreferencesService.instance.isMultiCurrencyEnabled();
    final amountField = AppTextField(
      controller: _amountController,
      label: 'expense_amount_label'.i18n(),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      validator: (val) {
        final parsed = double.tryParse(val?.trim() ?? '');
        if (parsed == null || parsed <= 0) {
          return 'expense_amount_required'.i18n();
        }
        return null;
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
                    _buildExpenseTypeSelector(),
                    if (widget.expenseToEdit == null &&
                        _expenseType == AppConstants.expenseTypeBusiness) ...[
                      const SizedBox(height: 10),
                      _buildQuickPresetChips(),
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _titleController,
                      label: 'expense_title_label'.i18n(),
                      hint: 'expense_title_hint'.i18n(),
                      prefixIcon: Icons.receipt_long_outlined,
                      validator: AppValidators.itemName,
                    ),
                    const SizedBox(height: 12),
                    AppDropdownField<String>(
                      label: 'product_category_label'.i18n(),
                      value: _category,
                      items: AppConstants.expenseCategories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c.i18n())))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (showCurrency)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: amountField,
                          ),
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
                      )
                    else
                      amountField,
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: context.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.borderSubtle, width: 0.8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: AppColors.primaryBlue,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'expense_date_label'.i18n(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                DateFormat('yyyy/MM/dd').format(_expenseDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'expense_recurrence_label'.i18n(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: AppConstants.expenseRecurrences.map((rec) {
                        final selected = _recurrence == rec;
                        final color = AppConstants.getExpenseRecurrenceColor(rec);
                        return ChoiceChip(
                          label: Text(AppConstants.getExpenseRecurrenceLabel(rec)),
                          selected: selected,
                          selectedColor: color.withValues(alpha: 0.16),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                            color: selected ? color : context.textPrimary,
                          ),
                          onSelected: (_) => setState(() => _recurrence = rec),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    AppSwitchTile(
                      title: 'expense_petty_cash_label'.i18n(),
                      subtitle: 'expense_petty_cash_hint'.i18n(),
                      value: _isPettyCash,
                      onChanged: (val) {
                        setState(() {
                          _isPettyCash = val;
                          if (val && _category == AppConstants.expenseCategories.first) {
                            _category = 'exp_cat_petty_cash';
                          }
                        });
                      },
                    ),
                    if (_expenseType == AppConstants.expenseTypeBusiness) ...[
                      const SizedBox(height: 10),
                      AppDropdownField<String?>(
                        label: 'expense_supplier_label'.i18n(),
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
                    ],
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _notesController,
                      label: 'common_notes'.i18n(),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'expense_receipt_photo_title'.i18n(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppPhotoAttachmentSection(
                      photos: _receiptPhotoPath != null && _receiptPhotoPath!.isNotEmpty
                          ? [_receiptPhotoPath!]
                          : const [],
                      maxPhotos: 1,
                      compact: true,
                      title: 'expense_receipt_photo_title'.i18n(),
                      hint: 'expense_receipt_photo_hint'.i18n(),
                      onPhotosChanged: (paths) {
                        setState(() {
                          _receiptPhotoPath = paths.isNotEmpty ? paths.first : null;
                        });
                      },
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
