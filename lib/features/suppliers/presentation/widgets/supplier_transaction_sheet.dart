import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier_transaction.dart';
import '../../domain/services/supplier_business_service.dart';

/// نتيجة ورقة تسجيل حركة المورد شاملةً التزويد الاختياري للمخزون
class SupplierTransactionResult {
  final SupplierTransaction transaction;
  final String? stockItemType;
  final String? stockItemId;
  final double stockQuantity;

  const SupplierTransactionResult({
    required this.transaction,
    this.stockItemType,
    this.stockItemId,
    this.stockQuantity = 0.0,
  });

  bool get hasStockLink =>
      !transaction.isPayment &&
      stockItemId != null &&
      stockItemId!.isNotEmpty &&
      stockQuantity > 0;
}

/// نافذة تسجيل حركة مالية مع المورد (اشتريت منه: آجل/نقدي، أو سددت له)
class SupplierTransactionSheet extends StatefulWidget {
  final String supplierId;
  final String supplierName;
  final bool isPayment;

  const SupplierTransactionSheet({
    super.key,
    required this.supplierId,
    required this.supplierName,
    required this.isPayment,
  });

  static Future<SupplierTransaction?> show(
    BuildContext context, {
    required String supplierId,
    required String supplierName,
    required bool isPayment,
  }) async {
    final res = await showWithStock(
      context,
      supplierId: supplierId,
      supplierName: supplierName,
      isPayment: isPayment,
    );
    return res?.transaction;
  }

  static Future<SupplierTransactionResult?> showWithStock(
    BuildContext context, {
    required String supplierId,
    required String supplierName,
    required bool isPayment,
  }) {
    return showAppModalSheet<SupplierTransactionResult>(
      context: context,
      title: isPayment
          ? 'supplier_tx_sheet_pay_title'.i18n()
          : 'supplier_tx_sheet_buy_title'.i18n(),
      subtitle: supplierName,
      child: SupplierTransactionSheet(
        supplierId: supplierId,
        supplierName: supplierName,
        isPayment: isPayment,
      ),
    );
  }

  @override
  State<SupplierTransactionSheet> createState() =>
      _SupplierTransactionSheetState();
}

class _SupplierTransactionSheetState extends State<SupplierTransactionSheet> {
  static const Color _creditWarmAmber = Color(0xFFD97706);

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _stockQtyController = TextEditingController(text: '1');
  final SupplierBusinessService _supplierService =
      AppServices.instance.supplierService;

  late String _txType;
  late String _currency;
  DateTime _txDate = DateTime.now();
  String? _receiptPhotoPath;

  bool _linkToStock = false;
  String _stockItemType = 'product';
  String? _selectedStockItemId;
  List<Product> _products = const [];
  List<RawMaterial> _materials = const [];

  @override
  void initState() {
    super.initState();
    _txType = widget.isPayment
        ? AppConstants.supplierTxPayment
        : AppConstants.supplierTxPurchaseCredit;
    _currency = PreferencesService.instance.getDefaultCurrency();
    if (!widget.isPayment) {
      _loadStockCatalog();
    }
  }

  Future<void> _loadStockCatalog() async {
    try {
      final options = await _supplierService.loadStockOptions();
      if (!mounted) return;
      final prods = options.products;
      final mats = options.materials;
      setState(() {
        _products = prods;
        _materials = mats;
        if (prods.isEmpty && mats.isNotEmpty) {
          _stockItemType = 'material';
          _selectedStockItemId = mats.first.id;
        } else if (prods.isNotEmpty) {
          _stockItemType = 'product';
          _selectedStockItemId = prods.first.id;
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _txDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() => _txDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      AppToast.showError(context, 'form_validation_failed'.i18n());
      return;
    }

    if (!widget.isPayment && _linkToStock) {
      if (_selectedStockItemId == null || _selectedStockItemId!.isEmpty) {
        AppToast.showError(context, 'supplier_stock_item_required'.i18n());
        return;
      }
      final qty = double.tryParse(_stockQtyController.text.trim()) ?? 0.0;
      if (qty <= 0) {
        AppToast.showError(context, 'supplier_stock_qty_required'.i18n());
        return;
      }
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final notes = _notesController.text.trim();
    final now = DateTime.now();
    final txDateTime = DateTime(
      _txDate.year,
      _txDate.month,
      _txDate.day,
      now.hour,
      now.minute,
      now.second,
    );

    final tx = SupplierTransaction(
      id: const Uuid().v4(),
      supplierId: widget.supplierId,
      type: _txType,
      amount: amount,
      currency: _currency,
      notes: notes.isEmpty ? null : notes,
      receiptPhotoPath: _receiptPhotoPath,
      txDate: txDateTime,
      createdAt: now,
    );

    final qty = (!widget.isPayment && _linkToStock)
        ? (double.tryParse(_stockQtyController.text.trim()) ?? 0.0)
        : 0.0;

    Navigator.pop(
      context,
      SupplierTransactionResult(
        transaction: tx,
        stockItemType: (!widget.isPayment && _linkToStock) ? _stockItemType : null,
        stockItemId: (!widget.isPayment && _linkToStock) ? _selectedStockItemId : null,
        stockQuantity: qty,
      ),
    );
  }

  Widget _buildPurchaseModeSelector() {
    final isCredit = _txType == AppConstants.supplierTxPurchaseCredit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'supplier_tx_payment_mode_label'.i18n(),
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
              child: _buildModeOption(
                label: 'supplier_tx_mode_credit'.i18n(),
                icon: Icons.schedule_rounded,
                selected: isCredit,
                color: _creditWarmAmber,
                onTap: () => setState(
                  () => _txType = AppConstants.supplierTxPurchaseCredit,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildModeOption(
                label: 'supplier_tx_mode_cash'.i18n(),
                icon: Icons.point_of_sale_outlined,
                selected: !isCredit,
                color: AppColors.primaryBlue,
                onTap: () => setState(
                  () => _txType = AppConstants.supplierTxPurchaseCash,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModeOption({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
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

  Widget _buildContextHint() {
    final String hintKey;
    final Color color;
    final IconData icon;

    if (widget.isPayment) {
      hintKey = 'supplier_tx_payment_hint';
      color = AppColors.primaryGreen;
      icon = Icons.payments_outlined;
    } else if (_txType == AppConstants.supplierTxPurchaseCredit) {
      hintKey = 'supplier_tx_credit_hint';
      color = _creditWarmAmber;
      icon = Icons.info_outline_rounded;
    } else {
      hintKey = 'supplier_tx_cash_hint';
      color = AppColors.primaryBlue;
      icon = Icons.account_balance_wallet_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hintKey.i18n(),
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: context.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showCurrency = PreferencesService.instance.isMultiCurrencyEnabled();
    final accentColor = widget.isPayment
        ? AppColors.primaryGreen
        : (_txType == AppConstants.supplierTxPurchaseCredit
            ? _creditWarmAmber
            : AppColors.primaryBlue);

    final amountField = AppTextField(
      controller: _amountController,
      label: 'expense_amount_label'.i18n(),
      prefixIcon: Icons.attach_money_rounded,
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
                    if (!widget.isPayment) ...[
                      _buildPurchaseModeSelector(),
                      const SizedBox(height: 10),
                    ],
                    _buildContextHint(),
                    const SizedBox(height: 12),
                    if (showCurrency)
                      Row(
                        children: [
                          Expanded(flex: 3, child: amountField),
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
                                if (val != null) {
                                  setState(() => _currency = val);
                                }
                              },
                            ),
                          ),
                        ],
                      )
                    else
                      amountField,
                    const SizedBox(height: 8),
                    QuickAmountChips(
                      controller: _amountController,
                      currency: _currency,
                    ),
                    if (!widget.isPayment) ...[
                      const SizedBox(height: 12),
                      _buildStockReplenishmentCard(),
                    ],
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: context.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: context.borderSubtle,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: accentColor,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'supplier_tx_date_label'.i18n(),
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
                                DateFormat('yyyy/MM/dd').format(_txDate),
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
                      photos: _receiptPhotoPath != null &&
                              _receiptPhotoPath!.isNotEmpty
                          ? [_receiptPhotoPath!]
                          : const [],
                      maxPhotos: 1,
                      compact: true,
                      title: 'expense_receipt_photo_title'.i18n(),
                      hint: 'expense_receipt_photo_hint'.i18n(),
                      onPhotosChanged: (paths) {
                        setState(() {
                          _receiptPhotoPath =
                              paths.isNotEmpty ? paths.first : null;
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
              backgroundColor: accentColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockReplenishmentCard() {
    final isProduct = _stockItemType == 'product';
    final hasAnyItems =
        isProduct ? _products.isNotEmpty : _materials.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _linkToStock
            ? AppColors.primaryGreen.withValues(alpha: 0.06)
            : context.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _linkToStock
              ? AppColors.primaryGreen.withValues(alpha: 0.35)
              : context.borderSubtle,
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSwitchTile(
            title: 'supplier_stock_link_toggle'.i18n(),
            subtitle: 'supplier_stock_link_subtitle'.i18n(),
            value: _linkToStock,
            onChanged: (val) => setState(() => _linkToStock = val),
          ),
          if (_linkToStock) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildModeOption(
                    label: 'supplier_stock_type_product'.i18n(),
                    icon: Icons.inventory_2_outlined,
                    selected: isProduct,
                    color: AppColors.primaryGreen,
                    onTap: () {
                      setState(() {
                        _stockItemType = 'product';
                        _selectedStockItemId =
                            _products.isNotEmpty ? _products.first.id : null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeOption(
                    label: 'supplier_stock_type_material'.i18n(),
                    icon: Icons.science_outlined,
                    selected: !isProduct,
                    color: AppColors.primaryGreen,
                    onTap: () {
                      setState(() {
                        _stockItemType = 'material';
                        _selectedStockItemId =
                            _materials.isNotEmpty ? _materials.first.id : null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (!hasAnyItems)
              Text(
                'supplier_stock_no_items'.i18n(),
                style: TextStyle(
                  fontSize: 12,
                  color: context.textSecondary,
                ),
              )
            else ...[
              AppDropdownField<String>(
                label: isProduct
                    ? 'supplier_stock_select_product'.i18n()
                    : 'supplier_stock_select_material'.i18n(),
                value: _selectedStockItemId,
                items: isProduct
                    ? _products
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p.id,
                            child: Text(
                              '${p.name} (${p.stockQuantity})',
                              maxLines: 1,
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
                              '${m.name} (${m.stockQuantity})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _selectedStockItemId = val),
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: _stockQtyController,
                label: 'supplier_stock_qty_label'.i18n(),
                prefixIcon: Icons.add_box_outlined,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
                validator: (val) {
                  if (!_linkToStock) return null;
                  final parsed = double.tryParse(val?.trim() ?? '');
                  if (parsed == null || parsed <= 0) {
                    return 'supplier_stock_qty_required'.i18n();
                  }
                  return null;
                },
              ),
            ],
          ],
        ],
      ),
    );
  }
}
