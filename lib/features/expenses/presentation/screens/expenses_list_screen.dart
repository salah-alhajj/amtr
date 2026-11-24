import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/expense.dart';
import '../../../suppliers/data/repositories/supplier_repository_impl.dart';
import '../bloc/expenses_bloc.dart';
import '../widgets/add_edit_expense_sheet.dart';

class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key});

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final SupplierRepositoryImpl _supplierRepo = SupplierRepositoryImpl();
  Map<String, String> _supplierNames = const {};
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadSupplierNames();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (domain == DataDomain.suppliers && mounted) {
        _loadSupplierNames();
      }
    });
  }

  Future<void> _loadSupplierNames() async {
    try {
      final list = await _supplierRepo.getAllSuppliers();
      if (!mounted) return;
      final map = <String, String>{};
      for (final s in list) {
        map[s.id] = s.name;
      }
      setState(() => _supplierNames = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _previewReceiptPhoto(String path) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AppPhotoLightboxDialog(
        photos: [path],
        initialIndex: 0,
      ),
    );
  }

  void _openAddEditSheet([Expense? expense]) {
    AddEditExpenseSheet.show(
      context,
      expenseToEdit: expense,
      onSave: (saved) {
        if (expense == null) {
          context.read<ExpensesBloc>().add(CreateExpenseEvent(saved));
          AppToast.showSuccess(context, 'expense_added_success'.i18n());
        } else {
          context.read<ExpensesBloc>().add(UpdateExpenseEvent(saved));
          AppToast.showSuccess(context, 'expense_updated_success'.i18n());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final activeCurrency = cs.activeDisplayCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Text('expenses_title'.i18n()),
      ),
      body: BlocBuilder<ExpensesBloc, ExpensesState>(
        builder: (context, state) {
          final selectedCategory =
              state is ExpensesLoaded ? state.selectedCategory : 'all';
          final selectedFrequency =
              state is ExpensesLoaded ? state.selectedFrequency : 'all';

          return Column(
            children: [
              if (state is ExpensesLoaded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: AppCard(
                    backgroundColor: AppColors.statusDanger.withValues(alpha: 0.07),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.statusDanger.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.account_balance_wallet_outlined,
                                color: AppColors.statusDanger,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'expenses_total_label'.i18n(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    cs.formatAmount(
                                      cs.fromBaseYer(state.totalInYer, activeCurrency),
                                      currencyCode: activeCurrency,
                                    ),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.statusDanger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${state.displayedExpenses.length}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (state.pettyCashTotalInYer > 0 ||
                            state.dailyTotalInYer > 0 ||
                            state.weeklyTotalInYer > 0 ||
                            state.monthlyTotalInYer > 0) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (state.pettyCashTotalInYer > 0)
                                _buildMiniMetricBadge(
                                  'expense_petty_cash_label'.i18n(),
                                  cs.formatAmount(
                                    cs.fromBaseYer(
                                        state.pettyCashTotalInYer, activeCurrency),
                                    currencyCode: activeCurrency,
                                  ),
                                  const Color(0xFFD97706),
                                ),
                              if (state.dailyTotalInYer > 0)
                                _buildMiniMetricBadge(
                                  'expense_recurrence_daily'.i18n(),
                                  cs.formatAmount(
                                    cs.fromBaseYer(
                                        state.dailyTotalInYer, activeCurrency),
                                    currencyCode: activeCurrency,
                                  ),
                                  AppConstants.getExpenseRecurrenceColor(
                                      AppConstants.expenseRecurrenceDaily),
                                ),
                              if (state.weeklyTotalInYer > 0)
                                _buildMiniMetricBadge(
                                  'expense_recurrence_weekly'.i18n(),
                                  cs.formatAmount(
                                    cs.fromBaseYer(
                                        state.weeklyTotalInYer, activeCurrency),
                                    currencyCode: activeCurrency,
                                  ),
                                  AppConstants.getExpenseRecurrenceColor(
                                      AppConstants.expenseRecurrenceWeekly),
                                ),
                              if (state.monthlyTotalInYer > 0)
                                _buildMiniMetricBadge(
                                  'expense_recurrence_monthly'.i18n(),
                                  cs.formatAmount(
                                    cs.fromBaseYer(
                                        state.monthlyTotalInYer, activeCurrency),
                                    currencyCode: activeCurrency,
                                  ),
                                  AppConstants.getExpenseRecurrenceColor(
                                      AppConstants.expenseRecurrenceMonthly),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'expenses_search_hint'.i18n(),
                  onChanged: (val) =>
                      context.read<ExpensesBloc>().add(SearchExpenses(val)),
                  onClear: () =>
                      context.read<ExpensesBloc>().add(const SearchExpenses('')),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFrequencyChip(
                        'status_all'.i18n(), 'all', selectedFrequency),
                    _buildFrequencyChip('expense_petty_cash_label'.i18n(),
                        'petty_cash', selectedFrequency),
                    _buildFrequencyChip('expense_recurrence_daily'.i18n(),
                        AppConstants.expenseRecurrenceDaily, selectedFrequency),
                    _buildFrequencyChip('expense_recurrence_weekly'.i18n(),
                        AppConstants.expenseRecurrenceWeekly, selectedFrequency),
                    _buildFrequencyChip('expense_recurrence_monthly'.i18n(),
                        AppConstants.expenseRecurrenceMonthly, selectedFrequency),
                    _buildFrequencyChip('expense_recurrence_once'.i18n(),
                        AppConstants.expenseRecurrenceOnce, selectedFrequency),
                  ],
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildCategoryChip('status_all'.i18n(), 'all', selectedCategory),
                    ...AppConstants.expenseCategories.map(
                      (cat) => _buildCategoryChip(cat.i18n(), cat, selectedCategory),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context, state, cs)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'expenses_fab',
        onPressed: () => _openAddEditSheet(),
        backgroundColor: AppColors.statusDanger,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'expense_add_title'.i18n(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMiniMetricBadge(String label, String amount, Color color) {
    return AppBadge(
      label: '$label: $amount',
      color: color,
      fontSize: 10.5,
    );
  }

  Widget _buildFrequencyChip(String label, String value, String current) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: AppFilterChip(
        label: label,
        isSelected: value == current,
        activeColor: AppColors.primaryBlue,
        onSelected: (_) {
          context.read<ExpensesBloc>().add(FilterExpensesByFrequency(value));
        },
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, String current) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: AppFilterChip(
        label: label,
        isSelected: value == current,
        activeColor: AppColors.statusDanger,
        onSelected: (_) {
          context.read<ExpensesBloc>().add(FilterExpensesByCategory(value));
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ExpensesState state,
    CurrencyService cs,
  ) {
    if (state is ExpensesLoading || state is ExpensesInitial) {
      return AppShimmer.list(itemCount: 5);
    }
    if (state is ExpensesError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => context.read<ExpensesBloc>().add(const LoadExpenses()),
      );
    }
    if (state is ExpensesLoaded) {
      if (state.displayedExpenses.isEmpty) {
        return EmptyStateView(
          icon: Icons.receipt_long_outlined,
          title: 'expenses_empty_title'.i18n(),
          subtitle: 'expenses_empty_subtitle'.i18n(),
          actionLabel: 'expense_add_title'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () => _openAddEditSheet(),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<ExpensesBloc>().add(const LoadExpenses());
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: state.displayedExpenses.length,
          itemBuilder: (context, idx) {
            final e = state.displayedExpenses[idx];
            final supplierName =
                e.supplierId != null ? _supplierNames[e.supplierId!] : null;
            return AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => _openAddEditSheet(e),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            AppBadge(
                              label: e.isPersonalDrawing
                                  ? 'expense_type_personal'.i18n()
                                  : e.category.i18n(),
                              color: e.isPersonalDrawing
                                  ? const Color(0xFFB45309)
                                  : AppColors.statusWarning,
                              fontSize: 10,
                            ),
                            if (e.isPettyCash)
                              AppBadge(
                                label: 'expense_petty_cash_label'.i18n(),
                                color: const Color(0xFFD97706),
                                fontSize: 10,
                              ),
                            if (e.isRecurring)
                              AppBadge(
                                label: AppConstants.getExpenseRecurrenceLabel(
                                    e.recurrence),
                                color: AppConstants.getExpenseRecurrenceColor(
                                    e.recurrence),
                                icon: Icons.repeat_rounded,
                                fontSize: 10,
                              ),
                            if (supplierName != null)
                              AppBadge(
                                label: supplierName,
                                color: AppColors.vibrantTeal,
                                icon: Icons.local_shipping_outlined,
                                fontSize: 10,
                              ),
                            if (e.receiptPhotoPath != null &&
                                e.receiptPhotoPath!.isNotEmpty)
                              Tooltip(
                                message:
                                    'expense_receipt_preview_tooltip'.i18n(),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () =>
                                      _previewReceiptPhoto(e.receiptPhotoPath!),
                                  child: AppBadge(
                                    label: 'expense_receipt_badge'.i18n(),
                                    color: AppColors.primaryBlue,
                                    icon: Icons.receipt_outlined,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 13,
                              color: context.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                DateFormat('yyyy/MM/dd').format(e.expenseDate),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cs.formatAmount(e.amount, currencyCode: e.currency),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: e.isPersonalDrawing
                                      ? const Color(0xFFB45309)
                                      : AppColors.statusDanger,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (e.notes != null && e.notes!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.notes!,
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
                  const SizedBox(width: 4),
                  if (e.isRecurring)
                    IconButton(
                      icon: const Icon(
                        Icons.repeat_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                      tooltip: 'expense_log_again_today'.i18n(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final repeated = e.copyWith(
                          id: const Uuid().v4(),
                          recurrence: AppConstants.expenseRecurrenceOnce,
                          parentRuleId: e.id,
                          expenseDate: DateTime.now(),
                          createdAt: DateTime.now(),
                        );
                        context
                            .read<ExpensesBloc>()
                            .add(CreateExpenseEvent(repeated));
                        AppToast.showSuccess(
                            context, 'expense_logged_again_toast'.i18n());
                      },
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.statusDanger,
                      size: 20,
                    ),
                    onPressed: () async {
                      final confirm = await showAppConfirmationDialog(
                        context: context,
                        title: 'common_delete'.i18n(),
                        message: 'expense_delete_confirm'.i18n(),
                        isDestructive: true,
                      );
                      if (confirm == true && context.mounted) {
                        context
                            .read<ExpensesBloc>()
                            .add(DeleteExpenseEvent(e.id));
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
