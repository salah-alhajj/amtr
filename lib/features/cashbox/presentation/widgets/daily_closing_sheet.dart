import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/daily_closing.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../data/repositories/cashbox_repository_impl.dart';
import '../../data/repositories/daily_closing_repository.dart';
import '../../domain/repositories/cashbox_repository.dart';

/// ورقة إغلاق اليوم في 30 ثانية: خطوتان لتأكيد التسليمات وحفظ ملخص الصندوق
class DailyClosingSheet extends StatefulWidget {
  final DateTime date;
  final DailyCashBoxSummary summary;
  final DailyClosing? existingClosing;

  const DailyClosingSheet({
    super.key,
    required this.date,
    required this.summary,
    this.existingClosing,
  });

  static Future<bool?> show(
    BuildContext context, {
    required DateTime date,
    required DailyCashBoxSummary summary,
    DailyClosing? existingClosing,
  }) {
    return showAppModalSheet<bool>(
      context: context,
      title: 'daily_close_title'.i18n(),
      subtitle: 'daily_close_subtitle'.i18n(),
      child: DailyClosingSheet(
        date: date,
        summary: summary,
        existingClosing: existingClosing,
      ),
    );
  }

  @override
  State<DailyClosingSheet> createState() => _DailyClosingSheetState();
}

class _DailyClosingSheetState extends State<DailyClosingSheet> {
  final _orderRepo = OrderRepositoryImpl();
  final _closingRepo = DailyClosingRepository();
  final _cashBoxRepo = CashBoxRepositoryImpl();
  late final TextEditingController _notesController;
  late DailyCashBoxSummary _summary;

  int _step = 0; // 0: undelivered orders, 1: summary & confirm, 2: done
  bool _isLoadingOrders = true;
  bool _isSaving = false;
  List<IndividualOrder> _pendingOrders = [];
  int _todayOrdersCount = 0;
  final Set<String> _markingIds = {};

  @override
  void initState() {
    super.initState();
    _summary = widget.summary;
    _notesController = TextEditingController(
      text: widget.existingClosing?.notes ?? '',
    );
    _loadTodayOrders();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _refreshSummary() async {
    try {
      final fresh = await _cashBoxRepo.getDailySummary(widget.date);
      if (!mounted) return;
      setState(() => _summary = fresh);
    } catch (_) {}
  }

  Future<void> _loadTodayOrders() async {
    setState(() => _isLoadingOrders = true);
    try {
      final allOrders = await _orderRepo.getAllOrders();
      final todayOrders = allOrders.where((o) {
        final createdSameDay = _isSameDay(o.createdAt, widget.date);
        final deliverySameDay = o.expectedDeliveryDate != null &&
            _isSameDay(o.expectedDeliveryDate!, widget.date);
        return createdSameDay || deliverySameDay;
      }).toList();

      final pending = todayOrders
          .where((o) => o.orderStatus != AppConstants.orderStatusDelivered)
          .toList();

      if (!mounted) return;
      setState(() {
        _todayOrdersCount = todayOrders.length;
        _pendingOrders = pending;
        _isLoadingOrders = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingOrders = false);
      }
    }
  }

  Future<bool?> _showCodCollectionPrompt(IndividualOrder order) {
    final cs = CurrencyService.instance;
    final formattedRemaining = cs.formatAmount(
      order.remainingDebt,
      currencyCode: order.currency,
    );
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor:
              isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
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
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.primaryGreen,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'daily_close_cod_prompt_title'.i18n(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ctx.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'daily_close_cod_prompt_msg'.trParams({
                    'amount': formattedRemaining,
                  }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: ctx.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                AppPrimaryButton(
                  label: 'daily_close_cod_collect_yes'.i18n(),
                  icon: Icons.check_circle_outline_rounded,
                  backgroundColor: AppColors.primaryGreen,
                  onPressed: () => Navigator.pop(ctx, true),
                ),
                const SizedBox(height: 8),
                AppOutlinedButton(
                  label: 'daily_close_cod_deliver_unpaid'.i18n(),
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('common_cancel'.i18n()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markDelivered(IndividualOrder order) async {
    bool collectRemaining = false;
    if (order.remainingDebt > 0) {
      final decision = await _showCodCollectionPrompt(order);
      if (decision == null || !mounted) return;
      collectRemaining = decision;
    }

    setState(() => _markingIds.add(order.id));
    try {
      if (collectRemaining) {
        await _orderRepo.updatePaymentStatus(
          order.id,
          AppConstants.paymentPrepaid,
          order.totalSellPrice,
        );
      }

      final updated = order.copyWith(
        paymentStatus:
            collectRemaining ? AppConstants.paymentPrepaid : order.paymentStatus,
        paidAmount: collectRemaining ? order.totalSellPrice : order.paidAmount,
        orderStatus: AppConstants.orderStatusDelivered,
        actualDeliveryDate: DateTime.now(),
      );
      await _orderRepo.updateOrder(updated, order.items);
      await _refreshSummary();

      if (!mounted) return;
      setState(() {
        _pendingOrders.removeWhere((o) => o.id == order.id);
        _markingIds.remove(order.id);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _markingIds.remove(order.id));
        AppToast.showError(context, e.toString());
      }
    }
  }

  Future<void> _confirmClosing() async {
    setState(() => _isSaving = true);
    try {
      final freshSummary = await _cashBoxRepo.getDailySummary(widget.date);
      final closing = DailyClosing(
        id: widget.existingClosing?.id ?? const Uuid().v4(),
        closingDate: DailyClosingRepository.formatClosingDate(widget.date),
        cashInYer: freshSummary.cashInYer,
        businessExpensesYer: freshSummary.businessExpensesYer,
        personalDrawingsYer: freshSummary.personalDrawingsYer,
        ordersCount: _todayOrdersCount,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        closedAt: DateTime.now(),
      );
      await _closingRepo.saveClosing(closing);
      if (!mounted) return;
      setState(() {
        _summary = freshSummary;
        _isSaving = false;
        _step = 2;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: _step == 2
            ? _buildDoneView(context)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStepHeader(context),
                  const SizedBox(height: 14),
                  if (_step == 0)
                    _buildStepOrders(context)
                  else
                    _buildStepSummary(context),
                ],
              ),
      ),
    );
  }

  Widget _buildStepHeader(BuildContext context) {
    return Row(
      children: [
        _buildStepChip(
          context,
          index: 0,
          label: '1. ${'daily_close_step_orders'.i18n()}',
          active: _step == 0,
          onTap: () => setState(() => _step = 0),
        ),
        const SizedBox(width: 8),
        _buildStepChip(
          context,
          index: 1,
          label: '2. ${'daily_close_step_summary'.i18n()}',
          active: _step == 1,
          onTap: () {
            setState(() => _step = 1);
            _refreshSummary();
          },
        ),
      ],
    );
  }

  Widget _buildStepChip(
    BuildContext context, {
    required int index,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primaryBlue.withValues(alpha: 0.14)
                : context.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? AppColors.primaryBlue : context.borderSubtle,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.primaryBlue : context.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepOrders(BuildContext context) {
    if (_isLoadingOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final cs = CurrencyService.instance;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_pendingOrders.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(16),
            backgroundColor: AppColors.statusSuccess.withValues(alpha: 0.08),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: AppColors.statusSuccess,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'daily_close_step_orders'.i18n(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '0',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.statusSuccess,
                  ),
                ),
              ],
            ),
          )
        else
          ..._pendingOrders.map((order) {
            final isMarking = _markingIds.contains(order.id);
            final title = (order.customerName?.isNotEmpty ?? false)
                ? '${order.orderNumber} • ${order.customerName}'
                : order.orderNumber;
            return AppCard(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          cs.formatAmount(
                            order.totalSellPrice,
                            currencyCode: order.currency,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppPrimaryButton(
                    label: 'daily_close_mark_delivered'.i18n(),
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: AppColors.primaryGreen,
                    isLoading: isMarking,
                    onPressed: isMarking ? null : () => _markDelivered(order),
                  ),
                ],
              ),
            );
          }),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: 'common_next'.i18n(),
          trailingIcon: Icons.arrow_forward_rounded,
          backgroundColor: AppColors.primaryBlue,
          onPressed: () {
            setState(() => _step = 1);
            _refreshSummary();
          },
        ),
      ],
    );
  }

  Widget _buildStepSummary(BuildContext context) {
    final cs = CurrencyService.instance;
    final activeCurrency = cs.activeDisplayCurrency;

    String fmt(double yer) => cs.formatAmount(
          cs.fromBaseYer(yer, activeCurrency),
          currencyCode: activeCurrency,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _buildSummaryRow(
                context,
                label: 'cashbox_today_in'.i18n(),
                value: fmt(_summary.cashInYer),
                color: AppColors.statusSuccess,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                context,
                label: 'cashbox_business_out'.i18n(),
                value: fmt(_summary.businessExpensesYer),
                color: AppColors.statusDanger,
              ),
              const SizedBox(height: 8),
              _buildSummaryRow(
                context,
                label: 'cashbox_personal_out'.i18n(),
                value: fmt(_summary.personalDrawingsYer),
                color: const Color(0xFFB45309),
              ),
              const Divider(height: 20),
              _buildSummaryRow(
                context,
                label: 'cashbox_net_drawer'.i18n(),
                value: fmt(_summary.netDrawerYer),
                color: AppColors.primaryBlue,
                isBold: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _notesController,
          label: 'common_notes'.i18n(),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        AppPrimaryButton(
          label: 'daily_close_confirm_btn'.i18n(),
          icon: Icons.lock_clock_outlined,
          backgroundColor: AppColors.primaryGreen,
          isLoading: _isSaving,
          onPressed: _isSaving ? null : _confirmClosing,
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: context.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 17 : 14,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDoneView(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusSuccess.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.statusSuccess,
              size: 44,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'daily_close_done_title'.i18n(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'daily_close_done_msg'.i18n(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          AppPrimaryButton(
            label: 'common_done'.i18n(),
            backgroundColor: AppColors.primaryBlue,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
  }
}
