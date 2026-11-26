import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants.dart';
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../reports/domain/monthly_insights_service.dart';

/// مولّد تقرير الملخص الشهري كصفحة PDF واحدة أنيقة بخط IBMPlexSansArabic واتجاه RTL
class MonthlyReportPdfGenerator {
  static const PdfColor _navy = PdfColor.fromInt(0xFF0F2C59);
  static const PdfColor _primaryBlue = PdfColor.fromInt(0xFF1A56DB);
  static const PdfColor _green = PdfColor.fromInt(0xFF15803D);
  static const PdfColor _red = PdfColor.fromInt(0xFFB91C1C);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF64748B);
  static const PdfColor _surfaceLight = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFE2E8F0);

  static Future<Uint8List> generateMonthlyPdf({
    required MonthlyInsightsReport report,
    required String currencyCode,
  }) async {
    final pdf = pw.Document();

    final regularFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    );
    final riyalFontData = await rootBundle.load(
      'assets/fonts/SaudiRiyalSymbol.ttf',
    );
    final ttfRegular = pw.Font.ttf(regularFontData);
    final ttfBold = pw.Font.ttf(boldFontData);
    final ttfRiyal = pw.Font.ttf(riyalFontData);
    final baseTheme = pw.ThemeData.withFont(
      base: ttfRegular,
      bold: ttfBold,
      fontFallback: [ttfRiyal],
    );

    final prefs = PreferencesService.instance;
    final businessName = prefs.getBusinessName().trim().isNotEmpty
        ? prefs.getBusinessName().trim()
        : 'app_name'.i18n();
    final businessPhone = prefs.getBusinessPhone().trim();
    final currencyService = CurrencyService.instance;

    String formatMoney(double amountYer) {
      final converted = currencyService.fromBaseYer(amountYer, currencyCode);
      final formatted = NumberFormat('#,##0.##').format(converted);
      final symbol = _currencyLabel(currencyCode);
      return '$formatted $symbol';
    }

    final monthLabel = DateFormat('MMMM yyyy', 'ar').format(
      DateTime(report.year, report.month, 1),
    );
    final generatedDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final changePercent = report.salesChangePercent;
    final changeText = changePercent == null
        ? null
        : '${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: baseTheme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        footer: (pw.Context context) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Divider(color: _borderColor, thickness: 0.7),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '${'monthly_personal_drawings'.i18n()}: ${formatMoney(report.personalDrawingsYer)}',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: _mutedText,
                  ),
                ),
                pw.Text(
                  '$generatedDate  •  ${context.pageNumber}/${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8.5,
                    color: _mutedText,
                  ),
                ),
              ],
            ),
          ],
        ),
        build: (pw.Context context) {
          final hasResaleVsMfg =
              report.resaleSalesYer > 0 || report.manufacturedSalesYer > 0;
          final hasExpensesBreakdown = report.businessExpensesYer > 0 &&
              (report.expensesByCategory.isNotEmpty ||
                  report.pettyCashExpensesYer > 0 ||
                  report.recurringExpensesYer > 0 ||
                  report.oneTimeExpensesYer > 0);

          return [
            // 1. ترويسة التقرير: اسم المشروع ورقم الهاتف والشهر
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _navy,
                borderRadius: pw.BorderRadius.circular(10),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessName,
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      if (businessPhone.isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          businessPhone,
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'monthly_report_title'.i18n(),
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text(
                        monthLabel,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey200,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // 2. المؤشرات الأربعة الرئيسية
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildKpiBox(
                    title: 'monthly_total_sales'.i18n(),
                    value: formatMoney(report.totalSalesYer),
                    accent: _primaryBlue,
                    badge: changeText,
                    badgePositive: (changePercent ?? 0) >= 0,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    title: 'monthly_net_profit'.i18n(),
                    value: formatMoney(report.netProfitYer),
                    accent: report.netProfitYer >= 0 ? _green : _red,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    title: 'monthly_business_expenses'.i18n(),
                    value: formatMoney(report.businessExpensesYer),
                    accent: _red,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildKpiBox(
                    title: 'monthly_cash_collected'.i18n(),
                    value: formatMoney(report.cashCollectedYer),
                    accent: _navy,
                    subtitle: 'monthly_orders_count'.trParams({
                      'count': report.ordersCount.toString(),
                    }),
                  ),
                ),
              ],
            ),

            if (hasResaleVsMfg) ...[
              pw.SizedBox(height: 14),
              _buildSectionHeader('monthly_resale_vs_mfg_title'.i18n()),
              pw.SizedBox(height: 6),
              _buildResaleVsManufacturedTable(report, formatMoney),
            ],

            pw.SizedBox(height: 14),

            // 3. جدول أعلى 5 منتجات
            _buildSectionHeader('monthly_top_products_title'.i18n()),
            pw.SizedBox(height: 6),
            _buildTopProductsTable(report.topProducts, formatMoney),

            pw.SizedBox(height: 14),

            // 4. جدول أعلى 5 عملاء
            _buildSectionHeader('monthly_top_customers_title'.i18n()),
            pw.SizedBox(height: 6),
            _buildTopCustomersTable(report.topCustomers, formatMoney),

            if (hasExpensesBreakdown) ...[
              pw.SizedBox(height: 14),
              _buildSectionHeader('monthly_expenses_breakdown_title'.i18n()),
              pw.SizedBox(height: 6),
              _buildExpenseTypeSummaryRow(report, formatMoney),
              if (report.expensesByCategory.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                _buildExpensesByCategoryTable(
                  report.expensesByCategory,
                  report.businessExpensesYer,
                  formatMoney,
                ),
              ],
            ],

            if (report.topSuppliers.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              _buildSectionHeader('monthly_top_suppliers_title'.i18n()),
              pw.SizedBox(height: 6),
              _buildTopSuppliersTable(report.topSuppliers, formatMoney),
            ],

            if (report.totalWasteLossYer > 0) ...[
              pw.SizedBox(height: 14),
              _buildSectionHeader('monthly_waste_loss_pdf_title'.i18n()),
              pw.SizedBox(height: 6),
              _buildWasteLossSummaryBox(report, formatMoney),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static String _currencyLabel(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case AppConstants.currencySar:
        return AppConstants.sarSymbol;
      case AppConstants.currencyUsd:
        return AppConstants.usdSymbol;
      case AppConstants.currencyYer:
      default:
        return AppConstants.yerSymbol.i18n();
    }
  }

  static pw.Widget _buildKpiBox({
    required String title,
    required String value,
    required PdfColor accent,
    String? badge,
    bool badgePositive = true,
    String? subtitle,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _surfaceLight,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: _borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            maxLines: 1,
            style: const pw.TextStyle(fontSize: 8.5, color: _mutedText),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: accent,
            ),
          ),
          if (badge != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              badge,
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: badgePositive ? _green : _red,
              ),
            ),
          ] else if (subtitle != null) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(fontSize: 8, color: _mutedText),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _surfaceLight,
        border: pw.Border(
          right: pw.BorderSide(color: _navy, width: 3),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: _navy,
        ),
      ),
    );
  }

  static pw.Widget _buildTopProductsTable(
    List<TopProductInsight> products,
    String Function(double) formatMoney,
  ) {
    if (products.isEmpty) {
      return _buildEmptyTableBox('monthly_no_data'.i18n());
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headers: [
        '#',
        'monthly_col_product'.i18n(),
        'monthly_col_quantity'.i18n(),
        'monthly_col_sales'.i18n(),
        'monthly_col_profit'.i18n(),
      ],
      data: List<List<String>>.generate(products.take(5).length, (index) {
        final p = products[index];
        return [
          '${index + 1}',
          p.name,
          '${p.quantity}',
          formatMoney(p.totalSalesYer),
          formatMoney(p.estimatedProfitYer),
        ];
      }),
    );
  }

  static pw.Widget _buildTopCustomersTable(
    List<TopCustomerInsight> customers,
    String Function(double) formatMoney,
  ) {
    if (customers.isEmpty) {
      return _buildEmptyTableBox('monthly_no_data'.i18n());
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headers: [
        '#',
        'monthly_col_customer'.i18n(),
        'monthly_col_orders'.i18n(),
        'monthly_col_sales'.i18n(),
      ],
      data: List<List<String>>.generate(customers.take(5).length, (index) {
        final c = customers[index];
        return [
          '${index + 1}',
          c.name,
          '${c.ordersCount}',
          formatMoney(c.totalSalesYer),
        ];
      }),
    );
  }

  static pw.Widget _buildResaleVsManufacturedTable(
    MonthlyInsightsReport report,
    String Function(double) formatMoney,
  ) {
    final rows = <List<String>>[
      [
        'product_type_resale'.i18n(),
        formatMoney(report.resaleSalesYer),
        formatMoney(report.resaleProfitYer),
      ],
      [
        'product_type_manufactured'.i18n(),
        formatMoney(report.manufacturedSalesYer),
        formatMoney(report.manufacturedProfitYer),
      ],
    ];

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headers: [
        'monthly_col_type'.i18n(),
        'monthly_col_sales'.i18n(),
        'monthly_col_profit'.i18n(),
      ],
      data: rows,
    );
  }

  static pw.Widget _buildExpenseTypeSummaryRow(
    MonthlyInsightsReport report,
    String Function(double) formatMoney,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: _buildKpiBox(
            title: 'monthly_exp_petty_cash'.i18n(),
            value: formatMoney(report.pettyCashExpensesYer),
            accent: _mutedText,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiBox(
            title: 'monthly_exp_recurring'.i18n(),
            value: formatMoney(report.recurringExpensesYer),
            accent: _primaryBlue,
          ),
        ),
        pw.SizedBox(width: 8),
        pw.Expanded(
          child: _buildKpiBox(
            title: 'monthly_exp_one_time'.i18n(),
            value: formatMoney(report.oneTimeExpensesYer),
            accent: _red,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildExpensesByCategoryTable(
    Map<String, double> expensesByCategory,
    double totalBusinessExpensesYer,
    String Function(double) formatMoney,
  ) {
    if (expensesByCategory.isEmpty) {
      return _buildEmptyTableBox('monthly_no_data'.i18n());
    }

    final sorted = expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headers: [
        'monthly_col_category'.i18n(),
        'monthly_col_amount'.i18n(),
        'monthly_col_share'.i18n(),
      ],
      data: sorted.map((entry) {
        final pct = totalBusinessExpensesYer > 0
            ? (entry.value / totalBusinessExpensesYer) * 100.0
            : 0.0;
        final label = entry.key == 'other'
            ? 'exp_cat_other'.i18n()
            : entry.key.i18n();
        return [
          label,
          formatMoney(entry.value),
          '${pct.toStringAsFixed(1)}%',
        ];
      }).toList(),
    );
  }

  static pw.Widget _buildTopSuppliersTable(
    List<TopSupplierSpend> suppliers,
    String Function(double) formatMoney,
  ) {
    if (suppliers.isEmpty) {
      return _buildEmptyTableBox('monthly_no_data'.i18n());
    }

    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: _borderColor, width: 0.6),
      headerDecoration: const pw.BoxDecoration(color: _navy),
      headerStyle: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      cellAlignment: pw.Alignment.centerRight,
      headerAlignment: pw.Alignment.centerRight,
      headers: [
        '#',
        'monthly_col_supplier'.i18n(),
        'monthly_col_entries'.i18n(),
        'monthly_col_amount'.i18n(),
      ],
      data: List<List<String>>.generate(suppliers.take(5).length, (index) {
        final s = suppliers[index];
        return [
          '${index + 1}',
          s.name,
          '${s.entriesCount}',
          formatMoney(s.totalSpendYer),
        ];
      }),
    );
  }

  static pw.Widget _buildWasteLossSummaryBox(
    MonthlyInsightsReport report,
    String Function(double) formatMoney,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _surfaceLight,
        border: pw.Border.all(color: _red, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'monthly_waste_loss_subtitle'.i18n(),
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: _navy,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'monthly_waste_logs_count_fmt'.trParams({
                  'count': report.wasteLogsCount.toString(),
                }),
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: _mutedText,
                ),
              ),
            ],
          ),
          pw.Text(
            formatMoney(report.totalWasteLossYer),
            style: pw.TextStyle(
              fontSize: 11.5,
              fontWeight: pw.FontWeight.bold,
              color: _red,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEmptyTableBox(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 14),
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 9, color: _mutedText),
      ),
    );
  }
}
