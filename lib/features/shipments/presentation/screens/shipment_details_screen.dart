import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/constants.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../data/repositories/shipment_repository_impl.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
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
    await _shipmentRepo.updateShipmentStatus(_shipment!.id, newStatus);
    _loadShipment();
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
              if (res == true) _loadShipment();
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    AppleBadge(
                      label: AppConstants.getShipmentStatusLabel(s.status),
                      color: currentStep == 2 ? AppColors.primaryGreen : AppColors.primaryBlue,
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

          // قائمة الطلبات الفردية المضمنة في هذه الشحنة
          Text(
            'shipment_orders_in_cargo'.trParams({'count': s.orders.length.toString()}),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          ...s.orders.map((o) => AppleCard(
                margin: const EdgeInsets.only(bottom: 8),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailsScreen(orderId: o.id)),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('#${o.orderNumber} - ${o.customerName ?? "customer_quick_default".i18n()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text('order_items_and_status_fmt'.trParams({
                          'count': o.items.length.toString(),
                          'status': AppConstants.getPaymentStatusLabel(o.paymentStatus),
                        }), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          _currencyService.formatAmount(o.totalSellPrice, currencyCode: o.currency),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryGreen),
                        ),
                        const SizedBox(width: 8),
                        const ForwardChevron(),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

