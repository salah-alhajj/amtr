import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/courier.dart';
import '../../../../models/courier_settlement.dart';
import '../../../../models/individual_order.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../data/repositories/courier_repository_impl.dart';
import '../bloc/couriers_bloc.dart';
import '../widgets/add_edit_courier_sheet.dart';

/// شاشة تفاصيل عهدة مندوب التوصيل: التحصيل النقدي، تسليم الطلبات، المرتجعات، والتسوية
class CourierDetailsScreen extends StatefulWidget {
  final Courier courier;

  const CourierDetailsScreen({super.key, required this.courier});

  @override
  State<CourierDetailsScreen> createState() => _CourierDetailsScreenState();
}

class _CourierDetailsScreenState extends State<CourierDetailsScreen> {
  final CourierRepositoryImpl _repo = CourierRepositoryImpl();

  late Courier _courier;
  CourierCustodySummary? _summary;
  List<IndividualOrder> _unsettledOrders = const [];
  List<CourierSettlement> _settlements = const [];
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _courier = widget.courier;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final freshCourier = await _repo.getCourierById(_courier.id) ?? _courier;
      final results = await Future.wait([
        _repo.getCustodySummary(freshCourier),
        _repo.getCourierOrders(freshCourier.id, unsettledOnly: true),
        _repo.getSettlements(freshCourier.id),
      ]);
      if (!mounted) return;
      setState(() {
        _courier = freshCourier;
        _summary = results[0] as CourierCustodySummary;
        _unsettledOrders = results[1] as List<IndividualOrder>;
        _settlements = results[2] as List<CourierSettlement>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _refreshBlocIfAvailable() {
    try {
      context.read<CouriersBloc>().add(const LoadCouriers(silent: true));
    } catch (_) {}
  }

  Future<void> _sendWhatsAppOrShare(String message) async {
    final rawPhone = (_courier.whatsapp ?? _courier.phone ?? '').trim();
    final cleanPhone = YemenPhoneHelper.cleanForWhatsApp(rawPhone);
    final encoded = Uri.encodeComponent(message);

    bool launched = false;
    if (cleanPhone.isNotEmpty) {
      final nativeUri =
          Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
      final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
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
          }
        } catch (_) {
          launched = false;
        }
      }
    }

    if (!launched) {
      await SharePlus.instance.share(ShareParams(text: message));
    }
  }

  Future<void> _sendDispatchSheet() async {
    final assignedOrders = _unsettledOrders
        .where((o) => o.courierStatus == AppConstants.courierStatusAssigned)
        .toList();
    final targetOrders =
        assignedOrders.isNotEmpty ? assignedOrders : _unsettledOrders;

    if (targetOrders.isEmpty) {
      AppToast.showInfo(context, 'courier_dispatch_no_orders'.i18n());
      return;
    }

    final message = WhatsAppTemplateEngine.buildCourierDispatchSheetMessage(
      courierName: _courier.name,
      orders: targetOrders,
    );
    await _sendWhatsAppOrShare(message);
  }

  Future<void> _openAssignOrdersSheet() async {
    final assignable = await _repo.getAssignableOrders();
    if (!mounted) return;

    if (assignable.isEmpty) {
      AppToast.showInfo(context, 'courier_assign_empty'.i18n());
      return;
    }

    final selectedIds = <String>{};
    final feeController = TextEditingController(
      text: _courier.defaultFee > 0
          ? (_courier.defaultFee % 1 == 0
              ? _courier.defaultFee.toStringAsFixed(0)
              : _courier.defaultFee.toString())
          : '0',
    );

    final confirmed = await showAppModalSheet<bool>(
      context: context,
      title: 'courier_assign_sheet_title'.i18n(),
      subtitle: _courier.name,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final cs = CurrencyService.instance;
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: feeController,
                  label: 'courier_assign_fee_per_order'.i18n(),
                  prefixIcon: Icons.delivery_dining_outlined,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 2),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: assignable.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final order = assignable[index];
                      final isSelected = selectedIds.contains(order.id);
                      final dueText = order.remainingDebt > 0
                          ? cs.formatAmount(
                              order.remainingDebt,
                              currencyCode: order.currency,
                            )
                          : 'courier_order_prepaid_badge'.i18n();
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          setSheetState(() {
                            if (isSelected) {
                              selectedIds.remove(order.id);
                            } else {
                              selectedIds.add(order.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue.withValues(alpha: 0.08)
                                : ctx.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue
                                  : ctx.borderSubtle,
                              width: isSelected ? 1.2 : 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                activeColor: AppColors.primaryBlue,
                                onChanged: (_) {
                                  setSheetState(() {
                                    if (isSelected) {
                                      selectedIds.remove(order.id);
                                    } else {
                                      selectedIds.add(order.id);
                                    }
                                  });
                                },
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '#${order.orderNumber} — ${order.customerName ?? 'common_unspecified'.i18n()}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (order.deliveryAddress != null &&
                                        order.deliveryAddress!
                                            .trim()
                                            .isNotEmpty)
                                      Text(
                                        order.deliveryAddress!.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: ctx.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                dueText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: order.remainingDebt > 0
                                      ? AppColors.primaryBlue
                                      : AppColors.primaryGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: 'courier_assign_confirm_btn'.trParams({
                    'count': selectedIds.length.toString(),
                  }),
                  icon: Icons.local_shipping_outlined,
                  onPressed: selectedIds.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );
        },
      ),
    );

    final fee = double.tryParse(feeController.text.trim()) ?? _courier.defaultFee;
    feeController.dispose();

    if (confirmed != true || selectedIds.isEmpty || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await _repo.assignOrdersToCourier(
        courierId: _courier.id,
        orderIds: selectedIds.toList(),
        defaultFee: fee,
      );
      if (!mounted) return;
      _refreshBlocIfAvailable();
      AppToast.showSuccess(
        context,
        'courier_assign_success'.trParams({
          'count': selectedIds.length.toString(),
        }),
      );
      await _loadData();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openMarkDeliveredDialog(IndividualOrder order) async {
    final defaultCollect = order.remainingDebt;
    final defaultFee =
        order.courierFee > 0 ? order.courierFee : _courier.defaultFee;
    final collectedCtrl = TextEditingController(
      text: defaultCollect > 0
          ? (defaultCollect % 1 == 0
              ? defaultCollect.toStringAsFixed(0)
              : defaultCollect.toString())
          : '0',
    );
    final feeCtrl = TextEditingController(
      text: defaultFee > 0
          ? (defaultFee % 1 == 0
              ? defaultFee.toStringAsFixed(0)
              : defaultFee.toString())
          : '0',
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showAppModalSheet<bool>(
      context: context,
      title: 'courier_deliver_dialog_title'.trParams({
        'order': order.orderNumber,
      }),
      subtitle: order.customerName,
      child: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: collectedCtrl,
                label: 'courier_collected_amount_label'.i18n(),
                prefixIcon: Icons.payments_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters:
                    AppFormatters.positiveDecimal(decimalRange: 2),
                validator: (v) =>
                    AppValidators.positiveAmount(v, allowZero: true),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: feeCtrl,
                label: 'courier_delivery_fee_label'.i18n(),
                prefixIcon: Icons.delivery_dining_outlined,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters:
                    AppFormatters.positiveDecimal(decimalRange: 2),
                validator: (v) =>
                    AppValidators.positiveAmount(v, allowZero: true),
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'common_confirm'.i18n(),
                icon: Icons.check_circle_outline_rounded,
                backgroundColor: AppColors.primaryGreen,
                onPressed: () {
                  if (formKey.currentState?.validate() == true) {
                    Navigator.pop(context, true);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    final collected = double.tryParse(collectedCtrl.text.trim()) ?? 0.0;
    final fee = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
    collectedCtrl.dispose();
    feeCtrl.dispose();

    if (confirmed != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await _repo.markOrderDeliveredByCourier(
        order: order,
        collectedAmount: collected,
        courierFee: fee,
      );
      if (!mounted) return;
      _refreshBlocIfAvailable();
      AppToast.showSuccess(context, 'courier_delivered_success'.i18n());
      await _loadData();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openMarkReturnedDialog(IndividualOrder order) async {
    bool restoreStock = true;
    final feeCtrl = TextEditingController(text: '0');

    final confirmed = await showAppModalSheet<bool>(
      context: context,
      title: 'courier_return_dialog_title'.trParams({
        'order': order.orderNumber,
      }),
      subtitle: order.customerName,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSwitchTile(
                  title: 'courier_return_restore_stock'.i18n(),
                  subtitle: 'courier_return_restore_stock_hint'.i18n(),
                  value: restoreStock,
                  onChanged: (val) => setSheetState(() => restoreStock = val),
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: feeCtrl,
                  label: 'courier_return_fee_label'.i18n(),
                  prefixIcon: Icons.undo_rounded,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters:
                      AppFormatters.positiveDecimal(decimalRange: 2),
                ),
                const SizedBox(height: 16),
                AppPrimaryButton(
                  label: 'courier_btn_mark_returned'.i18n(),
                  icon: Icons.assignment_return_outlined,
                  backgroundColor: AppColors.statusDanger,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          );
        },
      ),
    );

    final returnFee = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
    feeCtrl.dispose();

    if (confirmed != true || !mounted) return;
    setState(() => _isBusy = true);
    try {
      await _repo.markOrderReturnedByCourier(
        order: order,
        restoreStock: restoreStock,
        returnFee: returnFee,
      );
      if (!mounted) return;
      _refreshBlocIfAvailable();
      AppToast.showWarning(context, 'courier_returned_success'.i18n());
      await _loadData();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _openSettleSheet() async {
    final summary = _summary;
    if (summary == null || summary.settleableOrdersCount == 0) return;

    final cs = CurrencyService.instance;
    final notesCtrl = TextEditingController();

    final confirmed = await showAppModalSheet<bool>(
      context: context,
      title: 'courier_settle_confirm_title'.i18n(),
      subtitle: _courier.name,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'courier_settle_summary_orders'.trParams({
                      'delivered': summary.deliveredUnsettledCount.toString(),
                      'returned': summary.returnedUnsettledCount.toString(),
                    }),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _SettlementRow(
                    label: 'courier_settle_collected'.i18n(),
                    value: cs.formatAmount(
                      summary.collectedCashYer,
                      currencyCode: AppConstants.currencyYer,
                    ),
                    valueColor: AppColors.primaryBlue,
                  ),
                  const SizedBox(height: 6),
                  _SettlementRow(
                    label: 'courier_settle_delivery_fees'.i18n(),
                    value:
                        '- ${cs.formatAmount(summary.deliveryFeesYer, currencyCode: AppConstants.currencyYer)}',
                    valueColor: AppColors.statusWarning,
                  ),
                  if (summary.returnFeesYer > 0.0001) ...[
                    const SizedBox(height: 6),
                    _SettlementRow(
                      label: 'courier_settle_return_fees'.i18n(),
                      value:
                          '- ${cs.formatAmount(summary.returnFeesYer, currencyCode: AppConstants.currencyYer)}',
                      valueColor: AppColors.statusDanger,
                    ),
                  ],
                  Divider(height: 18, color: context.borderDivider),
                  _SettlementRow(
                    label: 'courier_settle_net_remitted'.i18n(),
                    value: cs.formatAmount(
                      summary.netDueFromCourierYer,
                      currencyCode: AppConstants.currencyYer,
                    ),
                    valueColor: summary.netDueFromCourierYer >= 0
                        ? AppColors.primaryGreen
                        : AppColors.statusDanger,
                    isBold: true,
                  ),
                ],
              ),
            ),
            if (summary.totalFeesYer > 0.0001) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'courier_settle_expense_note'.i18n(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            AppTextField(
              controller: notesCtrl,
              label: 'common_notes'.i18n(),
              hint: 'courier_settle_notes_hint'.i18n(),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            AppPrimaryButton(
              label: 'courier_action_settle'.i18n(),
              icon: Icons.verified_outlined,
              backgroundColor: AppColors.primaryGreen,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    final notesText = notesCtrl.text.trim();
    notesCtrl.dispose();

    if (confirmed != true || !mounted) return;
    final deliveredCount = summary.deliveredUnsettledCount;
    final returnedCount = summary.returnedUnsettledCount;

    setState(() => _isBusy = true);
    try {
      final settlement = await _repo.settleCourier(
        courier: _courier,
        notes: notesText.isEmpty ? null : notesText,
      );
      if (!mounted) return;
      _refreshBlocIfAvailable();
      AppToast.showSuccess(context, 'courier_settle_success'.i18n());
      await _loadData();
      if (!mounted) return;
      await _showSettlementReceiptPrompt(
        settlement: settlement,
        deliveredCount: deliveredCount,
        returnedCount: returnedCount,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showSettlementReceiptPrompt({
    required CourierSettlement settlement,
    required int deliveredCount,
    required int returnedCount,
  }) async {
    final cs = CurrencyService.instance;
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: ctx.surfaceCard,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primaryGreen,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'courier_settle_receipt_dialog_title'.i18n(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${'courier_settle_net_remitted'.i18n()}: ${cs.formatAmount(settlement.netRemittedYer, currencyCode: AppConstants.currencyYer)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
              const SizedBox(height: 16),
              AppPrimaryButton(
                label: 'courier_settle_send_whatsapp_btn'.i18n(),
                customIcon: const WhatsAppIcon(size: 18),
                backgroundColor: AppColors.primaryGreen,
                onPressed: () async {
                  Navigator.pop(ctx);
                  final receiptMsg = WhatsAppTemplateEngine
                      .buildCourierSettlementReceiptMessage(
                    courierName: _courier.name,
                    deliveredCount: deliveredCount,
                    returnedCount: returnedCount,
                    collectedCashYer: settlement.collectedCashYer,
                    deliveryFeesYer: settlement.deliveryFeesYer,
                    returnFeesYer: settlement.returnFeesYer,
                    netRemittedYer: settlement.netRemittedYer,
                  );
                  await _sendWhatsAppOrShare(receiptMsg);
                },
              ),
              const SizedBox(height: 8),
              AppOutlinedButton(
                label: 'common_done'.i18n(),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editCourier() {
    AddEditCourierSheet.show(
      context,
      courierToEdit: _courier,
      onSave: (updated) async {
        await _repo.saveCourier(updated);
        if (!mounted) return;
        setState(() => _courier = updated);
        _refreshBlocIfAvailable();
        AppToast.showSuccess(context, 'courier_updated_success'.i18n());
        await _loadData();
      },
    );
  }

  Future<void> _deleteCourier() async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'courier_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (confirm != true || !mounted) return;
    await _repo.deleteCourier(_courier.id);
    if (!mounted) return;
    _refreshBlocIfAvailable();
    AppToast.showSuccess(context, 'courier_deleted_success'.i18n());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final summary = _summary ?? CourierCustodySummary(courier: _courier);
    final hasPhone = _courier.phone != null && _courier.phone!.isNotEmpty;
    final hasWa =
        (_courier.whatsapp != null && _courier.whatsapp!.isNotEmpty) ||
            hasPhone;
    final canSettle = !_isBusy && summary.settleableOrdersCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_courier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCourier,
            tooltip: 'common_edit'.i18n(),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.statusDanger,
            ),
            onPressed: _deleteCourier,
            tooltip: 'common_delete'.i18n(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // بطاقة معلومات المندوب
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.14),
                    child: const Icon(
                      Icons.delivery_dining_rounded,
                      color: AppColors.primaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _courier.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (hasPhone)
                              Text(
                                _courier.phone!,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                            if (_courier.defaultFee > 0)
                              AppBadge(
                                label:
                                    '${'courier_order_fee_label'.i18n()}: ${cs.formatAmount(_courier.defaultFee, currencyCode: _courier.currency)}',
                                color: AppColors.primaryBlue,
                                fontSize: 10,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (hasWa)
                    AppIconButton(
                      customIcon: const WhatsAppIcon(size: 19),
                      color: AppColors.primaryGreen,
                      size: 36,
                      tooltip: 'customer_whatsapp_btn'.i18n(),
                      onPressed: () async {
                        final raw =
                            (_courier.whatsapp ?? _courier.phone ?? '').trim();
                        final clean = YemenPhoneHelper.cleanForWhatsApp(raw);
                        if (clean.isEmpty) return;
                        final uri = Uri.parse('https://wa.me/$clean');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                    ),
                  if (hasPhone) ...[
                    const SizedBox(width: 6),
                    AppIconButton(
                      icon: Icons.phone_outlined,
                      color: AppColors.primaryBlue,
                      size: 36,
                      iconSize: 18,
                      tooltip: 'customer_call_btn'.i18n(),
                      onPressed: () => YemenPhoneHelper.launchPhoneCall(
                        context,
                        _courier.phone,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // بطاقة ملخص العهدة ذات الـ 3 أرقام: مع المندوب | أجور التوصيل له | الصافي لك
            _buildCustodyHeroCard(context, summary),
            const SizedBox(height: 12),

            // صف الإجراءات السريعة (Wrap آمن على 360×740)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AppPrimaryButton(
                  label: 'courier_action_assign_orders'.i18n(),
                  icon: Icons.playlist_add_check_rounded,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onPressed: _isBusy ? null : _openAssignOrdersSheet,
                ),
                AppSecondaryButton(
                  label: 'courier_action_dispatch_whatsapp'.i18n(),
                  customIcon: const WhatsAppIcon(size: 17),
                  color: AppColors.primaryGreen,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  onPressed: _isBusy ? null : _sendDispatchSheet,
                ),
                AppPrimaryButton(
                  label: 'courier_action_settle'.i18n(),
                  icon: Icons.account_balance_wallet_outlined,
                  backgroundColor: AppColors.primaryGreen,
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  isLoading: _isBusy,
                  onPressed: canSettle ? _openSettleSheet : null,
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_isLoading)
              AppShimmer.list(itemCount: 3)
            else ...[
              // الطلبات المفتوحة (غير المسوّاة)
              _buildSectionHeader(
                title: 'courier_unsettled_orders_title'.i18n(),
                count: _unsettledOrders.length,
                icon: Icons.local_shipping_outlined,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(height: 8),
              if (_unsettledOrders.isEmpty)
                _buildEmptyHint('courier_no_unsettled_orders'.i18n())
              else
                ..._unsettledOrders.map(_buildOrderCard),

              const SizedBox(height: 20),

              // سجل التسويات السابقة
              _buildSectionHeader(
                title: 'courier_settlements_history_title'.i18n(),
                count: _settlements.length,
                icon: Icons.history_rounded,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(height: 8),
              if (_settlements.isEmpty)
                _buildEmptyHint('courier_no_settlements'.i18n())
              else
                ..._settlements.map(_buildSettlementCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCustodyHeroCard(
    BuildContext context,
    CourierCustodySummary summary,
  ) {
    final cs = CurrencyService.instance;
    final isNegativeNet = summary.netDueFromCourierYer < -0.0001;
    final netLabel = isNegativeNet
        ? 'courier_metric_owed_to_courier'.i18n()
        : 'courier_metric_net_due'.i18n();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroMetricBox(
                  label: 'courier_metric_with_courier'.i18n(),
                  value: cs.formatAmount(
                    summary.collectedCashYer,
                    currencyCode: AppConstants.currencyYer,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.22),
              ),
              Expanded(
                child: _HeroMetricBox(
                  label: 'courier_metric_delivery_fees'.i18n(),
                  value: cs.formatAmount(
                    summary.totalFeesYer,
                    currencyCode: AppConstants.currencyYer,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 44,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: Colors.white.withValues(alpha: 0.22),
              ),
              Expanded(
                child: _HeroMetricBox(
                  label: netLabel,
                  value: cs.formatAmount(
                    summary.netDueFromCourierYer.abs(),
                    currencyCode: AppConstants.currencyYer,
                  ),
                  highlight: true,
                ),
              ),
            ],
          ),
          if (summary.activeOrdersCount > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'courier_in_transit_banner'.trParams({
                  'count': summary.activeOrdersCount.toString(),
                  'amount': cs.formatAmount(
                    summary.expectedCollectYer,
                    currencyCode: AppConstants.currencyYer,
                  ),
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(IndividualOrder order) {
    final cs = CurrencyService.instance;
    final isAssigned =
        order.courierStatus == AppConstants.courierStatusAssigned;
    final isDelivered =
        order.courierStatus == AppConstants.courierStatusDelivered;

    final statusLabel = isDelivered
        ? 'courier_status_delivered'.i18n()
        : (isAssigned
            ? 'courier_status_assigned'.i18n()
            : 'courier_status_returned'.i18n());
    final statusColor = isDelivered
        ? AppColors.primaryGreen
        : (isAssigned ? AppColors.primaryBlue : AppColors.statusDanger);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '#${order.orderNumber} — ${order.customerName ?? 'common_unspecified'.i18n()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(label: statusLabel, color: statusColor, fontSize: 10.5),
            ],
          ),
          if (order.deliveryAddress != null &&
              order.deliveryAddress!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 13,
                  color: context.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.deliveryAddress!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Text(
                order.remainingDebt > 0
                    ? '${'courier_order_due_label'.i18n()}: ${cs.formatAmount(order.remainingDebt, currencyCode: order.currency)}'
                    : '${'common_total'.i18n()}: ${cs.formatAmount(order.totalSellPrice, currencyCode: order.currency)} (${'courier_order_prepaid_badge'.i18n()})',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: order.remainingDebt > 0
                      ? AppColors.primaryBlue
                      : AppColors.primaryGreen,
                ),
              ),
              if (order.courierFee > 0)
                Text(
                  '${'courier_order_fee_label'.i18n()}: ${cs.formatAmount(order.courierFee, currencyCode: _courier.currency)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                  ),
                ),
            ],
          ),
          if (isAssigned) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppPrimaryButton(
                    label: 'courier_btn_mark_delivered'.i18n(),
                    icon: Icons.check_circle_outline_rounded,
                    backgroundColor: AppColors.primaryGreen,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed:
                        _isBusy ? null : () => _openMarkDeliveredDialog(order),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppOutlinedButton(
                    label: 'courier_btn_mark_returned'.i18n(),
                    icon: Icons.assignment_return_outlined,
                    color: AppColors.statusDanger,
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    onPressed:
                        _isBusy ? null : () => _openMarkReturnedDialog(order),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSettlementCard(CourierSettlement s) {
    final cs = CurrencyService.instance;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('yyyy/MM/dd — HH:mm').format(s.settledAt),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'courier_settlement_orders_count'.trParams({
                        'count': s.orderCount.toString(),
                      }),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                cs.formatAmount(
                  s.netRemittedYer,
                  currencyCode: AppConstants.currencyYer,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: s.netRemittedYer >= 0
                      ? AppColors.primaryGreen
                      : AppColors.statusDanger,
                ),
              ),
              const SizedBox(width: 6),
              AppIconButton(
                customIcon: const WhatsAppIcon(size: 16),
                color: AppColors.primaryGreen,
                size: 32,
                tooltip: 'courier_settle_send_whatsapp_btn'.i18n(),
                onPressed: () async {
                  final msg = WhatsAppTemplateEngine
                      .buildCourierSettlementReceiptMessage(
                    courierName: _courier.name,
                    deliveredCount: s.orderCount,
                    returnedCount: 0,
                    collectedCashYer: s.collectedCashYer,
                    deliveryFeesYer: s.deliveryFeesYer,
                    returnFeesYer: s.returnFeesYer,
                    netRemittedYer: s.netRemittedYer,
                  );
                  await _sendWhatsAppOrShare(msg);
                },
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${'courier_settle_collected'.i18n()}: ${cs.formatAmount(s.collectedCashYer, currencyCode: AppConstants.currencyYer)}',
                style: TextStyle(fontSize: 11.5, color: context.textSecondary),
              ),
              Text(
                '${'courier_settle_delivery_fees'.i18n()}: ${cs.formatAmount(s.deliveryFeesYer + s.returnFeesYer, currencyCode: AppConstants.currencyYer)}',
                style: TextStyle(fontSize: 11.5, color: context.textSecondary),
              ),
            ],
          ),
          if (s.notes != null && s.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              s.notes!.trim(),
              style: TextStyle(fontSize: 11.5, color: context.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        AppBadge(label: '$count', color: color),
      ],
    );
  }

  Widget _buildEmptyHint(String text) {
    return AppCard(
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: context.textSecondary),
        ),
      ),
    );
  }
}

class _HeroMetricBox extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _HeroMetricBox({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.86),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: highlight ? 14.5 : 13.5,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _SettlementRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isBold;

  const _SettlementRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 13.5 : 12.5,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 14.5 : 13,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
