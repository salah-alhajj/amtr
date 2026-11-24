import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';
import '../../../customers/data/repositories/customer_repository_impl.dart';
import '../../../customers/domain/customer_whatsapp_helper.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../domain/repositories/order_repository.dart';
import '../bloc/orders_bloc.dart';
import '../widgets/order_financial_summary_card.dart';
import '../widgets/order_item_detail_tile.dart';
import '../widgets/record_payment_sheet.dart';
import 'add_edit_order_screen.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../../whatsapp/presentation/widgets/whatsapp_template_sheet.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final OrderRepository _orderRepo = OrderRepositoryImpl();
  IndividualOrder? _order;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final order = await _orderRepo.getOrderById(widget.orderId);
    if (!mounted) return;
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
        setState(() => _order = updated);
        context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
      } else {
        await _orderRepo.updateOrder(updated, updated.items);
      }
    }
  }

  void _showChangeOrderStatusSheet() {
    if (_order == null) return;
    final statuses = [
      (AppConstants.orderStatusPending, AppConstants.getOrderStatusLabel(AppConstants.orderStatusPending), Icons.hourglass_top_rounded),
      (AppConstants.orderStatusPurchased, AppConstants.getOrderStatusLabel(AppConstants.orderStatusPurchased), Icons.shopping_bag_outlined),
      (AppConstants.orderStatusInCargo, AppConstants.getOrderStatusLabel(AppConstants.orderStatusInCargo), Icons.local_shipping_outlined),
      (AppConstants.orderStatusReady, AppConstants.getOrderStatusLabel(AppConstants.orderStatusReady), Icons.check_circle_outline_rounded),
      (AppConstants.orderStatusDelivered, AppConstants.getOrderStatusLabel(AppConstants.orderStatusDelivered), Icons.done_all_rounded),
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
                  setState(() => _order = updated);
                  context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
                  AppToast.showSuccess(context, 'shipment_order_status_updated'.i18n());
                } else {
                  await _orderRepo.updateOrder(updated, updated.items);
                }
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
      setState(() => _order = updated);
      context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
    } else {
      await _orderRepo.updateOrder(updated, updated.items);
    }
    await ReminderService.instance.scheduleDebtReminder(updated);
  }

  Future<void> _syncToCalendar() async {
    if (_order == null || _order!.debtDueDate == null) return;
    final ok = await ReminderService.instance.syncWithNativeCalendar(_order!);
    if (!mounted) return;
    if (ok) {
      final updated = _order!.copyWith(isSyncedWithCalendar: true);
      if (mounted) {
        setState(() => _order = updated);
        context.read<OrdersBloc>().add(UpdateOrderEvent(updated, updated.items));
        AppToast.showSuccess(context, 'debt_due_calendar_success'.i18n());
      } else {
        await _orderRepo.updateOrder(updated, updated.items);
      }
    } else {
      AppToast.showInfo(context, 'debt_due_calendar_cancelled'.i18n());
    }
  }

  void _shareViaWhatsApp() {
    if (_order == null) return;
    WhatsAppTemplateSheet.show(context, order: _order!);
  }

  Future<void> _sendDepositReminder(IndividualOrder order) async {
    final msg = WhatsAppTemplateEngine.buildDepositReminderMessage(order);
    await SharePlus.instance.share(ShareParams(text: msg));
  }

  Future<void> _sendPreDispatchCodConfirm(IndividualOrder order) async {
    String cleanPhone = '';
    IndividualOrder orderForMsg = order;
    if (order.customerId != null && order.customerId!.isNotEmpty) {
      final customer = await CustomerRepositoryImpl().getCustomerById(
        order.customerId!,
      );
      if (customer != null) {
        cleanPhone = YemenPhoneHelper.cleanForWhatsApp(
          CustomerWhatsAppHelper.getEffectiveWhatsAppNumber(customer),
        );
        if ((order.customerName == null || order.customerName!.trim().isEmpty) &&
            customer.name.trim().isNotEmpty) {
          orderForMsg = order.copyWith(customerName: customer.name);
        }
      }
    }

    final message = WhatsAppTemplateEngine.buildPreDispatchCodConfirmMessage(
      orderForMsg,
    );
    final encodedText = Uri.encodeComponent(message);
    final nativeUri = cleanPhone.isNotEmpty
        ? Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encodedText')
        : Uri.parse('whatsapp://send?text=$encodedText');
    final webUri = cleanPhone.isNotEmpty
        ? Uri.parse('https://wa.me/$cleanPhone?text=$encodedText')
        : Uri.parse('https://wa.me/?text=$encodedText');

    bool launched = false;
    try {
      if (await canLaunchUrl(nativeUri)) {
        launched = await launchUrl(
          nativeUri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {
      launched = false;
    }

    if (!launched) {
      try {
        if (await canLaunchUrl(webUri)) {
          launched = await launchUrl(
            webUri,
            mode: LaunchMode.externalApplication,
          );
        } else {
          launched = await launchUrl(webUri, mode: LaunchMode.platformDefault);
        }
      } catch (_) {
        launched = false;
      }
    }

    if (!launched && mounted) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        AppToast.showInfo(context, 'wa_copied_success'.i18n());
      }
    }
  }

  void _showPaymentDialog() {
    if (_order == null) return;
    RecordPaymentSheet.show(
      context,
      order: _order!,
      onSave: (paymentStatus, paidAmount) async {
        final updated = _order!.copyWith(
          paymentStatus: paymentStatus,
          paidAmount: paidAmount,
        );
        if (mounted) {
          setState(() => _order = updated);
          context.read<OrdersBloc>().add(RecordPaymentEvent(
                orderId: _order!.id,
                newStatus: paymentStatus,
                paidAmount: paidAmount,
              ));
        }
      },
    );
  }

  void _reorder() {
    if (_order == null) return;
    context.read<OrdersBloc>().add(ReorderEvent(_order!));
    AppToast.showSuccess(context, 'order_reorder_success'.i18n());
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
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.customerName ?? 'order_guest_customer'.i18n(),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    GestureDetector(
                      onTap: _showChangeOrderStatusSheet,
                      child: AppBadge(
                        label: AppConstants.getOrderStatusLabel(order.orderStatus),
                        color: AppConstants.getOrderStatusColor(order.orderStatus),
                      ),
                    ),
                    AppBadge(
                      label: AppConstants.getPaymentStatusLabel(order.paymentStatus),
                      color: AppConstants.getPaymentStatusColor(order.paymentStatus),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'order_created_at_fmt'.trParams({'date': '${order.createdAt.year}/${order.createdAt.month}/${order.createdAt.day}'}),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'order_expected_delivery_fmt'.trParams({
                          'date': order.expectedDeliveryDate != null
                              ? '${order.expectedDeliveryDate!.year}/${order.expectedDeliveryDate!.month}/${order.expectedDeliveryDate!.day}'
                              : 'common_unspecified'.i18n(),
                        }),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppSecondaryButton(
                        onPressed: _updateActualDeliveryDate,
                        icon: Icons.check_circle_outline,
                        color: AppColors.primaryGreen,
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        label: order.actualDeliveryDate != null
                            ? 'order_delivered_date_fmt'.trParams({'date': '${order.actualDeliveryDate!.month}/${order.actualDeliveryDate!.day}'})
                            : 'order_set_delivery_date'.i18n(),
                      ),
                    ),
                  ],
                ),
                if (order.orderStatus != AppConstants.orderStatusDelivered &&
                    order.remainingDebt > 0) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: AppSecondaryButton(
                      onPressed: () => _sendPreDispatchCodConfirm(order),
                      customIcon: const WhatsAppIcon(size: 16),
                      color: AppColors.primaryGreen,
                      height: 38,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      label: 'order_pre_dispatch_cod_btn'.i18n(),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // بانر بانتظار العربون مع تذكير واتساب بضغطة واحدة
          if (order.isAwaitingDeposit) ...[
            const SizedBox(height: 14),
            AppCard(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.statusWarning.withValues(alpha: 0.14)
                  : const Color(0xFFFFFBEB),
              border: Border.all(
                color: AppColors.statusWarning.withValues(alpha: 0.45),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarning.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 18,
                          color: AppColors.statusWarning,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'order_awaiting_deposit_title'.i18n(),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      Text(
                        'order_deposit_required_fmt'.trParams({
                          'amount': CurrencyService.instance.formatAmount(
                            order.depositAmount,
                            currencyCode: order.currency,
                          ),
                        }),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        'order_deposit_remaining_fmt'.trParams({
                          'amount': CurrencyService.instance.formatAmount(
                            (order.depositAmount - order.paidAmount)
                                .clamp(0.0, double.infinity)
                                .toDouble(),
                            currencyCode: order.currency,
                          ),
                        }),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusWarning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: AppSecondaryButton(
                      onPressed: () => _sendDepositReminder(order),
                      customIcon: const WhatsAppIcon(size: 16),
                      color: AppColors.primaryGreen,
                      height: 38,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      label: 'order_deposit_reminder_whatsapp_btn'.i18n(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // بطاقة موعد استحقاق الدين والمنبه والتقويم
          if (order.remainingDebt > 0 || order.debtDueDate != null) ...[
            const SizedBox(height: 14),
            AppCard(
              backgroundColor: const Color(0xFFFFFBEB),
              border: Border.all(color: AppColors.statusWarning.withValues(alpha: 0.4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
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
                            Expanded(
                              child: Text(
                                'debt_due_section_title'.i18n(),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (order.isSyncedWithCalendar) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: AppBadge(
                            icon: Icons.check_circle_rounded,
                            label: 'debt_due_synced_calendar'.i18n(),
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ] else if (order.hasDebtReminder) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: AppBadge(
                            icon: Icons.notifications_active_rounded,
                            label: 'debt_due_alarm_enabled'.i18n(),
                            color: AppColors.statusWarning,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (order.debtDueDate != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 16, color: AppColors.statusWarning),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'debt_due_datetime_fmt'.trParams({'date': DateFormat('yyyy/MM/dd  -  hh:mm a').format(order.debtDueDate!)}),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
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
                        Expanded(
                          child: Text(
                            'debt_due_none_set'.i18n(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: AppPrimaryButton(
                            onPressed: _updateDebtDueDate,
                            icon: Icons.add_alarm_rounded,
                            label: 'debt_due_set_btn'.i18n(),
                            backgroundColor: AppColors.statusWarning,
                            height: 38,
                          ),
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

          const SizedBox(height: 16),

          AppOutlinedButton(
            onPressed: _reorder,
            icon: Icons.replay_rounded,
            label: 'order_reorder_btn'.i18n(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

