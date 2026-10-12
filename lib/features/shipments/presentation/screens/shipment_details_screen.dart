import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../data/repositories/shipment_repository_impl.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../bloc/shipments_bloc.dart';
import '../widgets/shipment_financial_summary_card.dart';
import '../widgets/shipment_timeline_step_bar.dart';
import 'add_edit_shipment_screen.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';

class ShipmentDetailsScreen extends StatefulWidget {
  final String shipmentId;

  const ShipmentDetailsScreen({super.key, required this.shipmentId});

  @override
  State<ShipmentDetailsScreen> createState() => _ShipmentDetailsScreenState();
}

class _ShipmentDetailsScreenState extends State<ShipmentDetailsScreen> {
  final ShipmentRepository _shipmentRepo = ShipmentRepositoryImpl();
  final CurrencyService _currencyService = CurrencyService.instance;
  ConsolidatedShipment? _shipment;
  bool _isLoading = true;
  String _shipmentViewCurrency = AppConstants.currencyYer;

  @override
  void initState() {
    super.initState();
    _shipmentViewCurrency = _currencyService.activeDisplayCurrency;
    _loadShipment();
  }

  Future<void> _loadShipment() async {
    setState(() => _isLoading = true);
    final shipment = await _shipmentRepo.getShipmentById(widget.shipmentId);
    setState(() {
      _shipment = shipment;
      _isLoading = false;
    });
  }

  Future<void> _advanceStatus(String newStatus) async {
    if (_shipment == null) return;

    // فحص ما إذا كانت هناك طلبات لم تصل بعد عند محاولة إغلاق/تسليم الشحنة
    if (newStatus == AppConstants.shipmentDelivered && _shipment!.orders.isNotEmpty) {
      final unarrived = _shipment!.orders.where(
        (o) => o.orderStatus != AppConstants.orderStatusReady && o.orderStatus != AppConstants.orderStatusDelivered,
      ).toList();

      if (unarrived.isNotEmpty) {
        final confirm = await showAppConfirmationDialog(
          context: context,
          title: 'shipment_advance_unverified_warning'.trParams({'count': unarrived.length.toString()}),
          message: 'توجد طلبات لم يتم التحقق من وصولها بعد أو حالتها ما زالت في الشحن. عند تأكيد التسليم النهائي للشحنة، سيتم تحديث كافة الطلبات الفردية إلى "تم التسليم" افتراضياً ما لم تقم بإزالتها أولاً.',
          confirmLabel: 'shipment_action_complete_delivery'.i18n(),
          cancelLabel: 'common_cancel'.i18n(),
        );
        if (confirm != true) return;
      }
    }

    if (mounted) {
      context.read<ShipmentsBloc>().add(AdvanceShipmentStatusEvent(_shipment!.id, newStatus));
      try {
        context.read<OrdersBloc>().add(const LoadOrders());
      } catch (_) {}
    } else {
      await _shipmentRepo.updateShipmentStatus(_shipment!.id, newStatus);
    }
    _loadShipment();
  }

  Future<void> _verifyAllOrders() async {
    if (_shipment == null || _shipment!.orders.isEmpty) return;
    final targetStatus = _shipment!.status == AppConstants.shipmentDelivered
        ? AppConstants.orderStatusDelivered
        : AppConstants.orderStatusReady;

    if (mounted) {
      context.read<ShipmentsBloc>().add(VerifyAllOrdersInShipmentEvent(_shipment!.id, targetStatus));
      try {
        context.read<OrdersBloc>().add(const LoadOrders());
      } catch (_) {}
      AppToast.showSuccess(context, 'shipment_all_orders_arrived'.i18n());
    } else {
      await _shipmentRepo.verifyAllOrdersInShipment(_shipment!.id, targetStatus);
    }
    _loadShipment();
  }

  Future<void> _toggleOrderArrival(IndividualOrder order) async {
    if (_shipment == null) return;
    final isArrived = order.orderStatus == AppConstants.orderStatusReady ||
        order.orderStatus == AppConstants.orderStatusDelivered;

    // إذا كان واصلاً يتم إرجاعه لوضع أسبق (في الشحن)، وإذا لم يكن واصلاً يتم تأكيد وصوله
    final newStatus = isArrived ? AppConstants.orderStatusInCargo : AppConstants.orderStatusReady;

    if (mounted) {
      context.read<ShipmentsBloc>().add(UpdateIndividualOrderStatusEvent(order.id, newStatus));
      try {
        context.read<OrdersBloc>().add(const LoadOrders());
      } catch (_) {}
      AppToast.showSuccess(
        context,
        isArrived ? 'shipment_order_mark_in_cargo'.i18n() : 'shipment_order_mark_arrived'.i18n(),
      );
    } else {
      await _shipmentRepo.updateIndividualOrderStatus(order.id, newStatus);
    }
    _loadShipment();
  }

  void _showChangeOrderStatusSheet(IndividualOrder order) {
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
      subtitle: 'طلب #${order.orderNumber} - ${order.customerName ?? "customer_quick_default".i18n()}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...statuses.map((item) {
            final code = item.$1;
            final label = item.$2;
            final icon = item.$3;
            final isCurrent = order.orderStatus == code;
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
                if (mounted) {
                  context.read<ShipmentsBloc>().add(UpdateIndividualOrderStatusEvent(order.id, code));
                  try {
                    context.read<OrdersBloc>().add(const LoadOrders());
                  } catch (_) {}
                  AppToast.showSuccess(context, 'shipment_order_status_updated'.i18n());
                }
                _loadShipment();
              },
            );
          }),
        ],
      ),
    );
  }

  Future<void> _confirmRemoveOrder(IndividualOrder order) async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'shipment_order_remove_confirm_title'.i18n(),
      message: 'shipment_order_remove_confirm_desc'.trParams({'number': order.orderNumber}),
      confirmLabel: 'shipment_order_remove_btn'.i18n(),
      cancelLabel: 'common_cancel'.i18n(),
      isDestructive: true,
    );

    if (confirm == true && mounted) {
      context.read<ShipmentsBloc>().add(RemoveOrderFromShipmentEvent(_shipment!.id, order.id));
      try {
        context.read<OrdersBloc>().add(const LoadOrders());
      } catch (_) {}
      AppToast.showSuccess(context, 'shipment_order_removed_success'.i18n());
      _loadShipment();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('shipment_details_title'.i18n())),
        body: AppShimmer.list(itemCount: 4, isCards: true),
      );
    }

    if (_shipment == null) {
      return Scaffold(
        appBar: AppBar(title: Text('shipment_details_title'.i18n())),
        body: AppErrorStateView(
          title: 'shipment_not_found'.i18n(),
          message: 'shipment_not_found_desc'.i18n(),
          onRetry: () => _loadShipment(),
        ),
      );
    }

    final s = _shipment!;
    final currentStep = AppConstants.getShipmentStatusStepIndex(s.status);
    final arrivedCount = s.orders.where((o) => o.orderStatus == AppConstants.orderStatusReady || o.orderStatus == AppConstants.orderStatusDelivered).length;
    final allArrived = s.orders.isNotEmpty && arrivedCount == s.orders.length;

    return Scaffold(
      appBar: AppBar(
        title: Text('shipment_cargo_number'.trParams({'number': s.shipmentNumber})),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'print_shipment_invoices_tooltip'.i18n(),
            onPressed: () {
              PrintOptionsSheet.show(
                context,
                allOrders: s.orders,
                shipmentTitle: s.title,
                title: 'print_shipment_invoices_title'.trParams({'number': s.shipmentNumber}),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AddEditShipmentScreen(shipmentToEdit: s)),
              );
              if (res == true) {
                if (context.mounted) {
                  context.read<ShipmentsBloc>().add(const LoadShipments());
                  try {
                    context.read<OrdersBloc>().add(const LoadOrders());
                  } catch (_) {}
                }
                _loadShipment();
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // بطاقة معلومات الشحنة
          AppleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        s.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppleBadge(
                      label: AppConstants.getShipmentStatusLabel(s.status),
                      color: AppConstants.getShipmentStatusColor(s.status),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (s.carrierName != null && s.carrierName!.isNotEmpty)
                  Text('shipment_carrier_fmt'.trParams({'name': s.carrierName!}), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                if (s.trackingNumber != null && s.trackingNumber!.isNotEmpty)
                  Text('shipment_waybill_fmt'.trParams({'no': s.trackingNumber!}), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                // شريط الخط الزمني للمحطات الثلاث
                ShipmentTimelineStepBar(
                  currentStep: currentStep,
                  onAdvanceStatus: _advanceStatus,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // بطاقة الحسبة المالية وصافي الأرباح
          ShipmentFinancialSummaryCard(
            shipment: s,
            viewCurrency: _shipmentViewCurrency,
            onCurrencyChanged: (code) => setState(() => _shipmentViewCurrency = code),
          ),

          const SizedBox(height: 16),

          // بطاقة التحقق من وصول كافة الطلبات الفردية ضمن الشحنة المجمعة
          if (s.orders.isNotEmpty) ...[
            AppleCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: allArrived
                                  ? AppColors.primaryGreen.withValues(alpha: 0.12)
                                  : AppColors.primaryBlue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              allArrived ? Icons.verified_rounded : Icons.fact_check_outlined,
                              size: 18,
                              color: allArrived ? AppColors.primaryGreen : AppColors.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'shipment_arrival_verification_title'.i18n(),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      AppleBadge(
                        label: '$arrivedCount / ${s.orders.length}',
                        color: allArrived ? AppColors.primaryGreen : AppColors.primaryBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: s.orders.isEmpty ? 0 : (arrivedCount / s.orders.length),
                      backgroundColor: context.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        allArrived ? AppColors.primaryGreen : AppColors.primaryBlue,
                      ),
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          allArrived
                              ? 'shipment_all_orders_arrived'.i18n()
                              : 'shipment_orders_arrived_count'.trParams({
                                  'arrived': '$arrivedCount',
                                  'total': '${s.orders.length}',
                                }),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: allArrived ? FontWeight.bold : FontWeight.normal,
                            color: allArrived ? AppColors.primaryGreen : context.textSecondary,
                          ),
                        ),
                      ),
                      if (!allArrived)
                        AppSecondaryButton(
                          label: 'shipment_verify_all_orders'.i18n(),
                          icon: Icons.done_all_rounded,
                          height: 32,
                          borderRadius: 8,
                          onPressed: _verifyAllOrders,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // قائمة الطلبات الفردية المضمنة في هذه الشحنة
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'shipment_orders_in_cargo'.trParams({'count': s.orders.length.toString()}),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ...s.orders.map((o) {
            final isArrived = o.orderStatus == AppConstants.orderStatusReady ||
                o.orderStatus == AppConstants.orderStatusDelivered;

            return AppleCard(
              margin: const EdgeInsets.only(bottom: 8),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)),
                );
              },
              child: Row(
                children: [
                  // زر التحقق من وصول الطلب الفردي أو إرجاعه
                  IconButton(
                    icon: Icon(
                      isArrived ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: isArrived ? AppColors.primaryGreen : AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 22,
                    ),
                    tooltip: isArrived
                        ? 'shipment_order_mark_in_cargo'.i18n()
                        : 'shipment_order_mark_arrived'.i18n(),
                    onPressed: () => _toggleOrderArrival(o),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '#${o.orderNumber} - ${o.customerName ?? "customer_quick_default".i18n()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppleBadge(
                              label: AppConstants.getOrderStatusLabel(o.orderStatus),
                              color: AppConstants.getOrderStatusColor(o.orderStatus),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'order_items_and_status_fmt'.trParams({
                                'count': o.items.length.toString(),
                                'status': AppConstants.getPaymentStatusLabel(o.paymentStatus),
                              }),
                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            Text(
                              _currencyService.formatAmount(o.totalSellPrice, currencyCode: o.currency),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // قائمة الإجراءات: تغيير يدوي / إرجاع لأوضاع سابقة / إزالة من الشحنة
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onSelected: (val) {
                      if (val == 'status') {
                        _showChangeOrderStatusSheet(o);
                      } else if (val == 'remove') {
                        _confirmRemoveOrder(o);
                      } else if (val == 'details') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            const Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.primaryBlue),
                            const SizedBox(width: 8),
                            Text('shipment_order_change_status'.i18n(), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'remove',
                        child: Row(
                          children: [
                            const Icon(Icons.link_off_rounded, size: 18, color: AppColors.statusDanger),
                            const SizedBox(width: 8),
                            Text(
                              'shipment_order_remove_from_cargo'.i18n(),
                              style: const TextStyle(fontSize: 12, color: AppColors.statusDanger),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'details',
                        child: Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 18, color: AppColors.textPrimary),
                            const SizedBox(width: 8),
                            Text('order_details'.i18n(), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

