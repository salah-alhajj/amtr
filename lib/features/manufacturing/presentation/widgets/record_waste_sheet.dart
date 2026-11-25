import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/waste_log.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../data/repositories/raw_material_repository.dart';
import '../../data/repositories/waste_log_repository.dart';

/// ورقة سفلية سريعة (3 ثوانٍ) لتسجيل الهالك والتالف لمنتج أو مادة خام
class RecordWasteSheet extends StatefulWidget {
  const RecordWasteSheet({super.key});

  static Future<WasteLog?> show(BuildContext context) {
    return showModalBottomSheet<WasteLog>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RecordWasteSheet(),
    );
  }

  @override
  State<RecordWasteSheet> createState() => _RecordWasteSheetState();
}

class _RecordWasteSheetState extends State<RecordWasteSheet> {
  final _productRepo = ProductRepositoryImpl();
  final _materialRepo = RawMaterialRepository();
  final _wasteRepo = WasteLogRepository();

  final _qtyController = TextEditingController(text: '1');
  final _lossController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  String _itemType = 'product';
  String? _selectedItemId;
  String _selectedReason = AppConstants.wasteReasonSpoiled;
  bool _deductStock = true;
  bool _lossManuallyEdited = false;
  bool _isLoadingItems = true;
  bool _isSubmitting = false;
  String? _errorText;

  List<Product> _products = const [];
  List<RawMaterial> _materials = const [];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    try {
      final results = await Future.wait([
        _productRepo.getAllProducts(),
        _materialRepo.getAll(),
      ]);
      if (!mounted) return;
      final prods = results[0] as List<Product>;
      final mats = results[1] as List<RawMaterial>;
      setState(() {
        _products = prods;
        _materials = mats;
        _isLoadingItems = false;
        if (_itemType == 'product' && _products.isNotEmpty) {
          _selectedItemId = _products.first.id;
        } else if (_itemType == 'material' && _materials.isNotEmpty) {
          _selectedItemId = _materials.first.id;
        }
      });
      _recomputeEstimatedLoss();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingItems = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _lossController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Product? get _selectedProduct {
    if (_itemType != 'product' || _selectedItemId == null) return null;
    for (final p in _products) {
      if (p.id == _selectedItemId) return p;
    }
    return null;
  }

  RawMaterial? get _selectedMaterial {
    if (_itemType != 'material' || _selectedItemId == null) return null;
    for (final m in _materials) {
      if (m.id == _selectedItemId) return m;
    }
    return null;
  }

  void _recomputeEstimatedLoss() {
    if (_lossManuallyEdited) return;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (qty <= 0) {
      _lossController.text = '0';
      return;
    }
    final cs = CurrencyService.instance;
    double unitCostYer = 0.0;
    if (_itemType == 'product') {
      final prod = _selectedProduct;
      if (prod != null) {
        unitCostYer = cs.toBaseYer(prod.costPrice, prod.currency);
      }
    } else {
      final mat = _selectedMaterial;
      if (mat != null) {
        unitCostYer = cs.toBaseYer(mat.unitCost, mat.currency);
      }
    }
    final est = qty * unitCostYer;
    _lossController.text =
        est == est.roundToDouble() ? est.toStringAsFixed(0) : est.toStringAsFixed(2);
  }

  void _switchItemType(String type) {
    if (_itemType == type) return;
    setState(() {
      _itemType = type;
      _lossManuallyEdited = false;
      _errorText = null;
      if (type == 'product') {
        _selectedItemId = _products.isNotEmpty ? _products.first.id : null;
      } else {
        _selectedItemId = _materials.isNotEmpty ? _materials.first.id : null;
      }
    });
    _recomputeEstimatedLoss();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final qty = double.tryParse(_qtyController.text.trim()) ?? 0.0;
    if (_selectedItemId == null) {
      setState(() => _errorText = 'waste_error_select_item'.i18n());
      return;
    }
    if (qty <= 0) {
      setState(() => _errorText = 'waste_error_invalid_qty'.i18n());
      return;
    }

    final lossYer =
        (double.tryParse(_lossController.text.trim()) ?? 0.0).clamp(0.0, 999999999.0);
    final notesText = _notesController.text.trim();

    String itemName = '';
    String unit = 'حبة';
    if (_itemType == 'product') {
      final prod = _selectedProduct;
      if (prod == null) {
        setState(() => _errorText = 'waste_error_select_item'.i18n());
        return;
      }
      itemName = prod.name;
      unit = prod.unit;
    } else {
      final mat = _selectedMaterial;
      if (mat == null) {
        setState(() => _errorText = 'waste_error_select_item'.i18n());
        return;
      }
      itemName = mat.name;
      unit = mat.unit;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final log = WasteLog(
        id: const Uuid().v4(),
        itemType: _itemType,
        itemId: _selectedItemId!,
        itemName: itemName,
        quantity: qty,
        unit: unit,
        estimatedLossYer: lossYer,
        reason: _selectedReason,
        notes: notesText.isEmpty ? null : notesText,
      );
      final saved = await _wasteRepo.recordWaste(log, deductStock: _deductStock);
      if (!mounted) return;
      AppToast.showSuccess(context, 'waste_recorded_success'.i18n());
      Navigator.of(context).pop(saved);
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
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    final hasItems =
        _itemType == 'product' ? _products.isNotEmpty : _materials.isNotEmpty;

    return AppModalSheet(
      title: 'waste_sheet_title'.i18n(),
      subtitle: 'waste_sheet_subtitle'.i18n(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              // محدد نوع العنصر بأسلوب آبل الأنيق
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.borderSubtle, width: 0.8),
                ),
                child: Row(
                  children: [
                    _buildTypeSegment(
                      type: 'product',
                      icon: Icons.inventory_2_outlined,
                      label: 'waste_type_product'.i18n(),
                    ),
                    const SizedBox(width: 4),
                    _buildTypeSegment(
                      type: 'material',
                      icon: Icons.science_outlined,
                      label: 'waste_type_material'.i18n(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingItems)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator.adaptive()),
                )
              else if (!hasItems)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _itemType == 'product'
                        ? 'products_empty_title'.i18n()
                        : 'materials_empty_title'.i18n(),
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  ),
                )
              else
                AppDropdownField<String>(
                  label: _itemType == 'product'
                      ? 'waste_select_product'.i18n()
                      : 'waste_select_material'.i18n(),
                  value: _selectedItemId,
                  items: _itemType == 'product'
                      ? _products
                          .map(
                            (p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(
                                '${p.name} (${p.stockQuantity} ${p.unit})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList()
                      : _materials
                          .map(
                            (m) => DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(
                                '${m.name} (${m.stockQuantity} ${m.unit})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedItemId = val;
                      _lossManuallyEdited = false;
                      _errorText = null;
                    });
                    _recomputeEstimatedLoss();
                  },
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _qtyController,
                      label: 'waste_qty_label'.i18n(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recomputeEstimatedLoss(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppTextField(
                      controller: _lossController,
                      label: 'waste_estimated_loss_label'.i18n(),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _lossManuallyEdited = true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'waste_reason_label'.i18n(),
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
                children: AppConstants.wasteReasons.map((reason) {
                  final selected = _selectedReason == reason;
                  return InkWell(
                    onTap: () => setState(() => _selectedReason = reason),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.statusWarning.withValues(alpha: 0.14)
                            : context.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? AppColors.statusWarning
                              : context.borderSubtle,
                          width: selected ? 1.4 : 0.8,
                        ),
                      ),
                      child: Text(
                        AppConstants.getWasteReasonLabel(reason),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              selected ? FontWeight.bold : FontWeight.w500,
                          color: selected
                              ? AppColors.statusWarning
                              : context.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              AppSwitchTile(
                title: 'waste_deduct_stock_label'.i18n(),
                value: _deductStock,
                onChanged: (v) => setState(() => _deductStock = v),
              ),
              const SizedBox(height: 6),
              AppTextField(
                controller: _notesController,
                label: 'common_notes'.i18n(),
                maxLines: 2,
              ),
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
                label: 'waste_submit_btn'.i18n(),
                icon: Icons.delete_sweep_outlined,
                backgroundColor: AppColors.statusDanger,
                isLoading: _isSubmitting,
                onPressed: hasItems && !_isSubmitting ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment({
    required String type,
    required IconData icon,
    required String label,
  }) {
    final active = _itemType == type;
    final color =
        type == 'product' ? AppColors.primaryBlue : AppColors.vibrantTeal;
    return Expanded(
      child: InkWell(
        onTap: () => _switchItemType(type),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? context.surfaceCard : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active
                ? Border.all(color: color.withValues(alpha: 0.45), width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? color : context.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.bold : FontWeight.w500,
                    color: active ? color : context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
