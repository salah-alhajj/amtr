import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../printing/services/monthly_report_pdf_generator.dart';
import '../../domain/monthly_insights_service.dart';

/// شاشة ملخص الشهر البسيط وتصدير التقرير الشهري كـ PDF من صفحة واحدة
class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final _service = MonthlyInsightsService.instance;
  final _currencyService = CurrencyService.instance;

  late DateTime _selectedMonth;
  MonthlyInsightsReport? _report;
  bool _isLoading = true;
  bool _isExportingPdf = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final report = await _service.generateForMonth(
        _selectedMonth.year,
        _selectedMonth.month,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + delta,
        1,
      );
    });
    _loadReport();
  }

  void _resetToCurrentMonth() {
    final now = DateTime.now();
    final current = DateTime(now.year, now.month, 1);
    if (_selectedMonth.year == current.year &&
        _selectedMonth.month == current.month) {
      return;
    }
    setState(() => _selectedMonth = current);
    _loadReport();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  Future<void> _exportAndSharePdf() async {
    final report = _report;
    if (report == null || _isExportingPdf) return;

    final box = context.findRenderObject() as RenderBox?;
    final sharePositionOrigin = (box != null && box.hasSize)
        ? (box.localToGlobal(Offset.zero) & box.size)
        : null;

    setState(() => _isExportingPdf = true);
    try {
      final activeCurrency = _currencyService.activeDisplayCurrency;
      final bytes = await MonthlyReportPdfGenerator.generateMonthlyPdf(
        report: report,
        currencyCode: activeCurrency,
      );

      final tempDir = await getTemporaryDirectory();
      final monthTag =
          '${report.year}_${report.month.toString().padLeft(2, '0')}';
      final filePath = '${tempDir.path}/monthly_report_$monthTag.pdf';
      await File(filePath).writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'monthly_report_title'.i18n(),
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          'print_error_pdf'.trParams({'error': e.toString()}),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingPdf = false);
      }
    }
  }

  String _formatYer(double amountYer) {
    final activeCurrency = _currencyService.activeDisplayCurrency;
    final converted = _currencyService.fromBaseYer(amountYer, activeCurrency);
    return _currencyService.formatAmount(
      converted,
      currencyCode: activeCurrency,
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watchLocaleState();
    final localeCode = Localizations.maybeLocaleOf(context)?.languageCode ?? 'ar';
    final monthLabel = DateFormat('MMMM yyyy', localeCode).format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('monthly_report_title'.i18n()),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton.icon(
              onPressed: (_report == null || _isLoading || _isExportingPdf)
                  ? null
                  : _exportAndSharePdf,
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, size: 18),
              label: Text('monthly_export_pdf_btn'.i18n()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط مبدل الشهر (السابق / الحالي / التالي)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.surfaceCard,
              border: Border(
                bottom: BorderSide(color: context.borderDivider, width: 0.7),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => _shiftMonth(-1),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  tooltip: 'monthly_prev_month'.i18n(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (!_isCurrentMonth)
                  TextButton(
                    onPressed: _resetToCurrentMonth,
                    child: Text('monthly_current_month'.i18n()),
                  ),
                IconButton(
                  onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                  tooltip: 'monthly_next_month'.i18n(),
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return AppShimmer.dashboard();
    }

    if (_errorMessage != null) {
      return AppErrorStateView(
        message: _errorMessage!,
        onRetry: _loadReport,
      );
    }

    final report = _report;
    if (report == null) {
      return EmptyStateView(
        icon: Icons.bar_chart_rounded,
        title: 'monthly_no_data'.i18n(),
        subtitle: 'monthly_no_data_sub'.i18n(),
      );
    }

    final change = report.salesChangePercent;

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. بطاقات الملخص الأربع
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.25,
            children: [
              _SummaryKpiCard(
                title: 'monthly_total_sales'.i18n(),
                value: _formatYer(report.totalSalesYer),
                icon: Icons.point_of_sale_rounded,
                color: AppColors.primaryBlue,
                badge: change != null
                    ? AppBadge(
                        label:
                            '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%',
                        color: change >= 0
                            ? AppColors.primaryGreen
                            : AppColors.statusDanger,
                        icon: change >= 0
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        fontSize: 10,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                      )
                    : null,
              ),
              _SummaryKpiCard(
                title: 'monthly_net_profit'.i18n(),
                value: _formatYer(report.netProfitYer),
                icon: Icons.savings_rounded,
                color: report.netProfitYer >= 0
                    ? AppColors.primaryGreen
                    : AppColors.statusDanger,
                subtitle: 'monthly_profit_note'.i18n(),
              ),
              _SummaryKpiCard(
                title: 'monthly_business_expenses'.i18n(),
                value: _formatYer(report.businessExpensesYer),
                icon: Icons.receipt_long_rounded,
                color: AppColors.statusDanger,
                subtitle: report.personalDrawingsYer > 0
                    ? '${'monthly_personal_drawings'.i18n()}: ${_formatYer(report.personalDrawingsYer)}'
                    : null,
              ),
              _SummaryKpiCard(
                title: 'monthly_cash_collected'.i18n(),
                value: _formatYer(report.cashCollectedYer),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.vibrantTeal,
                subtitle: 'monthly_orders_count'.trParams({
                  'count': report.ordersCount.toString(),
                }),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 1.5 البيع والشراء مقابل التصنيع والإنتاج (يظهر فقط عند توفر بيانات)
          if (report.resaleSalesYer > 0 || report.manufacturedSalesYer > 0) ...[
            _SectionTitle(
              title: 'monthly_resale_vs_mfg_title'.i18n(),
              icon: Icons.compare_arrows_rounded,
              color: const Color(0xFF7C3AED),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _ProductTypeBreakdownCard(
                    title: 'product_type_resale'.i18n(),
                    salesText: _formatYer(report.resaleSalesYer),
                    profitText: _formatYer(report.resaleProfitYer),
                    profitPositive: report.resaleProfitYer >= 0,
                    icon: Icons.storefront_rounded,
                    color: const Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ProductTypeBreakdownCard(
                    title: 'product_type_manufactured'.i18n(),
                    salesText: _formatYer(report.manufacturedSalesYer),
                    profitText: _formatYer(report.manufacturedProfitYer),
                    profitPositive: report.manufacturedProfitYer >= 0,
                    icon: Icons.precision_manufacturing_rounded,
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          // 2. قسم أعلى 5 منتجات
          _SectionTitle(
            title: 'monthly_top_products_title'.i18n(),
            icon: Icons.star_rounded,
            color: AppColors.statusWarning,
          ),
          const SizedBox(height: 8),
          if (report.topProducts.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'monthly_no_data'.i18n(),
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < report.topProducts.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: context.borderDivider),
                    _TopProductRow(
                      rank: i + 1,
                      item: report.topProducts[i],
                      formatYer: _formatYer,
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 20),

          // 3. قسم أعلى 5 عملاء
          _SectionTitle(
            title: 'monthly_top_customers_title'.i18n(),
            icon: Icons.people_alt_rounded,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(height: 8),
          if (report.topCustomers.isEmpty)
            AppCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    'monthly_no_data'.i18n(),
                    style: TextStyle(color: context.textSecondary, fontSize: 13),
                  ),
                ),
              ),
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < report.topCustomers.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: context.borderDivider),
                    _TopCustomerRow(
                      rank: i + 1,
                      item: report.topCustomers[i],
                      formatYer: _formatYer,
                    ),
                  ],
                ],
              ),
            ),

          // 4. تفصيل المصاريف (نثريات / دورية / مرة واحدة / حسب التصنيف)
          if (report.businessExpensesYer > 0 &&
              (report.expensesByCategory.isNotEmpty ||
                  report.pettyCashExpensesYer > 0 ||
                  report.recurringExpensesYer > 0 ||
                  report.oneTimeExpensesYer > 0)) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'monthly_expenses_breakdown_title'.i18n(),
              icon: Icons.pie_chart_outline_rounded,
              color: AppColors.statusDanger,
            ),
            const SizedBox(height: 8),
            _ExpensesBreakdownCard(
              report: report,
              formatYer: _formatYer,
            ),
          ],

          // 5. أكثر الموردين تعاملاً
          if (report.topSuppliers.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'monthly_top_suppliers_title'.i18n(),
              icon: Icons.local_shipping_outlined,
              color: AppColors.vibrantTeal,
            ),
            const SizedBox(height: 8),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (int i = 0; i < report.topSuppliers.length; i++) ...[
                    if (i > 0)
                      Divider(height: 1, color: context.borderDivider),
                    _TopSupplierRow(
                      rank: i + 1,
                      item: report.topSuppliers[i],
                      formatYer: _formatYer,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // 6. الهالك والتالف (تسرب الأرباح)
          if (report.totalWasteLossYer > 0 || report.wasteLogsCount > 0) ...[
            const SizedBox(height: 20),
            _SectionTitle(
              title: 'monthly_waste_loss_title'.i18n(),
              icon: Icons.delete_sweep_outlined,
              color: AppColors.statusDanger,
            ),
            const SizedBox(height: 8),
            AppCard(
              border: Border.all(
                color: AppColors.statusDanger.withValues(alpha: 0.35),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.statusDanger.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: AppColors.statusDanger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'monthly_waste_loss_subtitle'.i18n(),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'monthly_waste_logs_count_fmt'.trParams({
                            'count': report.wasteLogsCount.toString(),
                          }),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        _formatYer(report.totalWasteLossYer),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SummaryKpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final Widget? badge;
  final String? subtitle;

  const _SummaryKpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.badge,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              ?badge,
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              color: context.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: context.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopProductRow extends StatelessWidget {
  final int rank;
  final TopProductInsight item;
  final String Function(double) formatYer;

  const _TopProductRow({
    required this.rank,
    required this.item,
    required this.formatYer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'monthly_col_quantity'.i18n()}: ${item.quantity}',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatYer(item.totalSalesYer),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              Text(
                '${'monthly_col_profit'.i18n()}: ${formatYer(item.estimatedProfitYer)}',
                style: TextStyle(
                  fontSize: 11,
                  color: item.estimatedProfitYer >= 0
                      ? AppColors.primaryGreen
                      : AppColors.statusDanger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopCustomerRow extends StatelessWidget {
  final int rank;
  final TopCustomerInsight item;
  final String Function(double) formatYer;

  const _TopCustomerRow({
    required this.rank,
    required this.item,
    required this.formatYer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.vibrantTeal.withValues(alpha: 0.14),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.vibrantTeal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${'monthly_col_orders'.i18n()}: ${item.ordersCount}',
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            formatYer(item.totalSalesYer),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTypeBreakdownCard extends StatelessWidget {
  final String title;
  final String salesText;
  final String profitText;
  final bool profitPositive;
  final IconData icon;
  final Color color;

  const _ProductTypeBreakdownCard({
    required this.title,
    required this.salesText,
    required this.profitText,
    required this.profitPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'monthly_col_sales'.i18n(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 10.5, color: context.textSecondary),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              salesText,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${'monthly_col_profit'.i18n()}: ',
                style: TextStyle(fontSize: 10.5, color: context.textSecondary),
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    profitText,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: profitPositive
                          ? AppColors.primaryGreen
                          : AppColors.statusDanger,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExpensesBreakdownCard extends StatelessWidget {
  final MonthlyInsightsReport report;
  final String Function(double) formatYer;

  const _ExpensesBreakdownCard({
    required this.report,
    required this.formatYer,
  });

  @override
  Widget build(BuildContext context) {
    final sortedCategories = report.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = report.businessExpensesYer;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (report.pettyCashExpensesYer > 0)
                AppBadge(
                  label:
                      '${'monthly_exp_petty_cash'.i18n()}: ${formatYer(report.pettyCashExpensesYer)}',
                  color: AppColors.statusWarning,
                  icon: Icons.payments_outlined,
                ),
              if (report.recurringExpensesYer > 0)
                AppBadge(
                  label:
                      '${'monthly_exp_recurring'.i18n()}: ${formatYer(report.recurringExpensesYer)}',
                  color: AppColors.primaryBlue,
                  icon: Icons.repeat_rounded,
                ),
              if (report.oneTimeExpensesYer > 0)
                AppBadge(
                  label:
                      '${'monthly_exp_one_time'.i18n()}: ${formatYer(report.oneTimeExpensesYer)}',
                  color: AppColors.statusDanger,
                  icon: Icons.receipt_outlined,
                ),
            ],
          ),
          if (sortedCategories.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: context.borderDivider),
            const SizedBox(height: 10),
            for (int i = 0; i < sortedCategories.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              _buildCategoryProgressRow(
                context,
                sortedCategories[i].key,
                sortedCategories[i].value,
                total,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryProgressRow(
    BuildContext context,
    String categoryKey,
    double amountYer,
    double totalYer,
  ) {
    final ratio = totalYer > 0 ? (amountYer / totalYer).clamp(0.0, 1.0) : 0.0;
    final percentText = '${(ratio * 100).toStringAsFixed(0)}%';
    final label =
        categoryKey == 'other' ? 'exp_cat_other'.i18n() : categoryKey.i18n();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatYer(amountYer)} ($percentText)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            backgroundColor: context.borderDivider.withValues(alpha: 0.5),
            valueColor: const AlwaysStoppedAnimation<Color>(
              AppColors.statusDanger,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopSupplierRow extends StatelessWidget {
  final int rank;
  final TopSupplierSpend item;
  final String Function(double) formatYer;

  const _TopSupplierRow({
    required this.rank,
    required this.item,
    required this.formatYer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.vibrantTeal.withValues(alpha: 0.14),
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.vibrantTeal,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'monthly_supplier_entries_fmt'.trParams({
                    'count': item.entriesCount.toString(),
                  }),
                  style: TextStyle(fontSize: 11.5, color: context.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatYer(item.totalSpendYer),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
