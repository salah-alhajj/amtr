import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/daily_closing.dart';
import '../../../../models/expense.dart';
import '../../../expenses/presentation/screens/expenses_list_screen.dart';
import '../../../expenses/presentation/widgets/add_edit_expense_sheet.dart';
import '../../../suppliers/presentation/screens/suppliers_list_screen.dart';
import '../../data/repositories/daily_closing_repository.dart';
import '../../domain/repositories/cashbox_repository.dart';
import '../cubit/cashbox_cubit.dart';
import '../widgets/daily_closing_sheet.dart';

/// شاشة الصندوق اليومي: تعرض دخل اليوم ومصاريف الشغل والسحب الشخصي للبيت والمتبقي في الدرج
class CashBoxScreen extends StatefulWidget {
  final CashBoxCubit? cubit;

  const CashBoxScreen({super.key, this.cubit});

  @override
  State<CashBoxScreen> createState() => _CashBoxScreenState();
}

class _CashBoxScreenState extends State<CashBoxScreen> {
  // لون محايد دافئ للسحب الشخصي (أخذت للبيت) حتى لا يظهر كخسارة
  static const Color _personalNeutralWarm = Color(0xFFB45309);
  static const Color _personalNeutralWarmBg = Color(0xFFFEF3C7);

  late final CashBoxCubit _cubit;
  bool _ownsCubit = false;
  final DailyClosingRepository _closingRepo = DailyClosingRepository();
  DailyClosing? _currentDateClosing;
  List<DailyClosing> _recentClosings = const [];
  DateTime? _lastLoadedClosingDate;
  final Set<String> _loggingRuleIds = {};

  @override
  void initState() {
    super.initState();
    if (widget.cubit != null) {
      _cubit = widget.cubit!;
    } else {
      try {
        _cubit = context.read<CashBoxCubit>();
        if (_cubit.state is CashBoxInitial) {
          _cubit.loadDate(DateTime.now());
        }
      } catch (_) {
        _ownsCubit = true;
        _cubit = CashBoxCubit()..loadDate(DateTime.now());
      }
    }
    _loadClosings(_cubit.selectedDate);
  }

  Future<void> _loadClosings(DateTime date) async {
    _lastLoadedClosingDate = DateTime(date.year, date.month, date.day);
    try {
      final closing = await _closingRepo.getClosingForDate(date);
      final recent = await _closingRepo.getRecentClosings(limit: 14);
      if (!mounted) return;
      setState(() {
        _currentDateClosing = closing;
        _recentClosings = recent;
      });
    } catch (_) {
      // تجاهل أخطاء التهيئة المبدئية أثناء الاختبارات المعزولة
    }
  }

  Future<void> _openDailyClosingSheet(
    DateTime date,
    DailyCashBoxSummary summary,
  ) async {
    final closed = await DailyClosingSheet.show(
      context,
      date: date,
      summary: summary,
      existingClosing: _currentDateClosing,
    );
    if (closed == true && mounted) {
      await _loadClosings(date);
      await _cubit.loadDate(date);
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _pickDate(DateTime current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(now) ? now : current,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null && mounted) {
      await _cubit.loadDate(picked);
    }
  }

  void _openQuickExpenseSheet(String expenseType) {
    AddEditExpenseSheet.show(
      context,
      initialExpenseType: expenseType,
      onSave: (expense) async {
        await _cubit.recordExpense(expense);
        if (mounted) {
          AppToast.showSuccess(context, 'expense_added_success'.i18n());
        }
      },
    );
  }

  Future<void> _logDueRecurringExpense(
    Expense rule,
    DateTime selectedDate,
  ) async {
    if (_loggingRuleIds.contains(rule.id)) return;
    setState(() => _loggingRuleIds.add(rule.id));
    try {
      final now = DateTime.now();
      final logged = rule.copyWith(
        id: const Uuid().v4(),
        recurrence: AppConstants.expenseRecurrenceOnce,
        parentRuleId: rule.id,
        expenseDate: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          now.hour,
          now.minute,
        ),
        createdAt: now,
      );
      await _cubit.recordExpense(logged);
      if (mounted) {
        AppToast.showSuccess(
          context,
          'cashbox_due_recurring_logged_toast'.i18n(),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loggingRuleIds.remove(rule.id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final activeCurrency = cs.activeDisplayCurrency;

    return BlocProvider<CashBoxCubit>.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(
          title: Text('cashbox_title'.i18n()),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExpensesListScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long_outlined, size: 18),
              label: Text('cashbox_view_all_expenses'.i18n()),
            ),
          ],
        ),
        body: BlocConsumer<CashBoxCubit, CashBoxState>(
          listener: (context, state) {
            if (state is CashBoxLoaded) {
              final normalized = DateTime(
                state.selectedDate.year,
                state.selectedDate.month,
                state.selectedDate.day,
              );
              if (_lastLoadedClosingDate != normalized) {
                _loadClosings(state.selectedDate);
              }
            }
          },
          builder: (context, state) {
            final selectedDate = state is CashBoxLoaded
                ? state.selectedDate
                : _cubit.selectedDate;
            final isToday = _isSameDay(selectedDate, DateTime.now());

            return Column(
              children: [
                _buildDayNavigator(context, selectedDate, isToday),
                Expanded(
                  child: _buildContent(context, state, cs, activeCurrency),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDayNavigator(
    BuildContext context,
    DateTime selectedDate,
    bool isToday,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        borderRadius: 14,
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => _cubit.previousDay(),
              tooltip: 'common_previous'.i18n(),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _pickDate(selectedDate),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormat('yyyy/MM/dd').format(selectedDate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 8),
                        AppBadge(
                          label: 'quick_order_delivery_today'.i18n(),
                          color: AppColors.primaryBlue,
                          fontSize: 10,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => _cubit.nextDay(),
              tooltip: 'common_next'.i18n(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    CashBoxState state,
    CurrencyService cs,
    String activeCurrency,
  ) {
    if (state is CashBoxLoading || state is CashBoxInitial) {
      return AppShimmer.list(itemCount: 4);
    }
    if (state is CashBoxError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => _cubit.loadDate(_cubit.selectedDate),
      );
    }
    if (state is! CashBoxLoaded) {
      return const SizedBox.shrink();
    }

    final summary = state.summary;

    return RefreshIndicator(
      onRefresh: () => _cubit.loadDate(state.selectedDate),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildSummaryCard(context, summary, cs, activeCurrency),
          if (summary.totalSupplierPayablesYer > 0) ...[
            const SizedBox(height: 10),
            _buildSupplierPayablesTile(
              context,
              summary.totalSupplierPayablesYer,
              state.selectedDate,
              cs,
              activeCurrency,
            ),
          ],
          if (summary.dueRecurringExpenses.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDueRecurringCard(
              context,
              summary.dueRecurringExpenses,
              state.selectedDate,
              cs,
            ),
          ],
          const SizedBox(height: 12),
          _buildQuickActionButtons(context),
          const SizedBox(height: 10),
          _buildDailyCloseButton(context, state.selectedDate, summary),
          const SizedBox(height: 16),
          AppSectionHeader(
            title: 'cashbox_movements_title'.i18n(),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            trailing: Text(
              '${summary.movements.length}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (summary.movements.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: EmptyStateView(
                icon: Icons.account_balance_wallet_outlined,
                title: 'cashbox_no_movements'.i18n(),
              ),
            )
          else
            ...summary.movements.map(
              (m) => _buildMovementTile(context, m, cs),
            ),
          if (_recentClosings.isNotEmpty) ...[
            const SizedBox(height: 18),
            AppSectionHeader(
              title: 'daily_close_history_title'.i18n(),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              trailing: Text(
                '${_recentClosings.length}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ..._recentClosings.map(
              (closing) => _buildClosingHistoryTile(
                context,
                closing,
                cs,
                activeCurrency,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    DailyCashBoxSummary summary,
    CurrencyService cs,
    String activeCurrency,
  ) {
    final netFormatted = cs.formatAmount(
      cs.fromBaseYer(summary.netDrawerYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    final inFormatted = cs.formatAmount(
      cs.fromBaseYer(summary.cashInYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    final businessOutFormatted = cs.formatAmount(
      cs.fromBaseYer(summary.businessExpensesYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    final personalOutFormatted = cs.formatAmount(
      cs.fromBaseYer(summary.personalDrawingsYer, activeCurrency),
      currencyCode: activeCurrency,
    );

    final isNegative = summary.netDrawerYer < 0;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isNegative
                          ? AppColors.statusWarning
                          : AppColors.primaryGreen)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.point_of_sale_rounded,
                  color: isNegative
                      ? AppColors.statusWarning
                      : AppColors.primaryGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'cashbox_net_drawer'.i18n(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      netFormatted,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isNegative
                            ? AppColors.statusWarning
                            : context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: context.borderDivider),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatPill(
                  context,
                  label: 'cashbox_today_in'.i18n(),
                  value: inFormatted,
                  color: AppColors.statusSuccess,
                  bgColor: AppColors.statusSuccess.withValues(alpha: 0.10),
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatPill(
                  context,
                  label: 'cashbox_business_out'.i18n(),
                  value: businessOutFormatted,
                  color: AppColors.statusDanger,
                  bgColor: AppColors.statusDanger.withValues(alpha: 0.10),
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildStatPill(
                  context,
                  label: 'cashbox_personal_out'.i18n(),
                  value: personalOutFormatted,
                  color: _personalNeutralWarm,
                  bgColor: context.isDarkMode
                      ? _personalNeutralWarm.withValues(alpha: 0.16)
                      : _personalNeutralWarmBg,
                  icon: Icons.home_outlined,
                ),
              ),
            ],
          ),
          if (summary.pettyCashExpensesYer > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD97706).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFFD97706).withValues(alpha: 0.25),
                  width: 0.7,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bolt_rounded,
                    size: 14,
                    color: Color(0xFFD97706),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'cashbox_petty_cash_included'.i18n(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cs.formatAmount(
                        cs.fromBaseYer(
                          summary.pettyCashExpensesYer,
                          activeCurrency,
                        ),
                        currencyCode: activeCurrency,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFD97706),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplierPayablesTile(
    BuildContext context,
    double totalPayablesYer,
    DateTime selectedDate,
    CurrencyService cs,
    String activeCurrency,
  ) {
    const warmAmber = Color(0xFFD97706);
    final formatted = cs.formatAmount(
      cs.fromBaseYer(totalPayablesYer, activeCurrency),
      currencyCode: activeCurrency,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      backgroundColor: warmAmber.withValues(
        alpha: context.isDarkMode ? 0.14 : 0.08,
      ),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SuppliersListScreen(),
          ),
        );
        if (mounted) {
          await _cubit.loadDate(selectedDate);
        }
      },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: warmAmber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: warmAmber,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'cashbox_supplier_payables_title'.i18n(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              formatted,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: warmAmber,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 13,
            color: context.textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildDueRecurringCard(
    BuildContext context,
    List<Expense> dueRules,
    DateTime selectedDate,
    CurrencyService cs,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'cashbox_due_recurring_title'.i18n(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              AppBadge(
                label: '${dueRules.length}',
                color: AppColors.primaryBlue,
                fontSize: 10.5,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...dueRules.asMap().entries.map((entry) {
            final idx = entry.key;
            final rule = entry.value;
            final isLogging = _loggingRuleIds.contains(rule.id);
            final recColor =
                AppConstants.getExpenseRecurrenceColor(rule.recurrence);
            return Padding(
              padding: EdgeInsets.only(top: idx == 0 ? 0 : 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rule.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                cs.formatAmount(
                                  rule.amount,
                                  currencyCode: rule.currency,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.statusDanger,
                                ),
                              ),
                              AppBadge(
                                label: AppConstants.getExpenseRecurrenceLabel(
                                  rule.recurrence,
                                ),
                                color: recColor,
                                fontSize: 9.5,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Material(
                      color: isLogging
                          ? AppColors.primaryBlue.withValues(alpha: 0.5)
                          : AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: isLogging
                            ? null
                            : () => _logDueRecurringExpense(rule, selectedDate),
                        borderRadius: BorderRadius.circular(10),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: 34,
                            maxWidth: 112,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            child: Center(
                              widthFactor: 1,
                              child: isLogging
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'cashbox_log_due_btn'.i18n(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required Color bgColor,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AppPrimaryButton(
            label: 'cashbox_add_business_expense'.i18n(),
            icon: Icons.storefront_outlined,
            backgroundColor: AppColors.primaryBlue,
            height: 46,
            onPressed: () =>
                _openQuickExpenseSheet(AppConstants.expenseTypeBusiness),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppPrimaryButton(
            label: 'cashbox_add_personal_drawing'.i18n(),
            icon: Icons.home_outlined,
            backgroundColor: _personalNeutralWarm,
            height: 46,
            onPressed: () =>
                _openQuickExpenseSheet(AppConstants.expenseTypePersonal),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyCloseButton(
    BuildContext context,
    DateTime date,
    DailyCashBoxSummary summary,
  ) {
    final isClosed = _currentDateClosing != null;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            isClosed ? Icons.verified_rounded : Icons.lock_clock_outlined,
            color: isClosed ? AppColors.statusSuccess : AppColors.primaryGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'daily_close_title'.i18n(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isClosed) ...[
                      const SizedBox(width: 8),
                      AppBadge(
                        label: 'daily_close_already_closed'.i18n(),
                        color: AppColors.statusSuccess,
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'daily_close_subtitle'.i18n(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          AppPrimaryButton(
            label: 'daily_close_btn'.i18n(),
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            backgroundColor: AppColors.primaryGreen,
            onPressed: () => _openDailyClosingSheet(date, summary),
          ),
        ],
      ),
    );
  }

  Widget _buildClosingHistoryTile(
    BuildContext context,
    DailyClosing closing,
    CurrencyService cs,
    String activeCurrency,
  ) {
    final netFormatted = cs.formatAmount(
      cs.fromBaseYer(closing.netDrawerYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.statusSuccess.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 18,
              color: AppColors.statusSuccess,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  closing.closingDate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (closing.notes != null && closing.notes!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    closing.notes!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                netFormatted,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 2),
              AppBadge(
                label: 'daily_close_already_closed'.i18n(),
                color: AppColors.statusSuccess,
                fontSize: 10,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMovementTile(
    BuildContext context,
    CashBoxMovement movement,
    CurrencyService cs,
  ) {
    final Color color;
    final IconData icon;
    final String typeLabel;
    final String sign;

    switch (movement.type) {
      case CashBoxMovementType.cashIn:
        color = AppColors.statusSuccess;
        icon = Icons.arrow_downward_rounded;
        typeLabel = 'cashbox_today_in'.i18n();
        sign = '+';
        break;
      case CashBoxMovementType.businessExpense:
        color = AppColors.statusDanger;
        icon = Icons.arrow_upward_rounded;
        typeLabel = 'cashbox_business_out'.i18n();
        sign = '-';
        break;
      case CashBoxMovementType.personalDrawing:
        color = _personalNeutralWarm;
        icon = Icons.home_outlined;
        typeLabel = 'cashbox_personal_out'.i18n();
        sign = '-';
        break;
    }

    final displayTitle =
        movement.title.isNotEmpty ? movement.title : typeLabel;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      label: typeLabel,
                      color: color,
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                    ),
                    Text(
                      DateFormat('HH:mm').format(movement.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$sign${cs.formatAmount(movement.amount, currencyCode: movement.currency)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
