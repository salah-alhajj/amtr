import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/consolidated_shipment.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../data/repositories/shipment_repository_impl.dart';
import '../../domain/repositories/shipment_repository.dart';
import '../widgets/order_assignment_card.dart';

class AddEditShipmentScreen extends StatefulWidget {
  final ConsolidatedShipment? shipmentToEdit;

  const AddEditShipmentScreen({super.key, this.shipmentToEdit});

  @override
  State<AddEditShipmentScreen> createState() => _AddEditShipmentScreenState();
}

class _AddEditShipmentScreenState extends State<AddEditShipmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ShipmentRepository _shipmentRepo = ShipmentRepositoryImpl();
  final OrderRepository _orderRepo = OrderRepositoryImpl();

  late String _shipmentNumber;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _carrierController = TextEditingController();
  final TextEditingController _trackingController = TextEditingController();
  final TextEditingController _transportCostController = TextEditingController(
    text: '0',
  );
  final TextEditingController _notesController = TextEditingController();

  String _transportCurrency = AppConstants.currencyYer;
  String _status = AppConstants.shipmentDispatched;
  DateTime _createdAt = DateTime.now();
  DateTime? _expectedDeliveryDate;
  DateTime? _actualDeliveryDate;

  List<IndividualOrder> _availableOrders = [];
  final Set<String> _selectedOrderIds = {};
  bool _isLoading = true;

  @override
  void dispose() {
    _titleController.dispose();
    _carrierController.dispose();
    _trackingController.dispose();
    _transportCostController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableOrders();

    if (widget.shipmentToEdit != null) {
      final s = widget.shipmentToEdit!;
      _shipmentNumber = s.shipmentNumber;
      _titleController.text = s.title;
      _carrierController.text = s.carrierName ?? '';
      _trackingController.text = s.trackingNumber ?? '';
      _transportCostController.text = s.transportCost.toString();
      _transportCurrency = s.transportCostCurrency;
      _status = s.status;
      _createdAt = s.createdAt;
      _expectedDeliveryDate = s.expectedDeliveryDate;
      _actualDeliveryDate = s.actualDeliveryDate;
      _notesController.text = s.notes ?? '';
      _selectedOrderIds.addAll(s.orders.map((o) => o.id));
    } else {
      _shipmentNumber = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(8);
    }
  }

  Future<void> _loadAvailableOrders() async {
    final unassigned = await _orderRepo.getUnassignedOrders();
    List<IndividualOrder> allEligible = List.from(unassigned);

    if (widget.shipmentToEdit != null) {
      final currentOrders = await _orderRepo.getOrdersByShipmentId(
        widget.shipmentToEdit!.id,
      );
      for (final order in currentOrders) {
        if (!allEligible.any((o) => o.id == order.id)) {
          allEligible.add(order);
        }
      }
    }

    setState(() {
      _availableOrders = allEligible;
      _isLoading = false;
    });
  }

  Future<void> _saveShipment() async {
    if (!_formKey.currentState!.validate()) {
      AppToast.error(context, 'form_validation_failed'.i18n());
      return;
    }

    final id = widget.shipmentToEdit?.id ?? const Uuid().v4();
    final cost = double.tryParse(_transportCostController.text) ?? 0.0;

    final shipment = ConsolidatedShipment(
      id: id,
      shipmentNumber: _shipmentNumber,
      title: _titleController.text.trim(),
      carrierName: _carrierController.text.trim(),
      trackingNumber: _trackingController.text.trim(),
      transportCost: cost,
      transportCostCurrency: _transportCurrency,
      status: _status,
      createdAt: _createdAt,
      expectedDeliveryDate: _expectedDeliveryDate,
      actualDeliveryDate: _actualDeliveryDate,
      notes: _notesController.text.trim(),
    );

    if (widget.shipmentToEdit != null) {
      await _shipmentRepo.updateShipment(shipment, _selectedOrderIds.toList());
    } else {
      await _shipmentRepo.saveShipment(shipment, _selectedOrderIds.toList());
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.shipmentToEdit != null
              ? 'shipment_edit_title'.trParams({'number': _shipmentNumber})
              : 'shipment_create_title'.i18n(),
        ),
        leading: const BackButton(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // بيانات الشحنة والنقل
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'shipment_cargo_info'.i18n(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _titleController,
                          label: 'shipment_route_label'.i18n(),
                          hint: 'shipment_route_example'.i18n(),
                          prefixIcon: Icons.route_outlined,
                          inputFormatters: AppFormatters.generalText(
                            maxLength: 80,
                          ),
                          validator: AppValidators.shipmentRoute,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: _carrierController,
                                label: 'shipment_carrier_name'.i18n(),
                                prefixIcon: Icons.local_shipping_outlined,
                                inputFormatters: AppFormatters.generalText(
                                  maxLength: 60,
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AppTextField(
                                controller: _trackingController,
                                label: 'shipment_tracking_number'.i18n(),
                                prefixIcon: Icons.receipt_long_outlined,
                                inputFormatters: AppFormatters.trackingNumber(
                                  maxLength: 35,
                                ),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: AppTextField(
                                controller: _transportCostController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                label: 'shipment_transport_cost'.i18n(),
                                prefixIcon: Icons.payments_outlined,
                                inputFormatters: AppFormatters.positiveDecimal(
                                  decimalRange: 2,
                                ),
                                validator: (val) =>
                                    AppValidators.positiveAmount(
                                      val,
                                      allowZero: true,
                                    ),
                                textInputAction: TextInputAction.done,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: AppDropdownField<String>(
                                value: _transportCurrency,
                                label: 'shipment_transport_currency'.i18n(),
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
                                onChanged: (val) =>
                                    setState(() => _transportCurrency = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppDropdownField<String>(
                          value: _status,
                          label: 'shipment_arrival_status'.i18n(),
                          items: [
                            DropdownMenuItem(
                              value: AppConstants.shipmentDispatched,
                              child: Text(
                                AppConstants.getShipmentStatusLabel(
                                  AppConstants.shipmentDispatched,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.shipmentCheckpoint,
                              child: Text(
                                AppConstants.getShipmentStatusLabel(
                                  AppConstants.shipmentCheckpoint,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: AppConstants.shipmentDistribution,
                              child: Text(
                                AppConstants.getShipmentStatusLabel(
                                  AppConstants.shipmentDistribution,
                                ),
                                style: TextStyle(
                                  fontFamily: 'IBMPlexSansArabic',
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(() => _status = val!),
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
                                        DateTime.now().add(
                                          const Duration(days: 5),
                                        ),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2035),
                                  );
                                  if (picked != null) {
                                    setState(
                                      () => _expectedDeliveryDate = picked,
                                    );
                                  }
                                },
                                icon: Icons.event_outlined,
                                label: _expectedDeliveryDate == null
                                    ? 'shipment_expected_arrival'.i18n()
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
                                    setState(
                                      () => _actualDeliveryDate = picked,
                                    );
                                  }
                                },
                                icon: Icons.check_circle_outline,
                                label: _actualDeliveryDate == null
                                    ? 'shipment_actual_arrival'.i18n()
                                    : '${_actualDeliveryDate!.year}/${_actualDeliveryDate!.month}/${_actualDeliveryDate!.day}',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // اختيار الطلبات الفردية لضمها للحمولة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'shipment_attach_orders'.trParams({
                          'count': _selectedOrderIds.length.toString(),
                        }),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedOrderIds.length ==
                                _availableOrders.length) {
                              _selectedOrderIds.clear();
                            } else {
                              _selectedOrderIds.addAll(
                                _availableOrders.map((o) => o.id),
                              );
                            }
                          });
                        },
                        child: Text(
                          _selectedOrderIds.length == _availableOrders.length
                              ? 'shipment_deselect_all'.i18n()
                              : 'shipment_select_all'.i18n(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_availableOrders.isEmpty)
                    AppCard(
                      child: Center(
                        child: Text(
                          'shipment_no_unassigned_orders'.i18n(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._availableOrders.map((order) {
                      final isChecked = _selectedOrderIds.contains(order.id);
                      return OrderAssignmentCard(
                        order: order,
                        isSelected: isChecked,
                        onToggle: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedOrderIds.add(order.id);
                            } else {
                              _selectedOrderIds.remove(order.id);
                            }
                          });
                        },
                      );
                    }),

                  const SizedBox(height: 24),

                  AppPrimaryButton(
                    onPressed: _saveShipment,
                    backgroundColor: AppColors.primaryGreen,
                    label: widget.shipmentToEdit != null
                        ? 'shipment_save_changes'.i18n()
                        : 'shipment_confirm_create'.i18n(),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
