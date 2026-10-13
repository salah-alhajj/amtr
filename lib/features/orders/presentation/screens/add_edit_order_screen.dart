import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/repositories/customer_repository.dart';
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
  final TextEditingController _notesController = TextEditingController();

  DateTime _createdAt = DateTime.now();
  DateTime? _expectedDeliveryDate;
  DateTime? _actualDeliveryDate;
  DateTime? _debtDueDate;
  bool _hasDebtReminder = false;
  bool _isSyncedWithCalendar = false;

  String _paymentStatus = AppConstants.paymentDebt;
  String _currency = AppConstants.currencyYer;

  List<Customer> _customers = [];
  final List<OrderItemDraft> _itemsDraft = [];

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
      _notesController.text = o.notes ?? '';
      _createdAt = o.createdAt;
      _expectedDeliveryDate = o.expectedDeliveryDate;
      _actualDeliveryDate = o.actualDeliveryDate;
      _debtDueDate = o.debtDueDate;
      _hasDebtReminder = o.hasDebtReminder;
      _isSyncedWithCalendar = o.isSyncedWithCalendar;
      _paymentStatus = o.paymentStatus;
      _currency = o.currency;

      for (final item in o.items) {
        _itemsDraft.add(
          OrderItemDraft(
            id: item.id,
            name: item.name,
            quantity: item.quantity,
            costPrice: item.costPrice,
            sellPrice: item.sellPrice,
            photos: List.from(item.photos),
          ),
        );
      }
    } else {
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
    _notesController.dispose();
    for (final draft in _itemsDraft) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await _customerRepo.getAllCustomers();
    setState(() => _customers = list);
  }

  void _addItemRow() {
    setState(() {
      _itemsDraft.add(OrderItemDraft(id: const Uuid().v4(), quantity: 1));
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

  double _calculateTotalSell() {
    double totalSell = 0.0;
    for (final draft in _itemsDraft) {
      final qty = int.tryParse(draft.qtyController.text) ?? 1;
      final sell = double.tryParse(draft.sellController.text) ?? 0.0;
      totalSell += (qty * sell);
    }
    return totalSell;
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

      orderItems.add(
        OrderItem(
          id: draft.id,
          orderId: orderId,
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

  @override
  Widget build(BuildContext context) {
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
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdownField<String>(
                          value: _currency,
                          label: 'order_currency_label'.i18n(),
                          items: [
                            DropdownMenuItem(
                              value: AppConstants.currencyYer,
                              child: Text(
                                'currency_yer'.i18n(),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.currencySar,
                              child: Text(
                                'currency_sar'.i18n(),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.currencyUsd,
                              child: Text(
                                'currency_usd'.i18n(),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _currency = val!),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppDropdownField<String>(
                          value: _paymentStatus,
                          label: 'order_payment_status_label'.i18n(),
                          items: [
                            DropdownMenuItem(
                              value: AppConstants.paymentPrepaid,
                              child: Text(
                                AppConstants.getPaymentStatusLabel(
                                  AppConstants.paymentPrepaid,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.paymentDebt,
                              child: Text(
                                AppConstants.getPaymentStatusLabel(
                                  AppConstants.paymentDebt,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.paymentCod,
                              child: Text(
                                AppConstants.getPaymentStatusLabel(
                                  AppConstants.paymentCod,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.paymentPartial,
                              child: Text(
                                AppConstants.getPaymentStatusLabel(
                                  AppConstants.paymentPartial,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setState(() => _paymentStatus = val!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: _additionalCostController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          label: 'order_additional_cost_label'.trParams({
                            'symbol': AppConstants.getCurrencySymbol(_currency),
                          }),
                          hint: '0.00',
                          prefixIcon: Icons.add_circle_outline_rounded,
                          inputFormatters: AppFormatters.positiveDecimal(
                            decimalRange: 2,
                          ),
                          onChanged: (_) => setState(() {}),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppTextField(
                          controller: _paidAmountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          label: 'order_paid_amount_label'.trParams({
                            'symbol': AppConstants.getCurrencySymbol(
                              _currency,
                            ).i18n(),
                          }),
                          hint: '0.00',
                          prefixIcon: Icons.payments_outlined,
                          inputFormatters: AppFormatters.positiveDecimal(
                            decimalRange: 2,
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (val) => AppValidators.paidAmount(
                            val,
                            maxAmount: _calculateTotalSell() > 0
                                ? _calculateTotalSell()
                                : null,
                            allowEmpty: false,
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: AppOutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _expectedDeliveryDate ??
                                  DateTime.now().add(const Duration(days: 7)),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => _expectedDeliveryDate = picked);
                            }
                          },
                          icon: Icons.event_available,
                          label: _expectedDeliveryDate == null
                              ? 'order_expected_delivery_date'.i18n()
                              : '${_expectedDeliveryDate!.year}/${_expectedDeliveryDate!.month}/${_expectedDeliveryDate!.day}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppOutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate:
                                  _actualDeliveryDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => _actualDeliveryDate = picked);
                            }
                          },
                          icon: Icons.check_circle_outline,
                          label: _actualDeliveryDate == null
                              ? 'order_actual_delivery_date'.i18n()
                              : '${_actualDeliveryDate!.year}/${_actualDeliveryDate!.month}/${_actualDeliveryDate!.day}',
                        ),
                      ),
                    ],
                  ),
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
            const SizedBox(height: 8),

            ..._itemsDraft.asMap().entries.map((entry) {
              final idx = entry.key;
              final draft = entry.value;
              return ItemDraftCard(
                index: idx,
                draft: draft,
                currency: _currency,
                canDelete: _itemsDraft.length > 1,
                onDelete: () => _removeItemRow(idx),
                onPickPhotos: () => _pickPhotosForDraft(idx),
                onRemovePhoto: (photoIdx) {
                  setState(() => draft.photos.removeAt(photoIdx));
                },
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
                    'customer_notes_label'.i18n(),
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
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isBold ? context.textPrimary : context.textSecondary,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        CurrencyPriceDisplay(
          amount: amount,
          currency: _currency,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: valueColor ?? context.textPrimary,
          ),
        ),
      ],
    );
  }
}
