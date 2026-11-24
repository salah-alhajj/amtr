import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../models/product.dart';

/// مولد كتالوج المنتجات بصيغة PDF أنيقة باللغة العربية (RTL)
class CatalogPdfGenerator {
  CatalogPdfGenerator._();

  /// توليد مستند PDF مصنّف للمنتجات النشطة باستخدام خط IBMPlexSansArabic
  static Future<Uint8List> generateCatalogPdf(List<Product> products) async {
    final pdf = pw.Document();

    final regularFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/IBMPlexSansArabic-Bold.ttf',
    );
    final ttfRegular = pw.Font.ttf(regularFontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final baseTheme = pw.ThemeData.withFont(base: ttfRegular, bold: ttfBold);
    final prefs = PreferencesService.instance;
    final cs = CurrencyService.instance;
    final businessName = prefs.getBusinessName().trim();
    final businessPhone = prefs.getBusinessPhone().trim();
    final footerNote = prefs.getInvoiceFooterNote().trim();

    final activeProducts = products.where((p) => p.isActive).toList();
    final grouped = <String, List<Product>>{};
    for (final product in activeProducts) {
      grouped.putIfAbsent(product.category, () => []).add(product);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: baseTheme,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(28),
        header: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 16),
              padding: const pw.EdgeInsets.only(bottom: 10),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 1),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        businessName.isNotEmpty
                            ? businessName
                            : 'products_catalog_title'.i18n(),
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'catalog_pdf_title'.i18n(),
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                  if (businessPhone.isNotEmpty)
                    pw.Text(
                      '${'business_phone_label'.i18n()}: $businessPhone',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              margin: const pw.EdgeInsets.only(top: 12),
              padding: const pw.EdgeInsets.only(top: 8),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    footerNote.isNotEmpty ? footerNote : businessPhone,
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.Text(
                    '${context.pageNumber} / ${context.pagesCount}',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        build: (pw.Context context) {
          if (activeProducts.isEmpty) {
            return [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Center(
                  child: pw.Text(
                    'products_empty_title'.i18n(),
                    style: const pw.TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ];
          }

          final widgets = <pw.Widget>[];
          for (final entry in grouped.entries) {
            widgets.add(
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Container(
                  margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blueGrey50,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    entry.key.i18n(),
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey900,
                    ),
                  ),
                ),
              ),
            );

            widgets.add(
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Table(
                  border: pw.TableBorder.all(
                    color: PdfColors.grey300,
                    width: 0.5,
                  ),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(3),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey100,
                      ),
                      children: [
                        _tableCell('product_sell_price_clean_label'.i18n(),
                            isHeader: true),
                        _tableCell('product_unit_label'.i18n(), isHeader: true),
                        _tableCell('product_name_label'.i18n(), isHeader: true),
                      ],
                    ),
                    ...entry.value.map((p) {
                      final price = cs.formatAmount(
                        p.sellPrice,
                        currencyCode: p.currency,
                      );
                      return pw.TableRow(
                        children: [
                          _tableCell(price),
                          _tableCell(p.unit),
                          _tableCell(p.name, isBold: true),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          }

          return widgets;
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _tableCell(
    String text, {
    bool isHeader = false,
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 10,
          fontWeight: (isHeader || isBold)
              ? pw.FontWeight.bold
              : pw.FontWeight.normal,
          color: isHeader ? PdfColors.blueGrey800 : PdfColors.black,
        ),
      ),
    );
  }
}
