import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../../../models/production_batch.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/presentation/widgets/add_edit_product_sheet.dart';
import '../../data/repositories/production_batch_repository.dart';

/// ورقة سفلية أنيقة ومباشرة لتسجيل تشغيلة إنتاج جديدة (فورية أو قيد التعتيق)
class ProduceBatchSheet extends StatefulWidget {
  final Product? initialProduct;

  const ProduceBatchSheet({super.key, this.initialProduct});

  static Future<ProductionBatch?> show(
    BuildContext context, {
    Product? initialProduct,
  }) {
    return showModalBottomSheet<ProductionBatch>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ProduceBatchSheet(initialProduct: initialProduct),
    );
  }

  @override
  State<ProduceBatchSheet> createState() => _ProduceBatchSheetState();
}

class _ProduceBatchSheetState extends State<ProduceBatchSheet> {
  final _productRepo = ProductRepositoryImpl();
  final _batchRepo = ProductionBatchRepository();

  final _yieldController = TextEditingController(text: '1');
  final _curingDaysController = TextEditingController(text: '0');
  final _shelfLifeController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  List<Product> _products = const [];
  String? _selectedProductId;
  bool _deductMaterials = true;
  bool _logExpense = false;
  bool _isLoadingProducts = true;
  bool _isSubmitting = false;
  String? _errorText;

  static const List<int> _curingPresets = [0, 3, 7, 14, 30];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _yieldController.dispose();
    _curingDaysController.dispose();
    _shelfLifeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final all = await _productRepo.getAllProducts();
      final active = all.where((p) => p.isActive).toList();
      final list = active.isNotEmpty ? active : all;
      // ترتيب المنتجات المصنّعة أولاً لتسهيل الاختيار
      list.sort((a, b) {
        final aMfg = a.productType == AppConstants.productTypeManufactured;
        final bMfg = b.productType == AppConstants.productTypeManufactured;
        if (aMfg != bMfg) return aMfg ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      if (!mounted) return;
      setState(() {
        _products = list;
        _isLoadingProducts = false;
        if (widget.initialProduct != null &&
            list.any((p) => p.id == widget.initialProduct!.id)) {
          _selectedProductId = widget.initialProduct!.id;
        } else if (list.isNotEmpty) {
          _selectedProductId = list.first.id;
        }
        _syncDefaultsForSelectedProduct();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingProducts = false;
        _errorText = e.toString();
      });
    }
  }

  Product? get _selectedProduct {
    if (_selectedProductId == null) return null;
    for (final p in _products) {
      if (p.id == _selectedProductId) return p;
    }
    return null;
  }

  void _syncDefaultsForSelectedProduct() {
    final prod = _selectedProduct;
    if (prod == null) return;
    _yieldController.text = (prod.batchYield > 0 ? prod.batchYield : 1)
        .toString();
  }

  Future<void> _openCreateProduct() async {
    Product? savedProduct;
    await AddEditProductSheet.show(
      context,
      onSave: (prod) async {
        savedProduct = prod;
        await _productRepo.createProduct(prod);
      },
    );
    if (savedProduct != null && mounted) {
      await _loadProducts();
      if (!mounted) return;
      setState(() {
        _selectedProductId = savedProduct!.id;
        _syncDefaultsForSelectedProduct();
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final prod = _selectedProduct;
    if (prod == null) {
      setState(() => _errorText = 'waste_error_select_item'.i18n());
      return;
    }

    final parsedYield = int.tryParse(_yieldController.text.trim()) ?? 0;
    if (parsedYield <= 0) {
      setState(() => _errorText = 'waste_error_invalid_qty'.i18n());
      return;
    }

    final curingDays = int.tryParse(_curingDaysController.text.trim()) ?? 0;
    final shelfLifeDays = int.tryParse(_shelfLifeController.text.trim()) ?? 0;
    final notesText = _notesController.text.trim();

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final batch = await _batchRepo.produceBatch(
        product: prod,
        customYield: parsedYield,
        deductMaterials: _deductMaterials,
        logExpense: _logExpense,
        notes: notesText.isEmpty ? null : notesText,
        curingDays: curingDays < 0 ? 0 : curingDays,
        shelfLifeDays: shelfLifeDays < 0 ? 0 : shelfLifeDays,
      );
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        curingDays > 0
            ? 'mfg_batch_curing_toast'.trParams({
                'count': batch.yieldCount.toString(),
                'days': curingDays.toString(),
              })
            : 'mfg_batch_produced_toast'.trParams({
                'count': batch.yieldCount.toString(),
              }),
      );
      Navigator.of(context).pop(batch);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    final selectedCuring =
        int.tryParse(_curingDaysController.text.trim()) ?? -1;

    return AppModalSheet(
      title: 'batch_sheet_title'.i18n(),
      subtitle: 'batch_sheet_subtitle'.i18n(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isLoadingProducts)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (_products.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primaryBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 32,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'batch_no_products_hint'.i18n(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppSecondaryButton(
                        label: 'batch_create_product_btn'.i18n(),
                        icon: Icons.add_rounded,
                        onPressed: _openCreateProduct,
                      ),
                    ],
                  ),
                )
              else ...[
                AppDropdownField<String>(
                  label: 'batch_select_product'.i18n(),
                  value: _selectedProductId,
                  items: _products.map((p) {
                    final isMfg =
                        p.productType == AppConstants.productTypeManufactured;
                    final suffix = isMfg ? ' • ${'batch_recipe_tag'.i18n()}' : '';
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.stockQuantity} ${p.unit})$suffix',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedProductId = val;
                      _errorText = null;
                      _syncDefaultsForSelectedProduct();
                    });
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _yieldController,
                  label: 'mfg_batch_yield_input_label'.i18n(),
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.layers_outlined,
                  inputFormatters: AppFormatters.positiveInteger(maxDigits: 5),
                ),
                const SizedBox(height: 12),
                Text(
                  'batch_curing_presets_label'.i18n(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _curingPresets.map((days) {
                    final active = selectedCuring == days;
                    final label = days == 0
                        ? 'batch_ready_now_preset'.i18n()
                        : 'batch_days_short_fmt'.trParams({'days': '$days'});
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _curingDaysController.text = '$days';
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? (days == 0
                                    ? AppColors.primaryGreen
                                    : AppColors.statusWarning)
                                  .withValues(alpha: 0.14)
                              : context.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: active
                                ? (days == 0
                                      ? AppColors.primaryGreen
                                      : AppColors.statusWarning)
                                : context.borderSubtle,
                            width: active ? 1.4 : 0.8,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                active ? FontWeight.bold : FontWeight.w500,
                            color: active
                                ? (days == 0
                                      ? AppColors.primaryGreen
                                      : AppColors.statusWarning)
                                : context.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _curingDaysController,
                        label: 'mfg_batch_curing_days_label'.i18n(),
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters:
                            AppFormatters.positiveInteger(maxDigits: 3),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _shelfLifeController,
                        label: 'mfg_batch_shelf_life_days_label'.i18n(),
                        hint: '0',
                        keyboardType: TextInputType.number,
                        inputFormatters:
                            AppFormatters.positiveInteger(maxDigits: 3),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppSwitchTile(
                  title: 'mfg_batch_deduct_materials'.i18n(),
                  subtitle: 'mfg_batch_deduct_materials_hint'.i18n(),
                  value: _deductMaterials,
                  onChanged: (v) => setState(() => _deductMaterials = v),
                ),
                AppSwitchTile(
                  title: 'mfg_batch_log_expense'.i18n(),
                  subtitle: 'mfg_batch_log_expense_hint'.i18n(),
                  value: _logExpense,
                  onChanged: (v) => setState(() => _logExpense = v),
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _notesController,
                  label: 'common_notes'.i18n(),
                  maxLines: 2,
                ),
              ],
              if (_errorText != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.statusDanger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.statusDanger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(
                      color: AppColors.statusDanger,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              AppPrimaryButton(
                label: 'mfg_batch_confirm_btn'.i18n(),
                icon: Icons.precision_manufacturing_outlined,
                isLoading: _isSubmitting,
                backgroundColor: AppColors.primaryBlue,
                onPressed: _products.isNotEmpty && !_isSubmitting
                    ? _submit
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
