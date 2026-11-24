import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/manufacturing_template.dart';
import '../../../../models/product.dart';
import '../../../../models/product_ingredient.dart';
import '../../../../models/raw_material.dart';
import '../../../products/data/product_ingredient_repository.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../products/domain/pricing_calculator_service.dart';
import '../../data/repositories/manufacturing_template_repository.dart';
import '../../data/repositories/raw_material_repository.dart';
import 'add_edit_material_sheet.dart';

/// نتيجة بناء وصفة التصنيع والتكاليف الإنتاجية للمنتج
class ProductionRecipeResult {
  final List<ProductIngredient> items;
  final int batchYield;
  final double batchTotalCost;
  final double unitCost;
  final double? suggestedSellPrice;
  final String? templateId;

  const ProductionRecipeResult({
    required this.items,
    required this.batchYield,
    required this.batchTotalCost,
    required this.unitCost,
    this.suggestedSellPrice,
    this.templateId,
  });
}

class _RecipeLineController {
  final String id;
  final String itemType;
  final String? materialId;
  final String? unit;
  final TextEditingController nameController;
  final TextEditingController qtyController;
  final TextEditingController unitCostController;

  _RecipeLineController({
    required this.id,
    required this.itemType,
    this.materialId,
    this.unit,
    String name = '',
    double quantity = 1.0,
    double unitCost = 0.0,
  })  : nameController = TextEditingController(text: name),
        qtyController = TextEditingController(
          text: quantity == quantity.roundToDouble()
              ? quantity.toStringAsFixed(0)
              : quantity.toString(),
        ),
        unitCostController = TextEditingController(
          text: unitCost > 0
              ? (unitCost == unitCost.roundToDouble()
                  ? unitCost.toStringAsFixed(0)
                  : unitCost.toString())
              : '',
        );

  double get quantity =>
      double.tryParse(qtyController.text.trim()) ?? (isMaterial ? 0.0 : 1.0);

  double get unitCost => double.tryParse(unitCostController.text.trim()) ?? 0.0;

  double get lineTotal => isMaterial ? (quantity * unitCost) : unitCost;

  bool get isMaterial => itemType == AppConstants.costItemMaterial;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    unitCostController.dispose();
  }
}

/// نافذة بناء وصفة التصنيع (المواد والمقادير + التكاليف الإنتاجية + قوالب قابلة لإعادة الاستخدام)
class ProductionRecipeBuilderSheet extends StatefulWidget {
  final String currency;
  final String? productId;
  final String? productName;
  final List<ProductIngredient> initialItems;
  final int initialYield;
  final String? initialTemplateId;
  final ManufacturingTemplate? templateToEdit;

  const ProductionRecipeBuilderSheet({
    super.key,
    required this.currency,
    this.productId,
    this.productName,
    this.initialItems = const [],
    this.initialYield = 1,
    this.initialTemplateId,
    this.templateToEdit,
  });

  static Future<ProductionRecipeResult?> showForProduct(
    BuildContext context, {
    required String currency,
    required String productId,
    String? productName,
    List<ProductIngredient> initialItems = const [],
    int initialYield = 1,
    String? initialTemplateId,
  }) {
    return showAppModalSheet<ProductionRecipeResult>(
      context: context,
      title: 'mfg_recipe_builder_title'.i18n(),
      subtitle: 'mfg_recipe_builder_subtitle'.i18n(),
      child: ProductionRecipeBuilderSheet(
        currency: currency,
        productId: productId,
        productName: productName,
        initialItems: initialItems,
        initialYield: initialYield,
        initialTemplateId: initialTemplateId,
      ),
    );
  }

  static Future<ManufacturingTemplate?> showForTemplate(
    BuildContext context, {
    required String currency,
    ManufacturingTemplate? templateToEdit,
  }) async {
    final result = await showAppModalSheet<ManufacturingTemplate>(
      context: context,
      title: templateToEdit == null
          ? 'template_add_title'.i18n()
          : 'template_edit_title'.i18n(),
      subtitle: 'mfg_recipe_builder_subtitle'.i18n(),
      child: ProductionRecipeBuilderSheet(
        currency: templateToEdit?.currency ?? currency,
        initialYield: templateToEdit?.yieldCount ?? 1,
        templateToEdit: templateToEdit,
      ),
    );
    return result;
  }

  @override
  State<ProductionRecipeBuilderSheet> createState() =>
      _ProductionRecipeBuilderSheetState();
}

class _ProductionRecipeBuilderSheetState
    extends State<ProductionRecipeBuilderSheet> {
  static const List<double> _marginPresets = [30, 50, 80, 100];

  final _uuid = const Uuid();
  final _calculator = const PricingCalculatorService();
  final _materialRepo = RawMaterialRepository();
  final _templateRepo = ManufacturingTemplateRepository();
  final _ingredientRepo = ProductIngredientRepository();
  final _productRepo = ProductRepositoryImpl();

  final List<_RecipeLineController> _lines = [];
  late final TextEditingController _yieldController;
  late final TextEditingController _templateNameController;
  late int _yieldCount;
  double? _selectedMarginPercent;
  bool _saveAsTemplate = false;
  String? _selectedTemplateId;

  List<RawMaterial> _materials = const [];
  List<ManufacturingTemplate> _templates = const [];
  List<Product> _manufacturedProducts = const [];
  bool _isSaving = false;

  bool get _isTemplateMode => widget.templateToEdit != null || widget.productId == null;

  @override
  void initState() {
    super.initState();
    _yieldCount = widget.templateToEdit?.yieldCount ??
        (widget.initialYield > 0 ? widget.initialYield : 1);
    _yieldController = TextEditingController(text: _yieldCount.toString());
    _templateNameController = TextEditingController(
      text: widget.templateToEdit?.name ?? widget.productName ?? '',
    );
    _selectedTemplateId = widget.initialTemplateId ?? widget.templateToEdit?.id;

    if (widget.templateToEdit != null) {
      for (final item in widget.templateToEdit!.items) {
        final rawCost = item.unitCost > 0 ? item.unitCost : item.totalCost;
        final srcCurrency = item.currency.isNotEmpty
            ? item.currency
            : widget.templateToEdit!.currency;
        _lines.add(
          _RecipeLineController(
            id: item.id,
            itemType: item.itemType,
            materialId: item.materialId,
            unit: item.unit,
            name: item.name,
            quantity: item.quantity,
            unitCost: _convertToTargetCurrency(rawCost, srcCurrency),
          ),
        );
      }
    } else if (widget.initialItems.isNotEmpty) {
      for (final item in widget.initialItems) {
        final uCost = item.unitCost > 0
            ? item.unitCost
            : (item.quantity > 0 ? item.cost / item.quantity : item.cost);
        _lines.add(
          _RecipeLineController(
            id: item.id,
            itemType: item.itemType,
            materialId: item.materialId,
            unit: item.unit,
            name: item.name,
            quantity: item.quantity,
            unitCost: _convertToTargetCurrency(uCost, item.currency),
          ),
        );
      }
    }

    _loadLibraries();
  }

  double _convertToTargetCurrency(double amount, String fromCurrency) {
    if (amount <= 0) return 0.0;
    final converted = CurrencyService.instance.convert(
      amount: amount,
      fromCurrency: fromCurrency,
      toCurrency: widget.currency,
    );
    return double.parse(converted.toStringAsFixed(2));
  }

  Future<void> _loadLibraries() async {
    try {
      final results = await Future.wait([
        _materialRepo.getAll(),
        _templateRepo.getAllTemplates(),
        _productRepo.getAllProducts(),
      ]);
      if (!mounted) return;
      final products = (results[2] as List<Product>)
          .where((p) => p.isManufactured && p.id != widget.productId)
          .toList();
      setState(() {
        _materials = results[0] as List<RawMaterial>;
        _templates = results[1] as List<ManufacturingTemplate>;
        _manufacturedProducts = products;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    _yieldController.dispose();
    _templateNameController.dispose();
    super.dispose();
  }

  void _addMaterialLine({
    RawMaterial? material,
    String name = '',
    double quantity = 1.0,
    double unitCost = 0.0,
    String? unit,
  }) {
    final resolvedUnitCost = material != null
        ? _convertToTargetCurrency(material.unitCost, material.currency)
        : unitCost;
    setState(() {
      _lines.add(
        _RecipeLineController(
          id: _uuid.v4(),
          itemType: AppConstants.costItemMaterial,
          materialId: material?.id,
          unit: material?.unit ?? unit,
          name: material?.name ?? name,
          quantity: quantity,
          unitCost: resolvedUnitCost,
        ),
      );
    });
  }

  void _addOverheadLine(String itemType) {
    setState(() {
      _lines.add(
        _RecipeLineController(
          id: _uuid.v4(),
          itemType: itemType,
          name: AppConstants.getProductionCostItemTypeLabel(itemType),
          quantity: 1.0,
          unitCost: 0.0,
        ),
      );
    });
  }

  void _removeLine(int index) {
    final removed = _lines.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _updateYield(int nextYield) {
    final safe = nextYield < 1 ? 1 : nextYield;
    _yieldCount = safe;
    _yieldController.text = safe.toString();
    setState(() {});
  }

  Future<void> _pickFromMaterialsLibrary() async {
    if (_materials.isEmpty) {
      final created = await AddEditMaterialSheet.show(
        context,
        onSave: (m) async {
          await _materialRepo.save(m);
          DataSyncBus.instance.notify(DataDomain.materials);
        },
      );
      if (created != null && mounted) {
        await _loadLibraries();
        _addMaterialLine(material: created);
      }
      return;
    }

    final picked = await showAppModalSheet<RawMaterial>(
      context: context,
      title: 'mfg_pick_material'.i18n(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._materials.map(
            (m) => ListTile(
              leading: const Icon(Icons.science_outlined,
                  color: AppColors.vibrantTeal),
              title: Text(m.name),
              subtitle: Text(
                '${m.unit} • ${CurrencyService.instance.formatAmount(m.unitCost, currencyCode: m.currency)}',
              ),
              onTap: () => Navigator.pop(context, m),
            ),
          ),
          const SizedBox(height: 8),
          AppOutlinedButton(
            label: 'material_add_title'.i18n(),
            icon: Icons.add,
            onPressed: () async {
              Navigator.pop(context);
              final created = await AddEditMaterialSheet.show(
                context,
                onSave: (m) async {
                  await _materialRepo.save(m);
                  DataSyncBus.instance.notify(DataDomain.materials);
                },
              );
              if (created != null && mounted) {
                await _loadLibraries();
                _addMaterialLine(material: created);
              }
            },
          ),
        ],
      ),
    );
    if (picked != null && mounted) {
      _addMaterialLine(material: picked);
    }
  }

  Future<void> _importFromTemplate() async {
    if (_templates.isEmpty) {
      AppToast.showInfo(context, 'template_none_available'.i18n());
      return;
    }

    final picked = await showAppModalSheet<ManufacturingTemplate>(
      context: context,
      title: 'mfg_import_template'.i18n(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _templates
            .map(
              (t) => ListTile(
                leading: const Icon(Icons.auto_awesome_mosaic_outlined,
                    color: AppColors.primaryBlue),
                title: Text(t.name),
                subtitle: Text(
                  '${'template_yield_fmt'.trParams({'count': t.yieldCount.toString()})} • ${CurrencyService.instance.formatAmount(t.totalBatchCost, currencyCode: t.currency)}',
                ),
                onTap: () => Navigator.pop(context, t),
              ),
            )
            .toList(),
      ),
    );

    if (picked == null || !mounted) return;
    setState(() {
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
      for (final item in picked.items) {
        final rawUnitCost = item.unitCost > 0 ? item.unitCost : item.totalCost;
        final srcCurrency =
            item.currency.isNotEmpty ? item.currency : picked.currency;
        _lines.add(
          _RecipeLineController(
            id: _uuid.v4(),
            itemType: item.itemType,
            materialId: item.materialId,
            unit: item.unit,
            name: item.name,
            quantity: item.quantity,
            unitCost: _convertToTargetCurrency(rawUnitCost, srcCurrency),
          ),
        );
      }
      _selectedTemplateId = picked.id;
      _updateYield(picked.yieldCount);
    });
    AppToast.showSuccess(context, 'mfg_template_applied'.i18n());
  }

  Future<void> _cloneFromManufacturedProduct() async {
    if (_manufacturedProducts.isEmpty) {
      AppToast.showInfo(context, 'mfg_no_clone_products'.i18n());
      return;
    }

    final picked = await showAppModalSheet<Product>(
      context: context,
      title: 'mfg_clone_from_product'.i18n(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _manufacturedProducts
            .map(
              (p) => ListTile(
                leading: const Icon(Icons.content_copy_rounded,
                    color: AppColors.primaryBlue),
                title: Text(p.name),
                subtitle: Text(
                  '${'pricing_unit_cost_label'.i18n()}: ${CurrencyService.instance.formatAmount(p.costPrice, currencyCode: p.currency)}',
                ),
                onTap: () => Navigator.pop(context, p),
              ),
            )
            .toList(),
      ),
    );
    if (picked == null || !mounted) return;

    final savedItems = await _ingredientRepo.getByProductId(picked.id);
    if (!mounted) return;
    setState(() {
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
      for (final item in savedItems) {
        final uCost = item.unitCost > 0
            ? item.unitCost
            : (item.quantity > 0 ? item.cost / item.quantity : item.cost);
        final srcCurrency =
            item.currency.isNotEmpty ? item.currency : picked.currency;
        _lines.add(
          _RecipeLineController(
            id: _uuid.v4(),
            itemType: item.itemType,
            materialId: item.materialId,
            unit: item.unit,
            name: item.name,
            quantity: item.quantity,
            unitCost: _convertToTargetCurrency(uCost, srcCurrency),
          ),
        );
      }
      _updateYield(picked.batchYield > 0 ? picked.batchYield : 1);
    });
    AppToast.showSuccess(context, 'mfg_template_applied'.i18n());
  }

  double get _materialsTotal => _lines
      .where((l) => l.isMaterial)
      .fold(0.0, (sum, l) => sum + l.lineTotal);

  double get _overheadTotal => _lines
      .where((l) => !l.isMaterial)
      .fold(0.0, (sum, l) => sum + l.lineTotal);

  double get _batchTotal => _materialsTotal + _overheadTotal;

  double get _unitCost => _yieldCount > 0 ? _batchTotal / _yieldCount : _batchTotal;

  PricingResult? get _pricingResult {
    if (_selectedMarginPercent == null) return null;
    return _calculator.calculate(
      ingredientCosts: _lines.map((l) => l.lineTotal).toList(),
      yieldCount: _yieldCount,
      marginPercent: _selectedMarginPercent!,
      currency: widget.currency,
    );
  }

  Future<void> _save() async {
    if (_isTemplateMode && _templateNameController.text.trim().isEmpty) {
      AppToast.showError(context, 'template_name_required'.i18n());
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isTemplateMode) {
        final tId = widget.templateToEdit?.id ?? _uuid.v4();
        final items = _lines
            .where((l) => l.nameController.text.trim().isNotEmpty || l.lineTotal > 0)
            .map(
              (l) => ManufacturingTemplateItem(
                id: l.id,
                templateId: tId,
                itemType: l.itemType,
                materialId: l.materialId,
                name: l.nameController.text.trim().isEmpty
                    ? AppConstants.getProductionCostItemTypeLabel(l.itemType)
                    : l.nameController.text.trim(),
                quantity: l.isMaterial ? l.quantity : 1.0,
                unit: l.unit,
                unitCost: l.unitCost,
                currency: widget.currency,
              ),
            )
            .toList();

        final template = ManufacturingTemplate(
          id: tId,
          name: _templateNameController.text.trim(),
          yieldCount: _yieldCount,
          currency: widget.currency,
          items: items,
          createdAt: widget.templateToEdit?.createdAt,
        );
        await _templateRepo.saveTemplate(template);
        DataSyncBus.instance.notify(DataDomain.materials);
        if (!mounted) return;
        Navigator.pop(context, template);
        return;
      }

      String? templateId = _selectedTemplateId;
      final productId = widget.productId!;
      final ingredients = <ProductIngredient>[];
      for (final l in _lines) {
        final name = l.nameController.text.trim();
        final lineCost = l.lineTotal;
        if (name.isEmpty && lineCost <= 0) continue;
        ingredients.add(
          ProductIngredient(
            id: l.id,
            productId: productId,
            name: name.isEmpty
                ? AppConstants.getProductionCostItemTypeLabel(l.itemType)
                : name,
            cost: lineCost,
            currency: widget.currency,
            yieldCount: _yieldCount,
            itemType: l.itemType,
            materialId: l.materialId,
            quantity: l.isMaterial ? l.quantity : 1.0,
            unit: l.unit,
            unitCost: l.unitCost,
          ),
        );
      }

      if (_saveAsTemplate) {
        final tName = _templateNameController.text.trim().isNotEmpty
            ? _templateNameController.text.trim()
            : (widget.productName?.trim().isNotEmpty == true
                ? widget.productName!.trim()
                : 'template_default_name'.i18n());
        final newTemplateId = templateId ?? _uuid.v4();
        final templateItems = ingredients
            .map(
              (ing) => ManufacturingTemplateItem(
                id: _uuid.v4(),
                templateId: newTemplateId,
                itemType: ing.itemType,
                materialId: ing.materialId,
                name: ing.name,
                quantity: ing.quantity,
                unit: ing.unit,
                unitCost: ing.unitCost,
                currency: ing.currency,
              ),
            )
            .toList();
        await _templateRepo.saveTemplate(
          ManufacturingTemplate(
            id: newTemplateId,
            name: tName,
            yieldCount: _yieldCount,
            currency: widget.currency,
            items: templateItems,
          ),
        );
        templateId = newTemplateId;
        DataSyncBus.instance.notify(DataDomain.materials);
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        ProductionRecipeResult(
          items: ingredients,
          batchYield: _yieldCount,
          batchTotalCost: _batchTotal,
          unitCost: _unitCost,
          suggestedSellPrice: _pricingResult?.suggestedSellPrice,
          templateId: templateId,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = CurrencyService.instance;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.80;
    final materialLines = <int>[];
    final overheadLines = <int>[];
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i].isMaterial) {
        materialLines.add(i);
      } else {
        overheadLines.add(i);
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isTemplateMode) ...[
              AppTextField(
                controller: _templateNameController,
                label: 'template_name_label'.i18n(),
                hint: 'template_name_hint'.i18n(),
                prefixIcon: Icons.auto_awesome_mosaic_outlined,
              ),
              const SizedBox(height: 12),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.auto_awesome_mosaic_outlined,
                        size: 16, color: AppColors.primaryBlue),
                    label: Text('mfg_import_template'.i18n(),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: _importFromTemplate,
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.content_copy_rounded,
                        size: 16, color: AppColors.vibrantTeal),
                    label: Text('mfg_clone_from_product'.i18n(),
                        style: const TextStyle(fontSize: 12)),
                    onPressed: _cloneFromManufacturedProduct,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // --- قسم المواد والمقادير ---
            Text(
              'mfg_materials_section'.i18n(),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (materialLines.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'mfg_no_materials_added'.i18n(),
                  style: TextStyle(fontSize: 12, color: context.textSecondary),
                ),
              )
            else
              ...materialLines.map((idx) => _buildMaterialRow(idx, cs)),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.library_add_outlined,
                      size: 16, color: AppColors.vibrantTeal),
                  label: Text('mfg_pick_material'.i18n(),
                      style: const TextStyle(fontSize: 12)),
                  onPressed: _pickFromMaterialsLibrary,
                ),
                ActionChip(
                  avatar: const Icon(Icons.add_circle_outline_rounded,
                      size: 16, color: AppColors.primaryBlue),
                  label: Text('mfg_add_custom_material'.i18n(),
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => _addMaterialLine(),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // --- قسم التكاليف الإنتاجية الأخرى كبنود ---
            Text(
              'mfg_overhead_section'.i18n(),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...overheadLines.map((idx) => _buildOverheadRow(idx)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                AppConstants.costItemPackaging,
                AppConstants.costItemLabor,
                AppConstants.costItemUtilities,
                AppConstants.costItemOverhead,
              ].map((type) {
                return ActionChip(
                  avatar: Icon(
                    Icons.add,
                    size: 15,
                    color: AppConstants.getProductionCostItemTypeColor(type),
                  ),
                  label: Text(
                    AppConstants.getProductionCostItemTypeLabel(type),
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _addOverheadLine(type),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),

            // --- عدد الوحدات المنتجة من الدفعة ---
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'pricing_batch_yield_label'.i18n(),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    onPressed: _yieldCount > 1
                        ? () => _updateYield(_yieldCount - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      controller: _yieldController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters:
                          AppFormatters.positiveInteger(maxDigits: 4),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        final parsed = int.tryParse(val.trim()) ?? 1;
                        setState(() => _yieldCount = parsed < 1 ? 1 : parsed);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    onPressed: () => _updateYield(_yieldCount + 1),
                  ),
                ],
              ),
            ),

            if (!_isTemplateMode) ...[
              const SizedBox(height: 12),
              Text(
                'pricing_margin_label'.i18n(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _marginPresets.map((preset) {
                  final selected = _selectedMarginPercent == preset;
                  return ChoiceChip(
                    label: Text('+${preset.toInt()}%'),
                    selected: selected,
                    selectedColor: AppColors.primaryBlue.withValues(alpha: 0.16),
                    onSelected: (_) {
                      setState(() {
                        _selectedMarginPercent = selected ? null : preset;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              AppSwitchTile(
                title: 'mfg_save_as_template'.i18n(),
                subtitle: 'mfg_save_as_template_hint'.i18n(),
                value: _saveAsTemplate,
                onChanged: (val) => setState(() => _saveAsTemplate = val),
              ),
              if (_saveAsTemplate) ...[
                const SizedBox(height: 8),
                AppTextField(
                  controller: _templateNameController,
                  label: 'template_name_label'.i18n(),
                  hint: 'template_name_hint'.i18n(),
                ),
              ],
            ],

            const SizedBox(height: 12),

            // --- ملخص التكلفة ---
            AppCard(
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.08),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'mfg_materials_cost_total'.i18n(),
                    cs.formatAmount(_materialsTotal, currencyCode: widget.currency),
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'mfg_overhead_cost_total'.i18n(),
                    cs.formatAmount(_overheadTotal, currencyCode: widget.currency),
                  ),
                  const Divider(height: 14),
                  _buildSummaryRow(
                    'mfg_batch_total_cost'.i18n(),
                    cs.formatAmount(_batchTotal, currencyCode: widget.currency),
                    isBold: true,
                  ),
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    'pricing_unit_cost_label'.i18n(),
                    cs.formatAmount(_unitCost, currencyCode: widget.currency),
                    valueColor: AppColors.primaryBlue,
                    isBold: true,
                  ),
                  if (_pricingResult != null) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow(
                      'pricing_suggested_price'.i18n(),
                      cs.formatAmount(
                        _pricingResult!.suggestedSellPrice,
                        currencyCode: widget.currency,
                      ),
                      valueColor: AppColors.primaryGreen,
                      isBold: true,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),
            AppPrimaryButton(
              label: _isTemplateMode
                  ? 'common_save'.i18n()
                  : 'pricing_apply_to_product'.i18n(),
              icon: Icons.check_circle_outline_rounded,
              backgroundColor: AppColors.primaryGreen,
              isLoading: _isSaving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialRow(int index, CurrencyService cs) {
    final line = _lines[index];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: line.nameController,
                  hint: 'pricing_ingredient_name'.i18n(),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.statusDanger,
                  size: 20,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeLine(index),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: line.qtyController,
                  label: line.unit != null
                      ? '${'mfg_qty_label'.i18n()} (${line.unit})'
                      : 'mfg_qty_label'.i18n(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 3),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppTextField(
                  controller: line.unitCostController,
                  label: 'material_unit_cost_label'.i18n(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 2),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cs.formatAmount(line.lineTotal, currencyCode: widget.currency),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverheadRow(int index) {
    final line = _lines[index];
    final color = AppConstants.getProductionCostItemTypeColor(line.itemType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          AppBadge(
            label: AppConstants.getProductionCostItemTypeLabel(line.itemType),
            color: color,
            fontSize: 10,
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 3,
            child: AppTextField(
              controller: line.nameController,
              hint: 'mfg_cost_item_name_hint'.i18n(),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: AppTextField(
              controller: line.unitCostController,
              hint: 'pricing_ingredient_cost'.i18n(),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.statusDanger,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => _removeLine(index),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? context.textPrimary,
          ),
        ),
      ],
    );
  }
}
