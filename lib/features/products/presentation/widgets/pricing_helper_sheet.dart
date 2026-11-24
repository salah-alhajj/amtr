import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product_ingredient.dart';
import '../../data/product_ingredient_repository.dart';
import '../../domain/pricing_calculator_service.dart';

class _IngredientRow {
  final String id;
  final TextEditingController nameController;
  final TextEditingController costController;

  _IngredientRow({
    required this.id,
    String name = '',
    String cost = '',
  })  : nameController = TextEditingController(text: name),
        costController = TextEditingController(text: cost);

  void dispose() {
    nameController.dispose();
    costController.dispose();
  }
}

/// نافذة حاسبة تسعير الوصفة والمنتج لحساب تكلفة الحبة وسعر البيع المقترح
class PricingHelperSheet extends StatefulWidget {
  final String currency;
  final String? productId;

  const PricingHelperSheet({
    super.key,
    required this.currency,
    this.productId,
  });

  static Future<(double unitCost, double suggestedPrice)?> show(
    BuildContext context, {
    required String currency,
    String? productId,
  }) {
    return showAppModalSheet<(double unitCost, double suggestedPrice)>(
      context: context,
      title: 'pricing_calc_title'.i18n(),
      subtitle: 'pricing_calc_subtitle'.i18n(),
      child: PricingHelperSheet(
        currency: currency,
        productId: productId,
      ),
    );
  }

  @override
  State<PricingHelperSheet> createState() => _PricingHelperSheetState();
}

class _PricingHelperSheetState extends State<PricingHelperSheet> {
  static const List<double> _marginPresets = [30, 50, 80, 100];

  final _calculator = const PricingCalculatorService();
  final _repo = ProductIngredientRepository();
  final _uuid = const Uuid();

  final List<_IngredientRow> _rows = [];
  late final TextEditingController _yieldController;
  int _yieldCount = 1;
  double _marginPercent = 50;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _yieldController = TextEditingController(text: '1');
    if (widget.productId != null && widget.productId!.isNotEmpty) {
      _loadSavedIngredients(widget.productId!);
    } else {
      _addRow();
    }
  }

  Future<void> _loadSavedIngredients(String productId) async {
    setState(() => _isLoading = true);
    try {
      final saved = await _repo.getByProductId(productId);
      if (!mounted) return;
      for (final row in _rows) {
        row.dispose();
      }
      _rows.clear();

      if (saved.isNotEmpty) {
        _yieldCount = saved.first.yieldCount > 0 ? saved.first.yieldCount : 1;
        _yieldController.text = _yieldCount.toString();
        for (final item in saved) {
          _rows.add(
            _IngredientRow(
              id: item.id,
              name: item.name,
              cost: item.cost > 0
                  ? (item.cost == item.cost.roundToDouble()
                      ? item.cost.toStringAsFixed(0)
                      : item.cost.toString())
                  : '',
            ),
          );
        }
      } else {
        _addRow(notify: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addRow({bool notify = true}) {
    _rows.add(_IngredientRow(id: _uuid.v4()));
    if (notify && mounted) setState(() {});
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      _rows[index].nameController.clear();
      _rows[index].costController.clear();
      setState(() {});
      return;
    }
    final removed = _rows.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  void _updateYield(int nextYield) {
    final safe = nextYield < 1 ? 1 : nextYield;
    _yieldCount = safe;
    _yieldController.text = safe.toString();
    setState(() {});
  }

  PricingResult _compute() {
    final costs = _rows
        .map((r) => double.tryParse(r.costController.text.trim()) ?? 0.0)
        .toList();
    return _calculator.calculate(
      ingredientCosts: costs,
      yieldCount: _yieldCount,
      marginPercent: _marginPercent,
      currency: widget.currency,
    );
  }

  Future<void> _applyToProduct() async {
    final result = _compute();
    if (widget.productId != null && widget.productId!.isNotEmpty) {
      setState(() => _isSaving = true);
      try {
        final items = <ProductIngredient>[];
        for (final row in _rows) {
          final name = row.nameController.text.trim();
          final cost = double.tryParse(row.costController.text.trim()) ?? 0.0;
          if (name.isNotEmpty || cost > 0) {
            items.add(
              ProductIngredient(
                id: row.id,
                productId: widget.productId!,
                name: name.isEmpty ? 'pricing_ingredient_cost'.i18n() : name,
                cost: cost,
                currency: widget.currency,
                yieldCount: _yieldCount,
              ),
            );
          }
        }
        await _repo.replaceForProduct(widget.productId!, items);
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    }

    if (!mounted) return;
    Navigator.pop(context, (result.unitCost, result.suggestedSellPrice));
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _yieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = CurrencyService.instance;
    final result = _compute();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...List.generate(_rows.length, (index) {
                    final row = _rows[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: AppTextField(
                              controller: row.nameController,
                              hint: 'pricing_ingredient_name'.i18n(),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: row.costController,
                              hint: 'pricing_ingredient_cost'.i18n(),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters:
                                  AppFormatters.positiveDecimal(decimalRange: 2),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.statusDanger,
                              size: 20,
                            ),
                            onPressed: () => _removeRow(index),
                            tooltip: 'common_delete'.i18n(),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _addRow(),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: Text('pricing_add_ingredient'.i18n()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
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
                              setState(() {
                                _yieldCount = parsed < 1 ? 1 : parsed;
                              });
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
                  const SizedBox(height: 12),
                  Text(
                    'pricing_margin_label'.i18n(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _marginPresets.map((preset) {
                      final selected = _marginPercent == preset;
                      return ChoiceChip(
                        label: Text('+${preset.toInt()}%'),
                        selected: selected,
                        selectedColor:
                            AppColors.primaryBlue.withValues(alpha: 0.16),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: selected
                              ? AppColors.primaryBlue
                              : context.textPrimary,
                        ),
                        onSelected: (_) {
                          setState(() => _marginPercent = preset);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.08),
                    child: Column(
                      children: [
                        _buildPreviewRow(
                          context,
                          label: 'pricing_unit_cost_label'.i18n(),
                          value: cs.formatAmount(
                            result.unitCost,
                            currencyCode: widget.currency,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildPreviewRow(
                          context,
                          label: 'pricing_suggested_price'.i18n(),
                          value: cs.formatAmount(
                            result.suggestedSellPrice,
                            currencyCode: widget.currency,
                          ),
                          valueColor: AppColors.primaryBlue,
                          isBold: true,
                        ),
                        const SizedBox(height: 8),
                        _buildPreviewRow(
                          context,
                          label: 'pricing_unit_profit'.i18n(),
                          value: cs.formatAmount(
                            result.unitProfit,
                            currencyCode: widget.currency,
                          ),
                          valueColor: AppColors.primaryGreen,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppPrimaryButton(
                    label: 'pricing_apply_to_product'.i18n(),
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: AppColors.primaryGreen,
                    isLoading: _isSaving,
                    onPressed: _applyToProduct,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPreviewRow(
    BuildContext context, {
    required String label,
    required String value,
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
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: context.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: isBold ? 17 : 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
