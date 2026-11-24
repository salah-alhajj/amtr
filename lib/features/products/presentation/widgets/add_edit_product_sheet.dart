import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../../../models/product_bundle_item.dart';
import '../../../../models/product_ingredient.dart';
import '../../../../models/product_variant.dart';
import '../../../../models/supplier.dart';
import '../../../manufacturing/presentation/widgets/production_recipe_builder_sheet.dart';
import '../../../suppliers/data/repositories/supplier_repository_impl.dart';
import '../../../suppliers/presentation/widgets/add_edit_supplier_sheet.dart';
import '../../data/product_bundle_repository.dart';
import '../../data/product_ingredient_repository.dart';
import '../../data/product_variant_repository.dart';
import '../../data/repositories/product_repository_impl.dart';
import 'pricing_helper_sheet.dart';

class _VariantDraft {
  final String id;
  final TextEditingController nameCtrl;
  final TextEditingController sellCtrl;
  final TextEditingController stockCtrl;

  _VariantDraft({
    required this.id,
    String name = '',
    double? sellPrice,
    int stockQuantity = 0,
  }) : nameCtrl = TextEditingController(text: name),
       sellCtrl = TextEditingController(
         text: sellPrice != null ? sellPrice.toString() : '',
       ),
       stockCtrl = TextEditingController(text: stockQuantity.toString());

  void dispose() {
    nameCtrl.dispose();
    sellCtrl.dispose();
    stockCtrl.dispose();
  }
}

/// نافذة إضافة أو تعديل منتج في الكتالوج
class AddEditProductSheet extends StatefulWidget {
  final Product? productToEdit;
  final ValueChanged<Product> onSave;

  const AddEditProductSheet({
    super.key,
    this.productToEdit,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    Product? productToEdit,
    required ValueChanged<Product> onSave,
  }) {
    return showAppModalSheet(
      context: context,
      title: productToEdit == null
          ? 'product_add_title'.i18n()
          : 'product_edit_title'.i18n(),
      child: AddEditProductSheet(
        productToEdit: productToEdit,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AddEditProductSheet> createState() => _AddEditProductSheetState();
}

class _AddEditProductSheetState extends State<AddEditProductSheet> {
  final _formKey = GlobalKey<FormState>();
  final _supplierRepo = SupplierRepositoryImpl();
  final _ingredientRepo = ProductIngredientRepository();
  final _variantRepo = ProductVariantRepository();
  final _bundleRepo = ProductBundleRepository();
  final _productRepo = ProductRepositoryImpl();

  late final String _productId;
  late final TextEditingController _nameController;
  late final TextEditingController _unitController;
  late final TextEditingController _costController;
  late final TextEditingController _sellController;
  late final TextEditingController _stockController;
  late final TextEditingController _thresholdController;
  late final TextEditingController _notesController;

  late String _category;
  late String _currency;
  late String _productType;
  late int _batchYield;
  String? _supplierId;
  String? _templateId;
  late bool _trackStock;
  late bool _isActive;
  late bool _isBundle;
  late int _reorderCycleDays;

  List<Supplier> _suppliers = const [];
  List<ProductIngredient> _recipeItems = const [];
  List<Product> _catalogProducts = const [];
  List<ProductBundleItem> _bundleItems = [];
  final List<_VariantDraft> _variantDrafts = [];
  bool _recipeModified = false;

  @override
  void initState() {
    super.initState();
    final p = widget.productToEdit;
    _productId = p?.id ?? const Uuid().v4();
    _nameController = TextEditingController(text: p?.name ?? '');
    _unitController = TextEditingController(
      text: p?.unit ?? 'product_unit_default'.i18n(),
    );
    _costController = TextEditingController(
      text: p != null ? p.costPrice.toString() : '0',
    );
    _sellController = TextEditingController(
      text: p != null ? p.sellPrice.toString() : '',
    );
    _stockController = TextEditingController(
      text: (p?.stockQuantity ?? 0).toString(),
    );
    _thresholdController = TextEditingController(
      text: (p?.lowStockThreshold ?? 3).toString(),
    );
    _notesController = TextEditingController(text: p?.notes ?? '');
    _category = p?.category ?? AppConstants.productCategories.last;
    _currency = p?.currency ?? PreferencesService.instance.getDefaultCurrency();
    _productType = p?.productType ?? AppConstants.productTypeResale;
    _batchYield = p?.batchYield ?? 1;
    _supplierId = p?.supplierId;
    _templateId = p?.templateId;
    _trackStock = p?.trackStock ?? false;
    _isActive = p?.isActive ?? true;
    _isBundle = p?.isBundle ?? false;
    _reorderCycleDays = p?.reorderCycleDays ?? 0;

    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final isEditing = widget.productToEdit != null;
      final results = await Future.wait([
        _supplierRepo.getAllSuppliers(),
        isEditing
            ? _ingredientRepo.getByProductId(_productId)
            : Future.value(<ProductIngredient>[]),
        _productRepo.getAllProducts(),
        isEditing
            ? _variantRepo.getByProductId(_productId)
            : Future.value(<ProductVariant>[]),
        isEditing
            ? _bundleRepo.getByBundleId(_productId)
            : Future.value(<ProductBundleItem>[]),
      ]);
      if (!mounted) return;
      final suppliers = results[0] as List<Supplier>;
      final ingredients = results[1] as List<ProductIngredient>;
      final allProducts = results[2] as List<Product>;
      final variants = results[3] as List<ProductVariant>;
      final bundleItems = results[4] as List<ProductBundleItem>;

      for (final d in _variantDrafts) {
        d.dispose();
      }
      _variantDrafts.clear();
      for (final v in variants) {
        _variantDrafts.add(
          _VariantDraft(
            id: v.id,
            name: v.variantName,
            sellPrice: v.sellPrice,
            stockQuantity: v.stockQuantity,
          ),
        );
      }

      setState(() {
        _suppliers = suppliers;
        if (_supplierId != null &&
            !suppliers.any((s) => s.id == _supplierId)) {
          _supplierId = null;
        }
        _recipeItems = ingredients;
        _catalogProducts = allProducts
            .where((prod) => prod.id != _productId && !prod.isBundle)
            .toList();
        _bundleItems = List<ProductBundleItem>.from(bundleItems);
      });
    } catch (_) {}
  }

  Future<void> _quickAddSupplier() async {
    final created = await AddEditSupplierSheet.show(
      context,
      onSave: (s) async {
        await _supplierRepo.createSupplier(s);
        DataSyncBus.instance.notify(DataDomain.suppliers);
      },
    );
    if (created == null || !mounted) return;
    await _loadInitialData();
    if (!mounted) return;
    setState(() => _supplierId = created.id);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _costController.dispose();
    _sellController.dispose();
    _stockController.dispose();
    _thresholdController.dispose();
    _notesController.dispose();
    for (final v in _variantDrafts) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;
    final sell = double.tryParse(_sellController.text.trim()) ?? 0.0;
    final stock = int.tryParse(_stockController.text.trim()) ?? 0;
    final threshold = int.tryParse(_thresholdController.text.trim()) ?? 3;

    final product = Product(
      id: _productId,
      name: _nameController.text.trim(),
      category: _category,
      unit: _unitController.text.trim().isEmpty
          ? 'product_unit_default'.i18n()
          : _unitController.text.trim(),
      costPrice: cost,
      sellPrice: sell,
      currency: _currency,
      stockQuantity: stock,
      trackStock: _trackStock,
      lowStockThreshold: threshold,
      isActive: _isActive,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      supplierId: _supplierId,
      productType: _productType,
      batchYield:
          _productType == AppConstants.productTypeResale ? 1 : _batchYield,
      templateId:
          _productType == AppConstants.productTypeResale ? null : _templateId,
      reorderCycleDays: _reorderCycleDays,
      isBundle: _isBundle,
      createdAt: widget.productToEdit?.createdAt,
    );

    if (_productType == AppConstants.productTypeManufactured && _recipeModified) {
      await _ingredientRepo.replaceForProduct(_productId, _recipeItems);
    } else if (_productType == AppConstants.productTypeResale) {
      await _ingredientRepo.deleteByProductId(_productId);
    }

    if (_isBundle) {
      await _bundleRepo.replaceForBundle(_productId, _bundleItems);
    } else {
      await _bundleRepo.replaceForBundle(_productId, const []);
    }

    final validVariants = _variantDrafts
        .where((v) => v.nameCtrl.text.trim().isNotEmpty)
        .map(
          (v) => ProductVariant(
            id: v.id,
            productId: _productId,
            variantName: v.nameCtrl.text.trim(),
            sellPrice: double.tryParse(v.sellCtrl.text.trim()),
            stockQuantity: int.tryParse(v.stockCtrl.text.trim()) ?? 0,
          ),
        )
        .toList();
    await _variantRepo.replaceForProduct(_productId, validVariants);

    if (!mounted) return;
    widget.onSave(product);
    Navigator.pop(context);
  }

  String _formatNumber(double value) {
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Future<void> _openPricingHelper() async {
    final result = await PricingHelperSheet.show(
      context,
      currency: _currency,
      productId: widget.productToEdit?.id,
    );
    if (result == null || !mounted) return;
    final (unitCost, suggestedPrice) = result;
    setState(() {
      _costController.text = _formatNumber(unitCost);
      _sellController.text = _formatNumber(suggestedPrice);
    });
  }

  Future<void> _openRecipeBuilder() async {
    final result = await ProductionRecipeBuilderSheet.showForProduct(
      context,
      currency: _currency,
      productId: _productId,
      productName: _nameController.text.trim(),
      initialItems: _recipeItems,
      initialYield: _batchYield,
      initialTemplateId: _templateId,
    );
    if (result == null || !mounted) return;
    setState(() {
      _recipeItems = result.items;
      _batchYield = result.batchYield;
      _templateId = result.templateId;
      _recipeModified = true;
      _costController.text = _formatNumber(result.unitCost);
      if (result.suggestedSellPrice != null &&
          result.suggestedSellPrice! > 0) {
        _sellController.text = _formatNumber(result.suggestedSellPrice!);
      }
    });
  }

  Widget _buildProductTypeSelector() {
    final isManufactured = _productType == AppConstants.productTypeManufactured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'product_type_label'.i18n(),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildTypeChip(
                label: 'product_type_resale'.i18n(),
                icon: Icons.storefront_outlined,
                selected: !isManufactured,
                color: const Color(0xFF0284C7),
                onTap: () => setState(
                  () => _productType = AppConstants.productTypeResale,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildTypeChip(
                label: 'product_type_manufactured'.i18n(),
                icon: Icons.precision_manufacturing_outlined,
                selected: isManufactured,
                color: const Color(0xFF7C3AED),
                onTap: () => setState(
                  () => _productType = AppConstants.productTypeManufactured,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip({
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

  double _calculateBundleComponentsTotal() {
    double total = 0.0;
    final cs = CurrencyService.instance;
    for (final item in _bundleItems) {
      final prod = _catalogProducts.firstWhere(
        (p) => p.id == item.componentProductId,
        orElse: () => Product(id: '', name: '', sellPrice: 0),
      );
      if (prod.id.isEmpty) continue;
      final unitSell = prod.currency == _currency
          ? prod.sellPrice
          : cs.convert(
              amount: prod.sellPrice,
              fromCurrency: prod.currency,
              toCurrency: _currency,
            );
      total += unitSell * item.quantity;
    }
    return total;
  }

  Future<void> _pickBundleComponent() async {
    if (_catalogProducts.isEmpty) {
      AppToast.showInfo(context, 'product_bundle_no_components'.i18n());
      return;
    }
    final picked = await showAppModalSheet<Product>(
      context: context,
      title: 'product_bundle_pick_component'.i18n(),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _catalogProducts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final p = _catalogProducts[idx];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              p.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: CurrencyPriceDisplay(
              amount: p.sellPrice,
              currency: p.currency,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () => Navigator.pop(ctx, p),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final existingIdx = _bundleItems.indexWhere(
        (b) => b.componentProductId == picked.id,
      );
      if (existingIdx >= 0) {
        final existing = _bundleItems[existingIdx];
        _bundleItems[existingIdx] = existing.copyWith(
          quantity: existing.quantity + 1,
        );
      } else {
        _bundleItems.add(
          ProductBundleItem(
            id: const Uuid().v4(),
            bundleProductId: _productId,
            componentProductId: picked.id,
            componentName: picked.name,
            quantity: 1,
          ),
        );
      }
    });
  }

  Widget _buildBundleSection() {
    final componentsTotal = _calculateBundleComponentsTotal();
    final bundleSell = double.tryParse(_sellController.text.trim()) ?? 0.0;
    final savings = componentsTotal - bundleSell;
    final savingsPct = componentsTotal > 0 && savings > 0
        ? (savings / componentsTotal) * 100
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSwitchTile(
            title: 'product_is_bundle_label'.i18n(),
            subtitle: 'product_is_bundle_hint'.i18n(),
            value: _isBundle,
            onChanged: (val) => setState(() => _isBundle = val),
          ),
          if (_isBundle) ...[
            const SizedBox(height: 8),
            if (_bundleItems.isNotEmpty) ...[
              ..._bundleItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.borderDivider),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.componentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            if (item.quantity > 1) {
                              _bundleItems[idx] = item.copyWith(
                                quantity: item.quantity - 1,
                              );
                            } else {
                              _bundleItems.removeAt(idx);
                            }
                          });
                        },
                      ),
                      Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() {
                            _bundleItems[idx] = item.copyWith(
                              quantity: item.quantity + 1,
                            );
                          });
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: AppColors.statusDanger,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          setState(() => _bundleItems.removeAt(idx));
                        },
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            'product_bundle_components_total'.i18n(),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CurrencyPriceDisplay(
                          amount: componentsTotal,
                          currency: _currency,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (bundleSell > 0 && savings > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'product_bundle_savings_label'.trParams({
                                'percent': savingsPct.toStringAsFixed(0),
                              }),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CurrencyPriceDisplay(
                            amount: savings,
                            currency: _currency,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            AppOutlinedButton(
              onPressed: _pickBundleComponent,
              icon: Icons.add_box_outlined,
              label: 'product_bundle_add_component'.i18n(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderSubtle),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 10),
          title: Text(
            'product_variants_section_title'.i18n(),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _variantDrafts.isEmpty
                ? 'product_variants_section_hint'.i18n()
                : 'product_variants_count_fmt'.trParams({
                    'count': _variantDrafts.length.toString(),
                  }),
            style: TextStyle(fontSize: 11, color: context.textSecondary),
          ),
          children: [
            ..._variantDrafts.asMap().entries.map((entry) {
              final idx = entry.key;
              final draft = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.borderDivider),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: draft.nameCtrl,
                            label: 'product_variant_name_label'.i18n(),
                            hint: 'product_variant_name_hint'.i18n(),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.statusDanger,
                          ),
                          onPressed: () {
                            setState(() {
                              final removed = _variantDrafts.removeAt(idx);
                              removed.dispose();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: draft.sellCtrl,
                            label: 'product_variant_sell_optional'.i18n(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: AppFormatters.positiveDecimal(
                              decimalRange: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppTextField(
                            controller: draft.stockCtrl,
                            label: 'product_stock_qty_label'.i18n(),
                            keyboardType: TextInputType.number,
                            inputFormatters: AppFormatters.positiveInteger(
                              maxDigits: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            AppOutlinedButton(
              onPressed: () {
                setState(() {
                  _variantDrafts.add(_VariantDraft(id: const Uuid().v4()));
                });
              },
              icon: Icons.add_rounded,
              label: 'product_variant_add_btn'.i18n(),
            ),
          ],
        ),
        ),
      ),
    );
  }

  String _reorderCycleLabel(int days) {
    switch (days) {
      case 7:
        return 'product_reorder_cycle_7'.i18n();
      case 14:
        return 'product_reorder_cycle_14'.i18n();
      case 30:
        return 'product_reorder_cycle_30'.i18n();
      case 0:
      default:
        return 'product_reorder_cycle_off'.i18n();
    }
  }

  Widget _buildReorderCycleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'product_reorder_cycle_label'.i18n(),
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'product_reorder_cycle_hint'.i18n(),
          style: TextStyle(
            fontSize: 11,
            color: context.textSecondary.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: AppConstants.reorderCyclePresets.map((days) {
            final isSelected = _reorderCycleDays == days;
            return ChoiceChip(
              label: Text(_reorderCycleLabel(days)),
              selected: isSelected,
              selectedColor: AppColors.primaryBlue.withValues(alpha: 0.16),
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primaryBlue
                    : context.textPrimary,
              ),
              onSelected: (_) => setState(() => _reorderCycleDays = days),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final multiCurrencyEnabled =
        PreferencesService.instance.isMultiCurrencyEnabled();

    return SingleChildScrollView(
      child: Form(
        key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _nameController,
            label: 'product_name_label'.i18n(),
            hint: 'product_name_hint'.i18n(),
            prefixIcon: Icons.inventory_2_outlined,
            validator: AppValidators.itemName,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: AppDropdownField<String>(
                  label: 'product_category_label'.i18n(),
                  value: _category,
                  items: AppConstants.productCategories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c.i18n())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _category = val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: AppTextField(
                  controller: _unitController,
                  label: 'product_unit_label'.i18n(),
                  hint: 'product_unit_default'.i18n(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildProductTypeSelector(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppDropdownField<String?>(
                  label: 'product_supplier_label'.i18n(),
                  value: _suppliers.any((s) => s.id == _supplierId)
                      ? _supplierId
                      : null,
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
          InkWell(
            onTap: _productType == AppConstants.productTypeManufactured
                ? _openRecipeBuilder
                : _openPricingHelper,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (_productType == AppConstants.productTypeManufactured
                        ? const Color(0xFF7C3AED)
                        : AppColors.primaryBlue)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_productType == AppConstants.productTypeManufactured
                          ? const Color(0xFF7C3AED)
                          : AppColors.primaryBlue)
                      .withValues(alpha: 0.28),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _productType == AppConstants.productTypeManufactured
                        ? Icons.precision_manufacturing_outlined
                        : Icons.calculate_outlined,
                    color: _productType == AppConstants.productTypeManufactured
                        ? const Color(0xFF7C3AED)
                        : AppColors.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _productType == AppConstants.productTypeManufactured
                              ? 'mfg_recipe_builder_title'.i18n()
                              : 'pricing_calc_title'.i18n(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _productType ==
                                    AppConstants.productTypeManufactured
                                ? const Color(0xFF7C3AED)
                                : AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          _productType == AppConstants.productTypeManufactured
                              ? (_recipeItems.isEmpty
                                  ? 'mfg_recipe_builder_subtitle'.i18n()
                                  : 'mfg_recipe_summary_fmt'.trParams({
                                      'items': _recipeItems.length.toString(),
                                      'yield': _batchYield.toString(),
                                    }))
                              : 'pricing_calc_subtitle'.i18n(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _productType == AppConstants.productTypeManufactured
                        ? const Color(0xFF7C3AED)
                        : AppColors.primaryBlue,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _costController,
                  label: 'product_cost_optional_label'.i18n(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: _sellController,
                  label: 'product_sell_price_clean_label'.i18n(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
                  onChanged: (_) {
                    if (_isBundle) setState(() {});
                  },
                  validator: (val) {
                    final parsed = double.tryParse(val?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'product_sell_price_required'.i18n();
                    }
                    return null;
                  },
                ),
              ),
              if (multiCurrencyEnabled) ...[
                const SizedBox(width: 8),
                Expanded(
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
          const SizedBox(height: 12),
          AppSwitchTile(
            title: 'product_track_stock_label'.i18n(),
            subtitle: 'product_track_stock_hint'.i18n(),
            value: _trackStock,
            onChanged: (val) => setState(() => _trackStock = val),
          ),
          if (_trackStock) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _stockController,
                    label: 'product_stock_qty_label'.i18n(),
                    keyboardType: TextInputType.number,
                    inputFormatters: AppFormatters.positiveInteger(maxDigits: 5),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppTextField(
                    controller: _thresholdController,
                    label: 'product_low_stock_threshold'.i18n(),
                    keyboardType: TextInputType.number,
                    inputFormatters: AppFormatters.positiveInteger(maxDigits: 4),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _buildBundleSection(),
          const SizedBox(height: 12),
          _buildVariantsSection(),
          const SizedBox(height: 12),
          _buildReorderCycleSelector(),
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
