import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/repositories/order_repository.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_financial_summary_card.dart';
import '../widgets/order_item_detail_tile.dart';
import '../widgets/record_payment_sheet.dart';
import 'add_edit_order_screen.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderRepository _orderRepo = OrderRepositoryImpl();
  final CurrencyService _currencyService = CurrencyService.instance;
  IndividualOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    final order = await _orderRepo.getOrderById(widget.orderId);
    setState(() {
      _order = order;
      _isLoading = false;
    });
  }

  Future<void> _updateActualDeliveryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _order?.actualDeliveryDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );

    if (picked != null && _order != null) {
      final updated = _order!.copyWith(
        actualDeliveryDate: picked,
        orderStatus: AppConstants.orderStatusDelivered,
      );
      if (mounted) {
        context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
      } else {
        await _orderRepo.updateOrder(updated, updated.items);
      }
      _loadOrder();
    }
  }

  void _showChangeOrderStatusSheet() {
    if (_order == null) return;
    final statuses = [
      (AppConstants.orderStatusPending, 'item_status_awaiting_purchase'.i18n(), Icons.hourglass_top_rounded),
      (AppConstants.orderStatusPurchased, 'item_status_purchased'.i18n(), Icons.shopping_bag_outlined),
      (AppConstants.orderStatusInCargo, 'item_status_in_transit'.i18n(), Icons.local_shipping_outlined),
      (AppConstants.orderStatusReady, 'item_status_ready_for_delivery'.i18n(), Icons.check_circle_outline_rounded),
      (AppConstants.orderStatusDelivered, 'item_status_delivered_to_customer'.i18n(), Icons.done_all_rounded),
    ];

    showAppModalSheet(
      context: context,
      title: 'shipment_order_change_status'.i18n(),
      subtitle: 'order_number_title'.trParams({'number': _order!.orderNumber}),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...statuses.map((item) {
            final code = item.$1;
            final label = item.$2;
            final icon = item.$3;
            final isCurrent = _order!.orderStatus == code;
            final color = AppConstants.getOrderStatusColor(code);

            return ListTile(
              dense: true,
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              title: Text(
                label,
                style: TextStyle(
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent ? color : null,
                ),
              ),
              trailing: isCurrent ? Icon(Icons.check, color: color) : null,
              onTap: () async {
                Navigator.pop(context);
                final updated = _order!.copyWith(
                  orderStatus: code,
                  actualDeliveryDate: code == AppConstants.orderStatusDelivered
                      ? (_order!.actualDeliveryDate ?? DateTime.now())
                      : null,
                );
                if (mounted) {
                  context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
                  AppToast.showSuccess(context, 'shipment_order_status_updated'.i18n());
                } else {
                  await _orderRepo.updateOrder(updated, updated.items);
                }
                _loadOrder();
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _updateDebtDueDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _order?.debtDueDate ?? now.add(const Duration(days: 3)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      helpText: 'debt_due_pick_date'.i18n(),
      confirmText: 'debt_due_next_time'.i18n(),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _order?.debtDueDate != null
          ? TimeOfDay.fromDateTime(_order!.debtDueDate!)
          : const TimeOfDay(hour: 10, minute: 0),
      helpText: 'debt_due_pick_time'.i18n(),
      confirmText: 'debt_due_confirm_alarm'.i18n(),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final updated = _order!.copyWith(
      debtDueDate: combined,
      hasDebtReminder: true,
    );
    if (mounted) {
      context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
    } else {
      await _orderRepo.updateOrder(updated, updated.items);
    }
    await ReminderService.instance.scheduleDebtReminder(updated);
    _loadOrder();
  }

  Future<void> _syncToCalendar() async {
    if (_order == null || _order!.debtDueDate == null) return;
    final ok = await ReminderService.instance.syncWithNativeCalendar(_order!);
    if (!mounted) return;
    if (ok) {
      final updated = _order!.copyWith(isSyncedWithCalendar: true);
      if (mounted) {
        context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
      } else {
        await _orderRepo.updateOrder(updated, updated.items);
      }
      _loadOrder();
      if (!mounted) return;
      AppToast.showSuccess(context, 'debt_due_calendar_success'.i18n());
    } else {
      AppToast.showInfo(context, 'debt_due_calendar_cancelled'.i18n());
    }
  }

  void _shareViaWhatsApp() async {
    if (_order == null) return;
    final buffer = StringBuffer();
    buffer.writeln('invoice_greeting'.trParams({'name': _order!.customerName ?? 'customer_dear'.i18n()}));
    buffer.writeln('invoice_order_title'.trParams({'number': _order!.orderNumber}));
    buffer.writeln('--------------------------------');

    for (int i = 0; i < _order!.items.length; i++) {
      final item = _order!.items[i];
      final itemPrice = item.sellPrice != null
          ? _currencyService.formatAmount(item.sellPrice!, currencyCode: item.currency)
          : 'order_pricing_pending'.i18n();
      buffer.writeln('invoice_item_line'.trParams({
        'idx': '${i + 1}',
        'name': item.name,
        'qty': '${item.quantity}',
        'price': itemPrice,
      }));
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('invoice_total_amount'.trParams({
      'amount': _currencyService.formatAmount(_order!.totalSellPrice, currencyCode: _order!.currency),
    }));
    buffer.writeln('invoice_paid_label'.trParams({
      'amount': _currencyService.formatAmount(_order!.paidAmount, currencyCode: _order!.currency),
    }));
    buffer.writeln('invoice_remaining_amount'.trParams({
      'amount': _currencyService.formatAmount(_order!.remainingDebt, currencyCode: _order!.currency),
    }));

    final text = Uri.encodeComponent(buffer.toString());
    final url = Uri.parse('whatsapp://send?text=$text');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        AppToast.showError(context, 'order_whatsapp_error'.i18n());
      }
    }
  }

  void _showPaymentDialog() {
    if (_order == null) return;
    RecordPaymentSheet.show(
      context,
      order: _order!,
      onSave: (paymentStatus, paidAmount) async {
        context.read<OrdersBloc>().add(RecordPaymentEvent(
              orderId: _order!.id,
              newStatus: paymentStatus,
              paidAmount: paidAmount,
            ));
        _loadOrder();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('order_details'.i18n())),
        body: AppShimmer.list(itemCount: 4, isCards: true),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(title: Text('order_details'.i18n())),
        body: AppErrorStateView(
          title: 'order_not_found'.i18n(),
          message: 'order_not_found_desc'.i18n(),
          onRetry: () => _loadOrder(),
        ),
      );
    }

    final order = _order!;

    return Scaffold(
      appBar: AppBar(
        title: Text('order_number_title'.trParams({'number': order.orderNumber})),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'print_order_invoice_tooltip'.i18n(),
            onPressed: () {
              PrintOptionsSheet.show(
                context,
                allOrders: [order],
                customerName: order.customerName,
                title: 'print_single_order_title'.trParams({'number': order.orderNumber}),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditOrderScreen(orderToEdit: order)),
              );
              if (result == true) {
                if (context.mounted) {
                  context.read<OrdersBloc>().add(const LoadOrders());
                }
                _loadOrder();
              }
            },
          ),
          IconButton(
            icon: const WhatsAppIcon(size: 22),
            onPressed: _shareViaWhatsApp,
            tooltip: 'order_share_whatsapp'.i18n(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة رأس الطلب والعميل
          AppleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        order.customerName ?? 'order_guest_customer'.i18n(),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: _showChangeOrderStatusSheet,
                          child: AppleBadge(
                            label: AppConstants.getOrderStatusLabel(order.orderStatus),
                            color: AppConstants.getOrderStatusColor(order.orderStatus),
                          ),
                        ),
                        const SizedBox(width: 6),
                        AppleBadge(
                          label: AppConstants.getPaymentStatusLabel(order.paymentStatus),
                          color: AppConstants.getPaymentStatusColor(order.paymentStatus),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'order_created_at_fmt'.trParams({'date': '${order.createdAt.year}/${order.createdAt.month}/${order.createdAt.day}'}),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'order_expected_delivery_fmt'.trParams({
                        'date': order.expectedDeliveryDate != null
                            ? '${order.expectedDeliveryDate!.year}/${order.expectedDeliveryDate!.month}/${order.expectedDeliveryDate!.day}'
                            : 'common_unspecified'.i18n(),
                      }),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    TextButton.icon(
                      onPressed: _updateActualDeliveryDate,
                      icon: const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primaryGreen),
                      label: Text(
                        order.actualDeliveryDate != null
                            ? 'order_delivered_date_fmt'.trParams({'date': '${order.actualDeliveryDate!.month}/${order.actualDeliveryDate!.day}'})
                            : 'order_set_delivery_date'.i18n(),
                        style: const TextStyle(fontSize: 11, color: AppColors.primaryGreen),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // بطاقة موعد استحقاق الدين والمنبه والتقويم
          if (order.remainingDebt > 0 || order.debtDueDate != null) ...[
            const SizedBox(height: 14),
            AppleCard(
              backgroundColor: const Color(0xFFFFFBEB),
              border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppColors.statusWarning.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(Icons.alarm_on_rounded, size: 18, color: AppColors.statusWarning),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'debt_due_section_title'.i18n(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      if (order.isSyncedWithCalendar)
                        AppBadge(
                          label: 'debt_due_synced_calendar'.i18n(),
                          color: AppColors.primaryGreen,
                        )
                      else if (order.hasDebtReminder)
                        AppBadge(
                          label: 'debt_due_alarm_enabled'.i18n(),
                          color: AppColors.statusWarning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (order.debtDueDate != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.statusWarning),
                        const SizedBox(width: 6),
                        Text(
                          'debt_due_datetime_fmt'.trParams({'date': DateFormat('yyyy/MM/dd  -  hh:mm a').format(order.debtDueDate!)}),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppOutlinedButton(
                            onPressed: _syncToCalendar,
                            icon: Icons.calendar_month_rounded,
                            label: 'debt_due_sync_calendar_btn'.i18n(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AppIconButton(
                          onPressed: _updateDebtDueDate,
                          icon: Icons.edit_calendar_rounded,
                          size: 38,
                          iconSize: 18,
                          tooltip: 'debt_due_edit_btn'.i18n(),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'debt_due_none_set'.i18n(),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                        AppPrimaryButton(
                          onPressed: _updateDebtDueDate,
                          icon: Icons.add_alarm_rounded,
                          label: 'debt_due_set_btn'.i18n(),
                          backgroundColor: AppColors.statusWarning,
                          height: 38,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // قائمة الأغراض والبنود المفصلة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'order_items_section_title'.trParams({'count': '${order.items.length}'}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              if (!order.isFullyPriced)
                AppBadge(
                  label: 'order_unpriced_warning'.i18n(),
                  color: AppColors.statusWarning,
                ),
            ],
          ),
          const SizedBox(height: 8),

          ...order.items.map((item) => OrderItemDetailTile(item: item)),

          const SizedBox(height: 16),

          // ملخص الفاتورة والحسبة المالية
          OrderFinancialSummaryCard(
            order: order,
            onUpdatePayment: _showPaymentDialog,
          ),
        ],
      ),
    );
  }
}

