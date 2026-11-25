import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../../../models/product.dart';
import '../../../../models/product_variant.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
import '../../../products/data/product_variant_repository.dart';
import '../../../products/presentation/widgets/product_picker_sheet.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/repositories/order_repository.dart';
import '../widgets/debt_due_reminder_card.dart';
import '../widgets/item_draft_card.dart';

class AddEditOrderScreen extends StatefulWidget {
  final IndividualOrder? orderToEdit;
  final String? initialCustomerId;
  final String? initialCustomerName;

  const AddEditOrderScreen({
    super.key,
    this.orderToEdit,
    this.initialCustomerId,
    this.initialCustomerName,
  });

  @override
  State<AddEditOrderScreen> createState() => _AddEditOrderScreenState();
}

class _AddEditOrderScreenState extends State<AddEditOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final OrderRepository _orderRepo = OrderRepositoryImpl();
  final CustomerRepository _customerRepo = CustomerRepositoryImpl();
  final ProductVariantRepository _variantRepo = ProductVariantRepository();
  final ImagePicker _imagePicker = ImagePicker();

  late String _orderNumber;
  String? _selectedCustomerId;
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _paidAmountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _additionalCostController = TextEditingController(
    text: '0',
  );
  final TextEditingController _discountController = TextEditingController(
    text: '0',
  );
  final TextEditingController _deliveryFeeController = TextEditingController(
    text: '0',
  );
  final TextEditingController _deliveryAddressController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _depositAmountController = TextEditingController(
    text: '0',
  );

  DateTime _createdAt = DateTime.now();
  DateTime? _expectedDeliveryDate;
  DateTime? _actualDeliveryDate;
  DateTime? _debtDueDate;
  bool _hasDebtReminder = false;
  bool _isSyncedWithCalendar = false;
  bool _requiresDeposit = false;

  String _paymentStatus = AppConstants.paymentDebt;
  String _deliveryType = AppConstants.deliveryPickup;
  String _currency = AppConstants.currencyYer;

  List<Customer> _customers = [];
  List<IndividualOrder> _existingOrders = [];
  Map<String, List<ProductVariant>> _variantsByProduct = {};
  final List<OrderItemDraft> _itemsDraft = [];
  final Map<String, Product> _pickedCatalogProducts = {};
  final Map<String, ({String? variantId, String? variantName})> _draftVariants =
      {};

  @override
  void initState() {
    super.initState();
    _loadCustomers();

    if (widget.orderToEdit != null) {
      final o = widget.orderToEdit!;
      _orderNumber = o.orderNumber;
      _selectedCustomerId = o.customerId;
      _customerNameController.text = o.customerName ?? '';
      _paidAmountController.text = o.paidAmount.toString();
      _additionalCostController.text = o.additionalCost > 0
          ? (o.additionalCost % 1 == 0
                ? o.additionalCost.toInt().toString()
                : o.additionalCost.toString())
          : '0';
      _discountController.text = o.discount > 0
          ? (o.discount % 1 == 0
                ? o.discount.toInt().toString()
                : o.discount.toString())
          : '0';
      _deliveryFeeController.text = o.deliveryFee > 0
          ? (o.deliveryFee % 1 == 0
                ? o.deliveryFee.toInt().toString()
                : o.deliveryFee.toString())
          : '0';
      _deliveryType = o.deliveryType;
      _deliveryAddressController.text = o.deliveryAddress ?? '';
      _notesController.text = o.notes ?? '';
      _createdAt = o.createdAt;
      _expectedDeliveryDate = o.expectedDeliveryDate;
      _actualDeliveryDate = o.actualDeliveryDate;
      _debtDueDate = o.debtDueDate;
      _hasDebtReminder = o.hasDebtReminder;
      _isSyncedWithCalendar = o.isSyncedWithCalendar;
      _requiresDeposit = o.requiresDeposit;
      _depositAmountController.text = o.depositAmount > 0
          ? (o.depositAmount % 1 == 0
                ? o.depositAmount.toInt().toString()
                : o.depositAmount.toString())
          : '0';
      _paymentStatus = o.paymentStatus;
      _currency = o.currency;

      for (final item in o.items) {
        _itemsDraft.add(
          OrderItemDraft(
            id: item.id,
            productId: item.productId,
            name: item.name,
            quantity: item.quantity,
            costPrice: item.costPrice,
            sellPrice: item.sellPrice,
            photos: List.from(item.photos),
          ),
        );
        if (item.variantId != null || item.variantName != null) {
          _draftVariants[item.id] = (
            variantId: item.variantId,
            variantName: item.variantName,
          );
        }
      }
    } else {
      final pfMode = PreferencesService.instance.isProductiveFamilyMode;
      if (pfMode) {
        _paymentStatus = AppConstants.paymentPrepaid;
        _currency = PreferencesService.instance.getDefaultCurrency();
      }
      _orderNumber = DateTime.now().millisecondsSinceEpoch.toString().substring(
        7,
      );
      if (widget.initialCustomerId != null) {
        _selectedCustomerId = widget.initialCustomerId;
      }
      if (widget.initialCustomerName != null) {
        _customerNameController.text = widget.initialCustomerName!;
      }
      _itemsDraft.add(OrderItemDraft(id: const Uuid().v4(), quantity: 1));
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _paidAmountController.dispose();
    _additionalCostController.dispose();
    _discountController.dispose();
    _deliveryFeeController.dispose();
    _deliveryAddressController.dispose();
    _notesController.dispose();
    _depositAmountController.dispose();
    for (final draft in _itemsDraft) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final results = await Future.wait([
      _customerRepo.getAllCustomers(),
      _variantRepo.getAllGroupedByProduct(),
      _orderRepo.getAllOrders(),
    ]);
    if (!mounted) return;
    final groupedVariants = results[1] as Map<String, List<ProductVariant>>;
    final activeVariants = <String, List<ProductVariant>>{};
    for (final entry in groupedVariants.entries) {
      final active = entry.value.where((v) => v.isActive).toList();
      if (active.isNotEmpty) {
        activeVariants[entry.key] = active;
      }
    }
    setState(() {
      _customers = results[0] as List<Customer>;
      _variantsByProduct = activeVariants;
      _existingOrders = results[2] as List<IndividualOrder>;
    });
  }

  void _addItemRow() {
    setState(() {
      _itemsDraft.add(OrderItemDraft(id: const Uuid().v4(), quantity: 1));
    });
  }

  Future<ProductVariant?> _pickVariantForProduct(Product product) async {
    final variants = _variantsByProduct[product.id] ?? const [];
    if (variants.isEmpty) return null;
    final cs = CurrencyService.instance;
    return showAppModalSheet<ProductVariant>(
      context: context,
      title: product.name,
      subtitle: 'quick_order_pick_variant_subtitle'.i18n(),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: variants.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final v = variants[idx];
          final outOfStock = v.stockQuantity <= 0;
          final rawSell = v.sellPrice ?? product.sellPrice;
          final effectiveSell = product.currency == _currency
              ? rawSell
              : cs.convert(
                  amount: rawSell,
                  fromCurrency: product.currency,
                  toCurrency: _currency,
                );
          return ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !outOfStock,
            title: Text(
              v.variantName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: outOfStock ? context.textSecondary : context.textPrimary,
              ),
            ),
            subtitle: Text(
              outOfStock
                  ? 'product_variant_out_of_stock'.i18n()
                  : 'product_variant_remaining_stock'.trParams({
                      'stock': v.stockQuantity.toString(),
                    }),
              style: TextStyle(
                fontSize: 12,
                color: outOfStock
                    ? AppColors.statusDanger
                    : context.textSecondary,
              ),
            ),
            trailing: CurrencyPriceDisplay(
              amount: effectiveSell,
              currency: _currency,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: outOfStock ? context.textSecondary : context.primaryBlue,
              ),
            ),
            onTap: outOfStock ? null : () => Navigator.pop(ctx, v),
          );
        },
      ),
    );
  }

  Future<void> _pickFromCatalog() async {
    final selected = await ProductPickerSheet.show(context);
    if (selected == null || selected.isEmpty || !mounted) return;
    final cs = CurrencyService.instance;

    final resolvedSelections = <({Product product, ProductVariant? variant})>[];
    for (final p in selected) {
      final variants = _variantsByProduct[p.id] ?? const [];
      if (variants.isNotEmpty) {
        final chosenVariant = await _pickVariantForProduct(p);
        if (!mounted) return;
        if (chosenVariant == null) continue;
        resolvedSelections.add((product: p, variant: chosenVariant));
      } else {
        resolvedSelections.add((product: p, variant: null));
      }
    }
    if (resolvedSelections.isEmpty || !mounted) return;

    setState(() {
      // إزالة أول صف إذا كان فارغاً تماماً
      if (_itemsDraft.length == 1 &&
          _itemsDraft.first.nameController.text.trim().isEmpty &&
          _itemsDraft.first.sellController.text.trim().isEmpty) {
        final removed = _itemsDraft.removeAt(0);
        _draftVariants.remove(removed.id);
        removed.dispose();
      }
      for (final entry in resolvedSelections) {
        final p = entry.product;
        final v = entry.variant;
        final draftId = const Uuid().v4();
        final rawCost = v?.costPrice ?? p.costPrice;
        final rawSell = v?.sellPrice ?? p.sellPrice;
        final cost = p.currency == _currency
            ? rawCost
            : cs.convert(
                amount: rawCost,
                fromCurrency: p.currency,
                toCurrency: _currency,
              );
        final sell = p.currency == _currency
            ? rawSell
            : cs.convert(
                amount: rawSell,
                fromCurrency: p.currency,
                toCurrency: _currency,
              );
        _itemsDraft.add(
          OrderItemDraft(
            id: draftId,
            productId: p.id,
            name: p.name,
            quantity: 1,
            costPrice: cost,
            sellPrice: sell,
          ),
        );
        _pickedCatalogProducts[draftId] = p;
        if (v != null) {
          _draftVariants[draftId] = (
            variantId: v.id,
            variantName: v.variantName,
          );
        }
      }
    });
  }

  void _removeItemRow(int index) {
    if (_itemsDraft.length > 1) {
      setState(() {
        final removed = _itemsDraft.removeAt(index);
        removed.dispose();
      });
    }
  }

  Future<void> _pickPhotosForDraft(int index) async {
    final pickedFiles = await _imagePicker.pickMultiImage();
    if (!mounted) return;
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _itemsDraft[index].photos.addAll(pickedFiles.map((f) => f.path));
      });
    }
  }

  double _calculateItemsCost() {
    double totalCost = 0.0;
    for (final draft in _itemsDraft) {
      final qty = int.tryParse(draft.qtyController.text) ?? 1;
      final cost = double.tryParse(draft.costController.text) ?? 0.0;
      totalCost += (qty * cost);
    }
    return totalCost;
  }

  double _calculateAdditionalCost() {
    return double.tryParse(_additionalCostController.text) ?? 0.0;
  }

  double _calculateTotalCost() {
    return _calculateItemsCost() + _calculateAdditionalCost();
  }

  double _calculateDiscount() {
    return double.tryParse(_discountController.text) ?? 0.0;
  }

  double _calculateDeliveryFee() {
    return double.tryParse(_deliveryFeeController.text) ?? 0.0;
  }

  double _calculateTotalSell() {
    double totalSell = 0.0;
    for (final draft in _itemsDraft) {
      final qty = int.tryParse(draft.qtyController.text) ?? 1;
      final sell = double.tryParse(draft.sellController.text) ?? 0.0;
      totalSell += (qty * sell);
    }
    final net = totalSell + _calculateDeliveryFee() - _calculateDiscount();
    return net > 0 ? net : 0.0;
  }

  double _calculateRemainingDebt() {
    final totalSell = _calculateTotalSell();
    final paid = double.tryParse(_paidAmountController.text) ?? 0.0;
    final diff = totalSell - paid;
    return diff > 0 ? diff : 0.0;
  }

  double _calculateEstimatedProfit() {
    return _calculateTotalSell() - _calculateTotalCost();
  }

  Future<void> _saveOrder() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.error(context, 'form_validation_failed'.i18n());
      return;
    }

    final orderId = widget.orderToEdit?.id ?? const Uuid().v4();
    final paid = double.tryParse(_paidAmountController.text) ?? 0.0;
    final additionalCost =
        double.tryParse(_additionalCostController.text) ?? 0.0;

    final List<OrderItem> orderItems = [];
    for (final draft in _itemsDraft) {
      final name = draft.nameController.text.trim();
      final qty = int.tryParse(draft.qtyController.text) ?? 1;
      final cost = double.tryParse(draft.costController.text) ?? 0.0;
      final sellText = draft.sellController.text.trim();
      final double? sell = sellText.isNotEmpty
          ? double.tryParse(sellText)
          : null;

      final variantInfo = _draftVariants[draft.id];
      orderItems.add(
        OrderItem(
          id: draft.id,
          orderId: orderId,
          productId: draft.productId ?? _pickedCatalogProducts[draft.id]?.id,
          variantId: variantInfo?.variantId,
          variantName: variantInfo?.variantName,
          name: name,
          quantity: qty,
          costPrice: cost,
          sellPrice: sell,
          currency: _currency,
          photos: draft.photos,
        ),
      );
    }

    final newOrder = IndividualOrder(
      id: orderId,
      orderNumber: _orderNumber,
      customerId: _selectedCustomerId,
      customerName: _selectedCustomerId != null
          ? _customers
                .firstWhere(
                  (c) => c.id == _selectedCustomerId,
                  orElse: () => Customer(id: '', name: ''),
                )
                .name
          : (_customerNameController.text.trim().isNotEmpty
                ? _customerNameController.text.trim()
                : null),
      shipmentId: widget.orderToEdit?.shipmentId,
      paymentStatus: _paymentStatus,
      orderStatus:
          widget.orderToEdit?.orderStatus ?? AppConstants.orderStatusPending,
      createdAt: _createdAt,
      expectedDeliveryDate: _expectedDeliveryDate,
      actualDeliveryDate: _actualDeliveryDate,
      debtDueDate: _debtDueDate,
      hasDebtReminder: _hasDebtReminder,
      isSyncedWithCalendar: _isSyncedWithCalendar,
      paidAmount: paid,
      additionalCost: additionalCost,
      discount: _calculateDiscount(),
      deliveryFee: _calculateDeliveryFee(),
      deliveryType: _deliveryType,
      deliveryAddress: _deliveryAddressController.text.trim().isEmpty
          ? null
          : _deliveryAddressController.text.trim(),
      isQuickOrder: widget.orderToEdit?.isQuickOrder ?? false,
      occasionLabel: widget.orderToEdit?.occasionLabel,
      prepReminderAt: widget.orderToEdit?.prepReminderAt,
      courierId: widget.orderToEdit?.courierId,
      courierStatus:
          widget.orderToEdit?.courierStatus ?? AppConstants.courierStatusNone,
      courierFee: widget.orderToEdit?.courierFee ?? 0.0,
      isSettledWithCourier: widget.orderToEdit?.isSettledWithCourier ?? false,
      requiresDeposit: _requiresDeposit,
      depositAmount: _requiresDeposit
          ? (double.tryParse(_depositAmountController.text.trim()) ?? 0.0)
          : 0.0,
      currency: _currency,
      notes: _notesController.text.trim(),
      items: orderItems,
    );

    if (widget.orderToEdit != null) {
      await _orderRepo.updateOrder(newOrder, orderItems);
    } else {
      await _orderRepo.saveOrder(newOrder, orderItems);
    }

    // جدولة منبه الدين في حال كان مفعلاً ومحدداً
    if (_hasDebtReminder && _debtDueDate != null) {
      await ReminderService.instance.scheduleDebtReminder(newOrder);
    } else if (!_hasDebtReminder) {
      await ReminderService.instance.cancelDebtReminder(orderId);
    }

    if (mounted) Navigator.pop(context, true);
  }

  Widget _buildCurrencyDropdown() {
    return AppDropdownField<String>(
      value: _currency,
      label: 'order_currency_label'.i18n(),
      items: [
        DropdownMenuItem(
          value: AppConstants.currencyYer,
          child: Text(
            'currency_yer'.i18n(),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        DropdownMenuItem(
          value: AppConstants.currencySar,
          child: Text(
            'currency_sar'.i18n(),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        DropdownMenuItem(
          value: AppConstants.currencyUsd,
          child: Text(
            'currency_usd'.i18n(),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
      ],
      onChanged: (val) => setState(() => _currency = val!),
    );
  }

  Widget _buildPaymentStatusDropdown() {
    return AppDropdownField<String>(
      value: _paymentStatus,
      label: 'order_payment_status_label'.i18n(),
      items: [
        DropdownMenuItem(
          value: AppConstants.paymentPrepaid,
          child: Text(
            AppConstants.getPaymentStatusLabel(AppConstants.paymentPrepaid),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        DropdownMenuItem(
          value: AppConstants.paymentDebt,
          child: Text(
            AppConstants.getPaymentStatusLabel(AppConstants.paymentDebt),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        DropdownMenuItem(
          value: AppConstants.paymentCod,
          child: Text(
            AppConstants.getPaymentStatusLabel(AppConstants.paymentCod),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
        DropdownMenuItem(
          value: AppConstants.paymentPartial,
          child: Text(
            AppConstants.getPaymentStatusLabel(AppConstants.paymentPartial),
            style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
          ),
        ),
      ],
      onChanged: (val) {
        if (val == null) return;
        setState(() {
          _paymentStatus = val;
          if (val == AppConstants.paymentPrepaid ||
              val == AppConstants.paymentCod) {
            final currentPaid =
                double.tryParse(_paidAmountController.text.trim()) ?? 0.0;
            if (_paidAmountController.text.trim().isEmpty || currentPaid <= 0) {
              final total = _calculateTotalSell();
              if (total > 0) {
                _paidAmountController.text = total % 1 == 0
                    ? total.toInt().toString()
                    : total.toStringAsFixed(2);
              }
            }
          }
        });
      },
    );
  }

  Widget _buildAdditionalCostField() {
    return AppTextField(
      controller: _additionalCostController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'order_additional_cost_label'.trParams({
        'symbol': AppConstants.getCurrencySymbol(_currency),
      }),
      hint: '0.00',
      prefixIcon: Icons.add_circle_outline_rounded,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildPaidAmountField() {
    return AppTextField(
      controller: _paidAmountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'order_paid_amount_label'.trParams({
        'symbol': AppConstants.getCurrencySymbol(_currency).i18n(),
      }),
      hint: '0.00',
      prefixIcon: Icons.payments_outlined,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      onChanged: (_) => setState(() {}),
      validator: (val) => AppValidators.paidAmount(
        val,
        maxAmount: _calculateTotalSell() > 0 ? _calculateTotalSell() : null,
        allowEmpty: false,
      ),
      textInputAction: TextInputAction.next,
    );
  }

  Widget _buildDeliveryFeeField() {
    return AppTextField(
      controller: _deliveryFeeController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'order_delivery_fee_label'.i18n(),
      hint: '0.00',
      prefixIcon: Icons.delivery_dining_outlined,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildDiscountField() {
    return AppTextField(
      controller: _discountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      label: 'order_discount_label'.i18n(),
      hint: '0.00',
      prefixIcon: Icons.discount_outlined,
      inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
      onChanged: (_) => setState(() {}),
    );
  }

  int _activeOrdersCountForDate(DateTime date) {
    int count = 0;
    for (final o in _existingOrders) {
      if (widget.orderToEdit != null && o.id == widget.orderToEdit!.id) {
        continue;
      }
      if (o.orderStatus == AppConstants.orderStatusDelivered) continue;
      final d = o.expectedDeliveryDate;
      if (d == null) continue;
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        count++;
      }
    }
    return count;
  }

  Widget _buildDailyCapWarningBanner(
    BuildContext context, {
    required int activeCount,
    required int dailyCap,
    required DateTime targetDate,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 18,
                color: AppColors.statusWarning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'order_daily_cap_warning'.trParams({
                    'count': activeCount.toString(),
                    'cap': dailyCap.toString(),
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _expectedDeliveryDate = targetDate.add(
                      const Duration(days: 1),
                    );
                  });
                },
                icon: const Icon(Icons.next_plan_outlined, size: 16),
                label: Text('order_cap_shift_tomorrow'.i18n()),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final msg =
                      WhatsAppTemplateEngine.buildCapacityFullApologyMessage(
                        fullDate: targetDate,
                        nextAvailableDate: targetDate.add(
                          const Duration(days: 1),
                        ),
                      );
                  await SharePlus.instance.share(ShareParams(text: msg));
                },
                icon: const WhatsAppIcon(size: 16),
                label: Text('order_cap_whatsapp_apology'.i18n()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDatesRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        AppOutlinedButton(
          onPressed: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate:
                  _expectedDeliveryDate ??
                  DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
            );
            if (!mounted) return;
            if (picked != null) {
              setState(() => _expectedDeliveryDate = picked);
            }
          },
          icon: Icons.event_available,
          label: _expectedDeliveryDate == null
              ? 'order_expected_delivery_date'.i18n()
              : '${_expectedDeliveryDate!.year}/${_expectedDeliveryDate!.month}/${_expectedDeliveryDate!.day}',
        ),
        if (widget.orderToEdit != null)
          AppOutlinedButton(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _actualDeliveryDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (!mounted) return;
              if (picked != null) {
                setState(() => _actualDeliveryDate = picked);
              }
            },
            icon: Icons.check_circle_outline,
            label: _actualDeliveryDate == null
                ? 'order_actual_delivery_date'.i18n()
                : '${_actualDeliveryDate!.year}/${_actualDeliveryDate!.month}/${_actualDeliveryDate!.day}',
          ),
      ],
    );
  }

  Customer? get _selectedCustomer {
    if (_selectedCustomerId == null) return null;
    for (final c in _customers) {
      if (c.id == _selectedCustomerId) return c;
    }
    return null;
  }

  Widget _buildRepeatRefusalWarning(BuildContext context, Customer customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: AppColors.statusWarning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'customer_repeat_refusal_warning'.trParams({
                'count': customer.returnCount.toString(),
              }),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pfMode = PreferencesService.instance.isProductiveFamilyMode;
    final showMultiCurrency =
        PreferencesService.instance.isMultiCurrencyEnabled();
    final isDelivery = _deliveryType == AppConstants.deliveryDelivery;
    final selectedCustomer = _selectedCustomer;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.orderToEdit != null
              ? 'order_edit_title'.trParams({'number': _orderNumber})
              : 'order_create_title'.i18n(),
        ),
        leading: IconButton(
          icon: BackChevron(size: 18, color: context.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // بطاقة بيانات العميل والربط
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_customer_info_section'.i18n(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCustomerSearchDropdown(
                    customers: _customers,
                    selectedCustomerId: _selectedCustomerId,
                    onChanged: (customer) {
                      setState(() {
                        _selectedCustomerId = customer?.id;
                        if (customer != null) {
                          _customerNameController.text = customer.name;
                          if (!_customers.any((c) => c.id == customer.id)) {
                            _customers.add(customer);
                          }
                        } else {
                          _customerNameController.clear();
                        }
                      });
                    },
                    onCustomerCreated: (newCustomer) {
                      setState(() {
                        if (!_customers.any((c) => c.id == newCustomer.id)) {
                          _customers.add(newCustomer);
                        }
                        _selectedCustomerId = newCustomer.id;
                        _customerNameController.text = newCustomer.name;
                      });
                    },
                  ),
                  if (selectedCustomer != null &&
                      selectedCustomer.hasRepeatRefusals) ...[
                    const SizedBox(height: 10),
                    _buildRepeatRefusalWarning(context, selectedCustomer),
                  ],
                  if (_selectedCustomerId == null) ...[
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _customerNameController,
                      label: 'order_quick_customer_name'.i18n(),
                      hint: 'order_quick_customer_example'.i18n(),
                      prefixIcon: Icons.person_outline_rounded,
                      inputFormatters: AppFormatters.personName(),
                      validator: (val) => _selectedCustomerId == null
                          ? AppValidators.customerName(val)
                          : null,
                      textInputAction: TextInputAction.next,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // التواريخ والحالة والعملة
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_details_dates_section'.i18n(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!pfMode || showMultiCurrency)
                    Row(
                      children: [
                        Expanded(child: _buildCurrencyDropdown()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPaymentStatusDropdown()),
                      ],
                    )
                  else
                    _buildPaymentStatusDropdown(),
                  const SizedBox(height: 14),
                  if (!pfMode)
                    Row(
                      children: [
                        Expanded(child: _buildAdditionalCostField()),
                        const SizedBox(width: 8),
                        Expanded(child: _buildPaidAmountField()),
                      ],
                    )
                  else
                    _buildPaidAmountField(),
                  if (PreferencesService.instance
                          .getFeatureFlags()
                          .seasonalDeposit ||
                      _requiresDeposit) ...[
                    const SizedBox(height: 10),
                    AppSwitchTile(
                      title: 'order_requires_deposit_label'.i18n(),
                      subtitle: 'order_requires_deposit_hint'.i18n(),
                      value: _requiresDeposit,
                      onChanged: (val) => setState(() => _requiresDeposit = val),
                    ),
                    if (_requiresDeposit) ...[
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _depositAmountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        label: 'order_deposit_amount_label'.trParams({
                          'symbol': AppConstants.getCurrencySymbol(
                            _currency,
                          ).i18n(),
                        }),
                        hint: '0.00',
                        prefixIcon: Icons.savings_outlined,
                        inputFormatters: AppFormatters.positiveDecimal(
                          decimalRange: 2,
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  // نوع التسليم (استلام من المنزل / توصيل) والخصم ورسوم التوصيل
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text('order_delivery_pickup'.i18n()),
                        selected: _deliveryType == AppConstants.deliveryPickup,
                        onSelected: (_) => setState(
                          () => _deliveryType = AppConstants.deliveryPickup,
                        ),
                      ),
                      ChoiceChip(
                        label: Text('order_delivery_home'.i18n()),
                        selected:
                            _deliveryType == AppConstants.deliveryDelivery,
                        onSelected: (_) => setState(
                          () => _deliveryType = AppConstants.deliveryDelivery,
                        ),
                      ),
                    ],
                  ),
                  if (isDelivery) ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: _deliveryAddressController,
                      label: 'order_delivery_address_label'.i18n(),
                      hint: 'order_delivery_address_hint'.i18n(),
                      prefixIcon: Icons.location_on_outlined,
                    ),
                    if (pfMode) ...[
                      const SizedBox(height: 10),
                      _buildDeliveryFeeField(),
                    ],
                  ],
                  if (!pfMode) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (isDelivery) ...[
                          Expanded(child: _buildDeliveryFeeField()),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: _buildDiscountField()),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDatesRow(),
                  ] else ...[
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(top: 8),
                        title: Text(
                          'quick_order_more_options'.i18n(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          if (!showMultiCurrency) ...[
                            _buildCurrencyDropdown(),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            children: [
                              Expanded(child: _buildAdditionalCostField()),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDiscountField()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDatesRow(),
                        ],
                      ),
                    ),
                  ],
                  if (_expectedDeliveryDate != null) ...[
                    Builder(
                      builder: (context) {
                        final cap = PreferencesService.instance
                            .getDailyOrderCap();
                        if (cap <= 0) return const SizedBox.shrink();
                        final count = _activeOrdersCountForDate(
                          _expectedDeliveryDate!,
                        );
                        if (count < cap) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _buildDailyCapWarningBanner(
                            context,
                            activeCount: count,
                            dailyCap: cap,
                            targetDate: _expectedDeliveryDate!,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // بطاقة تاريخ استحقاق الدين والمنبه والتقويم (تظهر عند تحديد الطلب كدين أو دفع جزئي)
            if (_paymentStatus == AppConstants.paymentDebt ||
                _paymentStatus == AppConstants.paymentPartial) ...[
              const SizedBox(height: 16),
              DebtDueReminderCard(
                debtDueDate: _debtDueDate,
                hasDebtReminder: _hasDebtReminder,
                isSyncedWithCalendar: _isSyncedWithCalendar,
                orderNumber: _orderNumber,
                customerName: _selectedCustomerId != null
                    ? _customers
                          .firstWhere(
                            (c) => c.id == _selectedCustomerId,
                            orElse: () => Customer(id: '', name: ''),
                          )
                          .name
                    : _customerNameController.text.trim(),
                remainingDebt: _calculateRemainingDebt(),
                currency: _currency,
                onDueDateChanged: (val) => setState(() => _debtDueDate = val),
                onReminderChanged: (val) =>
                    setState(() => _hasDebtReminder = val),
                onCalendarSyncedChanged: (val) =>
                    setState(() => _isSyncedWithCalendar = val),
              ),
            ],

            const SizedBox(height: 16),

            // بنود وأغراض الطلب المفصلة
            AppSectionHeader(
              title: 'order_items_section'.i18n(),
              actionTitle: 'order_add_item_btn'.i18n(),
              actionIcon: Icons.add_circle_outline_rounded,
              onActionTap: _addItemRow,
              padding: EdgeInsets.zero,
            ),
            const SizedBox(height: 6),
            AppOutlinedButton(
              onPressed: _pickFromCatalog,
              icon: Icons.storefront_outlined,
              label: 'product_pick_from_catalog'.i18n(),
            ),
            const SizedBox(height: 8),

            ..._itemsDraft.asMap().entries.map((entry) {
              final idx = entry.key;
              final draft = entry.value;
              final variantName = _draftVariants[draft.id]?.variantName;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (variantName != null && variantName.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: AppBadge(
                        icon: Icons.style_outlined,
                        label: variantName.trim(),
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ItemDraftCard(
                    index: idx,
                    draft: draft,
                    currency: _currency,
                    canDelete: _itemsDraft.length > 1,
                    onDelete: () => _removeItemRow(idx),
                    onPickPhotos: () => _pickPhotosForDraft(idx),
                    onRemovePhoto: (photoIdx) {
                      setState(() => draft.photos.removeAt(photoIdx));
                    },
                  ),
                ],
              );
            }),

            const SizedBox(height: 16),

            // بطاقة ملخص الحسبة المالية المباشرة للطلب
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_financial_summary_title'.i18n(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLiveSummaryRow(
                    context,
                    'order_items_cost_only'.i18n(),
                    amount: _calculateItemsCost(),
                  ),
                  if (_calculateAdditionalCost() > 0) ...[
                    const SizedBox(height: 6),
                    _buildLiveSummaryRow(
                      context,
                      'order_additional_cost'.i18n(),
                      amount: _calculateAdditionalCost(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  _buildLiveSummaryRow(
                    context,
                    'order_total_cost_price'.i18n(),
                    amount: _calculateTotalCost(),
                    isBold: true,
                  ),
                  const SizedBox(height: 6),
                  _buildLiveSummaryRow(
                    context,
                    'order_total_sell_price'.i18n(),
                    amount: _calculateTotalSell(),
                    isBold: true,
                  ),
                  const Divider(height: 16),
                  _buildLiveSummaryRow(
                    context,
                    'order_estimated_profit'.i18n(),
                    amount: _calculateEstimatedProfit(),
                    isBold: true,
                    valueColor: _calculateEstimatedProfit() >= 0
                        ? AppColors.primaryGreen
                        : AppColors.statusDanger,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // قسم الملاحظات الإضافية للطلب
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'order_notes_label'.i18n(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: _notesController,
                    maxLines: 3,
                    label: '',
                    hint: 'customer_notes_hint'.i18n(),
                    prefixIcon: Icons.notes_rounded,
                    inputFormatters: AppFormatters.notes(),
                    validator: AppValidators.notes,
                    textInputAction: TextInputAction.done,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            AppPrimaryButton(
              onPressed: _saveOrder,
              label: widget.orderToEdit != null
                  ? 'order_save_changes'.i18n()
                  : 'order_confirm_create'.i18n(),
              icon: Icons.check_circle_outline_rounded,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSummaryRow(
    BuildContext context,
    String label, {
    required double amount,
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isBold ? context.textPrimary : context.textSecondary,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: CurrencyPriceDisplay(
            amount: amount,
            currency: _currency,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
