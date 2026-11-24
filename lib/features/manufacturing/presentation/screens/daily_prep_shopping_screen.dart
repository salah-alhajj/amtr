import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/expense.dart';
import '../../../expenses/data/repositories/expense_repository_impl.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../data/repositories/raw_material_repository.dart';
import '../../domain/daily_prep_shopping_service.dart';
import '../widgets/record_waste_sheet.dart';

enum _PrepDateMode { today, tomorrow, upcoming2Days }

/// شاشة ورقة التجهيز اليومية وقائمة مشتريات المواد الخام المجمّعة حسب المورد
class DailyPrepAndShoppingScreen extends StatefulWidget {
  const DailyPrepAndShoppingScreen({super.key});

  @override
  State<DailyPrepAndShoppingScreen> createState() =>
      _DailyPrepAndShoppingScreenState();
}

class _DailyPrepAndShoppingScreenState extends State<DailyPrepAndShoppingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _service = DailyPrepShoppingService();
  final _expenseRepo = ExpenseRepositoryImpl();
  final _materialRepo = RawMaterialRepository();

  _PrepDateMode _dateMode = _PrepDateMode.today;
  DailyPrepPlan? _plan;
  bool _isLoading = true;
  final Set<String> _checkedPrepKeys = {};
  final Set<String> _checkedShoppingKeys = {};
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPlan();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!mounted) return;
      if (domain == DataDomain.orders ||
          domain == DataDomain.products ||
          domain == DataDomain.materials ||
          domain == DataDomain.suppliers) {
        _loadPlan();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlan() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final DailyPrepPlan plan;
      switch (_dateMode) {
        case _PrepDateMode.today:
          plan = await _service.buildPlanForDate(now);
          break;
        case _PrepDateMode.tomorrow:
          plan = await _service.buildPlanForDate(
            now.add(const Duration(days: 1)),
          );
          break;
        case _PrepDateMode.upcoming2Days:
          plan = await _service.buildPlanForUpcomingDays(days: 2);
          break;
      }
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatQty(double qty) {
    if (qty == qty.roundToDouble()) return qty.toStringAsFixed(0);
    final fixed = qty.toStringAsFixed(2);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String _shoppingLineKey(ShoppingMaterialLine line) {
    return '${line.supplierId ?? line.supplierName}|${line.materialId ?? line.name}|${line.unit}';
  }

  String _prepItemKey(PrepProductSummary item) {
    return item.productId ?? item.productName;
  }

  String _dateLabel() {
    final now = DateTime.now();
    final fmt = DateFormat('yyyy/MM/dd');
    switch (_dateMode) {
      case _PrepDateMode.today:
        return '${'prep_date_today'.i18n()} (${fmt.format(now)})';
      case _PrepDateMode.tomorrow:
        return '${'prep_date_tomorrow'.i18n()} (${fmt.format(now.add(const Duration(days: 1)))})';
      case _PrepDateMode.upcoming2Days:
        return 'prep_date_upcoming_2d'.i18n();
    }
  }

  Future<void> _launchWhatsAppOrShare({
    required String message,
    String? phone,
  }) async {
    final cleanPhone =
        YemenPhoneHelper.cleanForWhatsApp(phone).replaceAll(RegExp(r'[^0-9]'), '');

    if (cleanPhone.isEmpty) {
      await SharePlus.instance.share(ShareParams(text: message));
      return;
    }

    final encoded = Uri.encodeComponent(message);
    final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');
    final webUri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');

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
        }
      } catch (_) {
        launched = false;
      }
    }

    if (!launched) {
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        AppToast.showInfo(
          context,
          'customer_whatsapp_copied_msg'.i18n(),
          title: 'customer_whatsapp_copied_title'.i18n(),
        );
      }
    }
  }

  Future<void> _shareFullShoppingList() async {
    final plan = _plan;
    if (plan == null || plan.shoppingLines.isEmpty) return;

    final cs = CurrencyService.instance;
    final groupedLines = <String>[];

    for (final entry in plan.shoppingBySupplier.entries) {
      final actionable = entry.value.where((l) => l.toBuyQty > 0).toList();
      final linesToInclude = actionable.isNotEmpty ? actionable : entry.value;
      groupedLines.add('*[${entry.key}]*');
      for (final l in linesToInclude) {
        final qtyStr = _formatQty(l.toBuyQty > 0 ? l.toBuyQty : l.requiredQty);
        final costPart = l.estimatedCost > 0
            ? ' (~${cs.formatAmount(l.estimatedCost, currencyCode: l.currency)})'
            : '';
        groupedLines.add('• ${l.name}: $qtyStr ${l.unit}$costPart');
      }
      groupedLines.add('');
    }

    final msg = WhatsAppTemplateEngine.buildShoppingListMessage(
      groupedLines: groupedLines,
      dateLabel: _dateLabel(),
    );
    await SharePlus.instance.share(ShareParams(text: msg));
  }

  Future<void> _sendSupplierWhatsApp(
    String supplierName,
    List<ShoppingMaterialLine> lines,
  ) async {
    final actionable = lines.where((l) => l.toBuyQty > 0).toList();
    final selected = actionable.isNotEmpty ? actionable : lines;

    final itemLines = selected.map((l) {
      final qtyStr = _formatQty(l.toBuyQty > 0 ? l.toBuyQty : l.requiredQty);
      return '${l.name} — $qtyStr ${l.unit}';
    }).toList();

    final msg = WhatsAppTemplateEngine.buildSupplierRestockMessage(
      supplierName: supplierName,
      itemLines: itemLines,
    );

    final phone = lines
        .map((l) => l.supplierPhone)
        .firstWhere((p) => p != null && p.trim().isNotEmpty, orElse: () => null);

    await _launchWhatsAppOrShare(message: msg, phone: phone);
  }

  Future<void> _logSupplierPurchaseAsExpense(
    String supplierName,
    List<ShoppingMaterialLine> lines,
  ) async {
    final cs = CurrencyService.instance;
    final checkedInGroup =
        lines.where((l) => _checkedShoppingKeys.contains(_shoppingLineKey(l))).toList();
    final targetLines = checkedInGroup.isNotEmpty
        ? checkedInGroup
        : lines.where((l) => l.toBuyQty > 0).toList();
    final effectiveLines = targetLines.isNotEmpty ? targetLines : lines;

    final defaultCurrency = effectiveLines.isNotEmpty
        ? effectiveLines.first.currency
        : PreferencesService.instance.getDefaultCurrency();
    double totalInCurrency = 0.0;
    for (final l in effectiveLines) {
      final qty = l.toBuyQty > 0 ? l.toBuyQty : l.requiredQty;
      final unitEst = l.toBuyQty > 0 && l.estimatedCost > 0
          ? l.estimatedCost
          : (l.estimatedCost > 0 ? l.estimatedCost : qty * 0.0);
      totalInCurrency += cs.convert(
        amount: unitEst,
        fromCurrency: l.currency,
        toCurrency: defaultCurrency,
      );
    }

    final amountCtrl = TextEditingController(
      text: totalInCurrency > 0 ? _formatQty(totalInCurrency) : '',
    );
    bool restockMaterials = true;
    final supplierId = lines
        .map((l) => l.supplierId)
        .firstWhere((id) => id != null && id.isNotEmpty, orElse: () => null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'prep_log_expense_dialog_title'.i18n(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      supplierName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: ctx.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: amountCtrl,
                      label:
                          '${'prep_log_expense_amount_label'.i18n()} (${AppConstants.getCurrencySymbol(defaultCurrency)})',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters:
                          AppFormatters.positiveDecimal(decimalRange: 2),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'prep_log_expense_restock_toggle'.i18n(),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      value: restockMaterials,
                      onChanged: (v) =>
                          setDialogState(() => restockMaterials = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common_cancel'.i18n()),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (parsed <= 0) {
                      AppToast.showError(ctx, 'form_validation_failed'.i18n());
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text('common_save'.i18n()),
                ),
              ],
            );
          },
        );
      },
    );

    final paidAmount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
    amountCtrl.dispose();

    if (confirmed != true || paidAmount <= 0 || !mounted) return;

    final itemSummary = effectiveLines
        .map((l) =>
            '${l.name} (${_formatQty(l.toBuyQty > 0 ? l.toBuyQty : l.requiredQty)} ${l.unit})')
        .join('، ');

    final expense = Expense(
      id: const Uuid().v4(),
      title: 'prep_expense_title_fmt'.trParams({'supplier': supplierName}),
      category: 'exp_cat_materials',
      expenseType: AppConstants.expenseTypeBusiness,
      amount: paidAmount,
      currency: defaultCurrency,
      expenseDate: DateTime.now(),
      notes: itemSummary,
      supplierId: supplierId,
    );
    await _expenseRepo.createExpense(expense);

    if (restockMaterials) {
      for (final l in effectiveLines) {
        if (l.materialId == null || l.materialId!.isEmpty) continue;
        final boughtQty = l.toBuyQty > 0 ? l.toBuyQty : l.requiredQty;
        if (boughtQty <= 0) continue;
        final existing = await _materialRepo.getById(l.materialId!);
        if (existing != null) {
          await _materialRepo.save(
            existing.copyWith(stockQuantity: existing.stockQuantity + boughtQty),
          );
        }
      }
    }

    if (mounted) {
      AppToast.showSuccess(context, 'prep_log_expense_success'.i18n());
      await _loadPlan();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('prep_screen_title'.i18n()),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'waste_sheet_title'.i18n(),
            onPressed: () => RecordWasteSheet.show(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.checklist_rtl_rounded, size: 18),
              text: 'prep_tab_sheet'.i18n(),
            ),
            Tab(
              icon: const Icon(Icons.shopping_basket_outlined, size: 18),
              text: 'prep_tab_shopping'.i18n(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildDateChip(_PrepDateMode.today, 'prep_date_today'.i18n()),
                  const SizedBox(width: 8),
                  _buildDateChip(
                    _PrepDateMode.tomorrow,
                    'prep_date_tomorrow'.i18n(),
                  ),
                  const SizedBox(width: 8),
                  _buildDateChip(
                    _PrepDateMode.upcoming2Days,
                    'prep_date_upcoming_2d'.i18n(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? AppShimmer.list(itemCount: 4)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPrepSheetTab(),
                      _buildShoppingListTab(cs),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(_PrepDateMode mode, String label) {
    return AppFilterChip(
      label: label,
      isSelected: _dateMode == mode,
      activeColor: AppColors.primaryBlue,
      onSelected: (_) {
        if (_dateMode != mode) {
          setState(() => _dateMode = mode);
          _loadPlan();
        }
      },
    );
  }

  Widget _buildPrepSheetTab() {
    final plan = _plan;
    if (plan == null || plan.prepItems.isEmpty) {
      return EmptyStateView(
        icon: Icons.checklist_rtl_rounded,
        title: 'prep_empty_title'.i18n(),
        subtitle: 'prep_empty_subtitle'.i18n(),
      );
    }

    final totalUnits =
        plan.prepItems.fold<int>(0, (sum, item) => sum + item.totalQty);

    return RefreshIndicator(
      onRefresh: _loadPlan,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: plan.prepItems.length + 1,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              backgroundColor: context.primaryBlue.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 18,
                    color: context.primaryBlue,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dateLabel(),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'prep_summary_products_fmt'.trParams({
                            'products': plan.prepItems.length.toString(),
                            'units': totalUnits.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          final item = plan.prepItems[idx - 1];
          final key = _prepItemKey(item);
          final isDone = _checkedPrepKeys.contains(key);

          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () {
              setState(() {
                if (isDone) {
                  _checkedPrepKeys.remove(key);
                } else {
                  _checkedPrepKeys.add(key);
                }
              });
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: isDone,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedPrepKeys.add(key);
                          } else {
                            _checkedPrepKeys.remove(key);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Text(
                        item.productName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          decoration:
                              isDone ? TextDecoration.lineThrough : null,
                          color: isDone
                              ? context.textSecondary
                              : context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        AppBadge(
                          label: '×${item.totalQty}',
                          color: AppColors.primaryBlue,
                          fontSize: 12,
                        ),
                        if (item.batchCount > 0 && item.batchCount != item.totalQty)
                          AppBadge(
                            label: 'prep_batches_badge_fmt'.trParams({
                              'count': item.batchCount.toString(),
                            }),
                            color: AppColors.vibrantTeal,
                            fontSize: 10.5,
                          ),
                        if (item.awaitingDepositCount > 0)
                          AppBadge(
                            label: 'prep_awaiting_deposit_badge'.i18n(),
                            color: AppColors.statusWarning,
                            icon: Icons.hourglass_top_rounded,
                            fontSize: 10.5,
                          ),
                      ],
                    ),
                  ],
                ),
                if (item.customerNotes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusWarning.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.statusWarning.withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.sticky_note_2_outlined,
                              size: 14,
                              color: AppColors.statusWarning,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'prep_customer_notes_label'.i18n(),
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statusWarning,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...item.customerNotes.map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '• $note',
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textPrimary,
                              ),
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
        },
      ),
    );
  }

  Widget _buildShoppingListTab(CurrencyService cs) {
    final plan = _plan;
    if (plan == null || plan.shoppingLines.isEmpty) {
      return EmptyStateView(
        icon: Icons.shopping_basket_outlined,
        title: 'prep_shopping_empty_title'.i18n(),
        subtitle: 'prep_shopping_empty_subtitle'.i18n(),
      );
    }

    final displayCurrency = cs.activeDisplayCurrency;
    final displayTotal = cs.fromBaseYer(
      plan.totalEstimatedCostYer,
      displayCurrency,
    );
    final supplierEntries = plan.shoppingBySupplier.entries.toList();

    return RefreshIndicator(
      onRefresh: _loadPlan,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: supplierEntries.length + 1,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              backgroundColor: context.primaryGreen.withValues(alpha: 0.08),
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
                              'prep_shopping_est_total_label'.i18n(),
                              style: TextStyle(
                                fontSize: 12,
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cs.formatAmount(
                                displayTotal,
                                currencyCode: displayCurrency,
                              ),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: context.primaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _shareFullShoppingList,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                    ),
                    icon: const WhatsAppIcon(size: 16, color: Colors.white),
                    label: Text(
                      'prep_share_shopping_wa_btn'.i18n(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }

          final entry = supplierEntries[idx - 1];
          return _buildSupplierShoppingCard(entry.key, entry.value, cs);
        },
      ),
    );
  }

  Widget _buildSupplierShoppingCard(
    String supplierName,
    List<ShoppingMaterialLine> lines,
    CurrencyService cs,
  ) {
    final displayCurrency = cs.activeDisplayCurrency;
    double groupTotalYer = 0.0;
    for (final l in lines) {
      groupTotalYer += cs.toBaseYer(l.estimatedCost, l.currency);
    }
    final groupDisplayTotal = cs.fromBaseYer(groupTotalYer, displayCurrency);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.local_shipping_outlined,
                size: 18,
                color: AppColors.vibrantTeal,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  supplierName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (groupTotalYer > 0)
                AppBadge(
                  label: cs.formatAmount(
                    groupDisplayTotal,
                    currencyCode: displayCurrency,
                  ),
                  color: AppColors.primaryBlue,
                  fontSize: 11,
                ),
            ],
          ),
          const Divider(height: 16),
          ...lines.map((line) {
            final lineKey = _shoppingLineKey(line);
            final checked = _checkedShoppingKeys.contains(lineKey);
            final isSufficient = line.toBuyQty <= 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  setState(() {
                    if (checked) {
                      _checkedShoppingKeys.remove(lineKey);
                    } else {
                      _checkedShoppingKeys.add(lineKey);
                    }
                  });
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: checked,
                      visualDensity: VisualDensity.compact,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _checkedShoppingKeys.add(lineKey);
                          } else {
                            _checkedShoppingKeys.remove(lineKey);
                          }
                        });
                      },
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      decoration: checked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: checked
                                          ? context.textSecondary
                                          : context.textPrimary,
                                    ),
                                  ),
                                ),
                                if (line.estimatedCost > 0)
                                  Text(
                                    cs.formatAmount(
                                      line.estimatedCost,
                                      currencyCode: line.currency,
                                    ),
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: context.primaryBlue,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                AppBadge(
                                  label: 'prep_req_qty_fmt'.trParams({
                                    'qty': _formatQty(line.requiredQty),
                                    'unit': line.unit,
                                  }),
                                  color: AppColors.deepNavy,
                                  fontSize: 10,
                                ),
                                if (line.inStockQty > 0)
                                  AppBadge(
                                    label: 'prep_instock_qty_fmt'.trParams({
                                      'qty': _formatQty(line.inStockQty),
                                      'unit': line.unit,
                                    }),
                                    color: AppColors.vibrantTeal,
                                    fontSize: 10,
                                  ),
                                AppBadge(
                                  label: isSufficient
                                      ? 'prep_in_stock_sufficient'.i18n()
                                      : 'prep_tobuy_qty_fmt'.trParams({
                                          'qty': _formatQty(line.toBuyQty),
                                          'unit': line.unit,
                                        }),
                                  color: isSufficient
                                      ? AppColors.primaryGreen
                                      : AppColors.statusWarning,
                                  fontSize: 10,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _sendSupplierWhatsApp(supplierName, lines),
                icon: const WhatsAppIcon(size: 15, color: AppColors.primaryGreen),
                label: Text(
                  'prep_send_supplier_wa_btn'.i18n(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () =>
                    _logSupplierPurchaseAsExpense(supplierName, lines),
                icon: const Icon(Icons.receipt_long_outlined, size: 16),
                label: Text(
                  'prep_log_purchase_expense_btn'.i18n(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
