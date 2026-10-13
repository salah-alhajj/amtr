import 'dart:io';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/constants.dart';
import '../../../core/localization/localization.dart';
import '../../../models/individual_order.dart';
import '../../../models/order_item.dart';
import '../../../core/utils/yemen_phone_helper.dart';
import '../models/print_options.dart';

/// مولي الفواتير الإلكترونية ومستندات PDF الاحترافية
/// يدعم اللغة العربية الكاملة (RTL)، خطوط IBM Plex Sans Arabic الرسمية،
/// أحجام الورق المتعددة (A4, A5, Thermal)، والتوزيع المرن (3 فواتير عمودية متجاورة افتراضياً في A4)
class PdfInvoiceGenerator {
  /// توليد مستند PDF كامل لقائمة الطلبات المحددة
  static Future<Uint8List> generateInvoicesPdf({
    required List<IndividualOrder> orders,
    required PrintOptions options,
  }) async {
    final pdf = pw.Document();

    // تحميل الخطوط العربية المضمنة في التطبيق
    final regularFontData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final boldFontData = await rootBundle.load('assets/fonts/IBMPlexSansArabic-Bold.ttf');
    final ttfRegular = pw.Font.ttf(regularFontData);
    final ttfBold = pw.Font.ttf(boldFontData);

    final baseTheme = pw.ThemeData.withFont(
      base: ttfRegular,
      bold: ttfBold,
    );

    final pageFormat = options.paperSize.pageFormat;
    final int cols = options.effectiveColumnsPerRow;

    // إذا كانت طابعة حرارية (Roll)، نطبع كل فاتورة كإيصال رول متتابع
    if (options.paperSize.isThermalRoll) {
      for (final order in orders) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            theme: baseTheme,
            textDirection: pw.TextDirection.rtl,
            margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            build: (pw.Context context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: _buildSingleInvoiceCard(
                  order: order,
                  options: options,
                  cardWidth: pageFormat.availableWidth,
                  isThermal: true,
                  fontSizeScale: 0.9,
                ),
              );
            },
          ),
        );
      }
      return pdf.save();
    }

    // لورق A4 أو A5 أو Letter:
    // إذا كان خيار الأعمدة هو 1 (فاتورة عريضة لكل صفحة):
    if (cols == 1) {
      for (final order in orders) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: pageFormat,
            theme: baseTheme,
            textDirection: pw.TextDirection.rtl,
            margin: const pw.EdgeInsets.all(24),
            header: (pw.Context context) => _buildDocumentHeader(options),
            footer: (pw.Context context) => _buildDocumentFooter(context, options),
            build: (pw.Context context) => [
              pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: _buildWideInvoiceLayout(order, options),
              ),
            ],
          ),
        );
      }
      return pdf.save();
    }

    // إذا كان خيار الأعمدة هو 2 أو 3 (الافتراضي في A4 هو 3 فواتير عمودية متجاورة):
    // نقسم الطلبات في مجموعات حسب عدد الأعمدة لكل صف، ونبني صفحات تحتوي على الفواتير المتجاورة
    // بحيث لا تنضغط أبداً مع الحفاظ على مرونة العناصر وتناسب العرض والارتفاع.
    final double marginSize = 16.0;
    final double availableWidth = pageFormat.width - (marginSize * 2);
    final double columnSpacing = 10.0;
    final double cardWidth = (availableWidth - (columnSpacing * (cols - 1))) / cols;

    // نقسم الطلبات إلى شرائح (صفحات)
    // في A4، بارتفاع 842pt، فاتورة بارتفاع ~360pt تستوعب صفين (أي حتى 6 فواتير بالصفحة)
    // إذا كانت الطلبات تحتوي عناصر كثيرة (> 4 بنود)، نضع صفاً واحداً بالصفحة (3 فواتير بالصفحة)
    int invoicesPerPage = cols;
    final bool anyOrderHasManyItems = orders.any((o) => o.items.length > 4 || options.includeItemPhotos);
    if (!anyOrderHasManyItems && orders.every((o) => o.items.length <= 3)) {
      invoicesPerPage = cols * 2; // صفان
    }

    for (int i = 0; i < orders.length; i += invoicesPerPage) {
      final end = (i + invoicesPerPage < orders.length) ? i + invoicesPerPage : orders.length;
      final pageOrders = orders.sublist(i, end);

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: baseTheme,
          textDirection: pw.TextDirection.rtl,
          margin: pw.EdgeInsets.all(marginSize),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _buildPageHeader(options, pageIndex: (i ~/ invoicesPerPage) + 1, totalPages: (orders.length / invoicesPerPage).ceil()),
                  pw.SizedBox(height: 8),
                  pw.Expanded(
                    child: _buildInvoiceGrid(
                      orders: pageOrders,
                      cols: cols,
                      cardWidth: cardWidth,
                      columnSpacing: columnSpacing,
                      options: options,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  _buildPageFooter(context, options),
                ],
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// رأس المستند
  static pw.Widget _buildDocumentHeader(PrintOptions options) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            options.documentTitle ?? 'print_invoice_slip_title'.i18n(),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800),
          ),
          if (options.customerName != null)
            pw.Text(
              '${'print_customer_label'.trParams({'name': options.customerName!})}${options.customerPhone != null && options.customerPhone!.isNotEmpty ? ' (${YemenPhoneHelper.formatForDisplay(options.customerPhone)})' : ''}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          pw.Text(
            DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now()),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// رأس كل صفحة في التوزيع الشبكي
  static pw.Widget _buildPageHeader(PrintOptions options, {required int pageIndex, required int totalPages}) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 8,
                height: 8,
                decoration: const pw.BoxDecoration(color: PdfColors.indigo700, shape: pw.BoxShape.circle),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                options.documentTitle ?? 'print_default_doc_title'.i18n(),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
              ),
            ],
          ),
          pw.Text(
            '${'print_page_counter'.trParams({'current': pageIndex.toString(), 'total': totalPages.toString()})}  •  ${DateFormat('yyyy/MM/dd').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  /// تذييل الصفحة
  static pw.Widget _buildDocumentFooter(pw.Context context, PrintOptions options) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey200, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            options.footerNotes ?? 'print_footer_thanks'.i18n(),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
          pw.Text(
            'print_page_of'.trParams({'current': context.pageNumber.toString(), 'total': context.pagesCount.toString()}),
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPageFooter(pw.Context context, PrintOptions options) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            options.footerNotes ?? 'print_footer_electronic'.i18n(),
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
          ),
          pw.Text(
            'print_cut_here'.i18n(),
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  /// بناء شبكة الفواتير المتجاورة في الصفحة (افتراضياً 3 أعمدة في A4)
  static pw.Widget _buildInvoiceGrid({
    required List<IndividualOrder> orders,
    required int cols,
    required double cardWidth,
    required double columnSpacing,
    required PrintOptions options,
  }) {
    final List<pw.Widget> rows = [];
    final double fontSizeScale = (cols >= 3) ? 0.82 : (cols == 2 ? 0.92 : 1.0);

    for (int r = 0; r < orders.length; r += cols) {
      final rowOrders = orders.sublist(
        r,
        (r + cols < orders.length) ? r + cols : orders.length,
      );

      final rowChildren = <pw.Widget>[];

      for (int c = 0; c < rowOrders.length; c++) {
        final order = rowOrders[c];
        rowChildren.add(
          pw.Container(
            width: cardWidth,
            child: _buildSingleInvoiceCard(
              order: order,
              options: options,
              cardWidth: cardWidth,
              isThermal: false,
              fontSizeScale: fontSizeScale,
            ),
          ),
        );

        // فاصل قص منقط بين الفواتير المتجاورة
        if (c < rowOrders.length - 1 && options.showCutLines) {
          rowChildren.add(
            pw.Container(
              width: columnSpacing,
              alignment: pw.Alignment.center,
              child: _buildVerticalCutLine(),
            ),
          );
        } else if (c < rowOrders.length - 1) {
          rowChildren.add(pw.SizedBox(width: columnSpacing));
        }
      }

      // إكمال الأعمدة الفارغة إن وجدت للحفاظ على ثبات العرض
      while (rowChildren.length < (cols * 2 - 1)) {
        if (options.showCutLines) {
          rowChildren.add(pw.SizedBox(width: columnSpacing));
        }
        rowChildren.add(pw.Container(width: cardWidth));
      }

      rows.add(
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: rowChildren,
          ),
        ),
      );

      // إذا كان هناك صف تالٍ، نضيف فاصل أفقي
      if (r + cols < orders.length && options.showCutLines) {
        rows.add(_buildHorizontalCutLine());
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  /// خط قص عمودي منقط
  static pw.Widget _buildVerticalCutLine() {
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(':', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400)),
        pw.SizedBox(height: 2),
        pw.Expanded(
          child: pw.Container(
            width: 1,
            child: pw.ListView.builder(
              itemCount: 25,
              itemBuilder: (context, i) => pw.Container(
                height: 4,
                margin: const pw.EdgeInsets.symmetric(vertical: 2),
                color: PdfColors.grey300,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// خط قص أفقي منقط
  static pw.Widget _buildHorizontalCutLine() {
    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(vertical: 6),
      child: pw.Row(
        children: [
          pw.Text('- - - ', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
          pw.Expanded(
            child: pw.Container(
              height: 1,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8, style: pw.BorderStyle.dashed),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء كرت الفاتورة العمودية المفردة (مرنة بالكامل وغير منضغطة)
  static pw.Widget _buildSingleInvoiceCard({
    required IndividualOrder order,
    required PrintOptions options,
    required double cardWidth,
    required bool isThermal,
    required double fontSizeScale,
  }) {
    final currencySymbol = _getCurrencySymbol(order.currency);
    final isPaid = order.isFullyPaid;
    final paymentStatusLabel = _getPaymentStatusText(order.paymentStatus);

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // رأس الفاتورة
          pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'print_order_tag'.trParams({'number': order.orderNumber}),
                      style: pw.TextStyle(
                        fontSize: 10 * fontSizeScale,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: pw.BoxDecoration(
                        color: isPaid ? PdfColors.green50 : PdfColors.amber50,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        border: pw.Border.all(
                          color: isPaid ? PdfColors.green700 : PdfColors.amber800,
                          width: 0.6,
                        ),
                      ),
                      child: pw.Text(
                        paymentStatusLabel,
                        style: pw.TextStyle(
                          fontSize: 7.5 * fontSizeScale,
                          fontWeight: pw.FontWeight.bold,
                          color: isPaid ? PdfColors.green900 : PdfColors.amber900,
                        ),
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 3),
                if (order.customerName != null && order.customerName!.isNotEmpty)
                  pw.Text(
                    'print_customer_label'.trParams({'name': order.customerName!}),
                    style: pw.TextStyle(
                      fontSize: 8.5 * fontSizeScale,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                    maxLines: 1,
                  ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      DateFormat('yyyy/MM/dd').format(order.createdAt),
                      style: pw.TextStyle(fontSize: 7.5 * fontSizeScale, color: PdfColors.grey600),
                    ),
                    pw.Text(
                      'print_items_count'.trParams({'count': order.items.length.toString()}),
                      style: pw.TextStyle(fontSize: 7.5 * fontSizeScale, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 6),

          // جدول/قائمة البنود المرنة
          if (isThermal)
            _buildItemsList(
              items: order.items,
              currencySymbol: currencySymbol,
              includePhotos: options.includeItemPhotos,
              fontSizeScale: fontSizeScale,
              cardWidth: cardWidth,
            )
          else
            pw.Expanded(
              child: _buildItemsList(
                items: order.items,
                currencySymbol: currencySymbol,
                includePhotos: options.includeItemPhotos,
                fontSizeScale: fontSizeScale,
                cardWidth: cardWidth,
              ),
            ),

          pw.SizedBox(height: 6),

          // ملخص الحساب والتذييل المالي
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
            ),
            child: pw.Column(
              children: [
                _buildSummaryRow(
                  label: '${'print_total_price'.i18n()}:',
                  value: '${order.totalSellPrice.toStringAsFixed(1)} $currencySymbol',
                  fontSize: 8.5 * fontSizeScale,
                  isBold: true,
                ),
                if (order.paidAmount > 0)
                  _buildSummaryRow(
                    label: 'print_paid_summary'.i18n(),
                    value: '${order.paidAmount.toStringAsFixed(1)} $currencySymbol',
                    fontSize: 7.5 * fontSizeScale,
                    color: PdfColors.green800,
                  ),
                if (order.remainingDebt > 0)
                  _buildSummaryRow(
                    label: 'print_debt_summary'.i18n(),
                    value: '${order.remainingDebt.toStringAsFixed(1)} $currencySymbol',
                    fontSize: 8 * fontSizeScale,
                    color: PdfColors.red800,
                    isBold: true,
                  ),
              ],
            ),
          ),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text(
              'print_notes_label'.trParams({'notes': order.notes!}),
              style: pw.TextStyle(fontSize: 7 * fontSizeScale, color: PdfColors.grey600),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }

  /// قائمة البنود المرنة داخل الفاتورة العمودية
  static pw.Widget _buildItemsList({
    required List<OrderItem> items,
    required String currencySymbol,
    required bool includePhotos,
    required double fontSizeScale,
    required double cardWidth,
  }) {
    return pw.Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        final price = item.sellPrice ?? item.costPrice;
        final total = (item.totalSell ?? item.totalCost);

        pw.Widget? photoWidget;
        if (includePhotos && item.photos.isNotEmpty) {
          final photoPath = item.photos.first;
          final file = File(photoPath);
          if (file.existsSync()) {
            try {
              final bytes = file.readAsBytesSync();
              final image = pw.MemoryImage(bytes);
              photoWidget = pw.Container(
                width: 26,
                height: 26,
                margin: const pw.EdgeInsets.only(left: 4),
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                child: pw.ClipRRect(
                  horizontalRadius: 3,
                  verticalRadius: 3,
                  child: pw.Image(image, fit: pw.BoxFit.cover),
                ),
              );
            } catch (_) {}
          }
        }

        return pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              ?photoWidget,
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      item.name,
                      style: pw.TextStyle(
                        fontSize: 8 * fontSizeScale,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                      maxLines: 2,
                    ),
                    pw.Text(
                      '${item.quantity} × ${price.toStringAsFixed(1)} $currencySymbol',
                      style: pw.TextStyle(fontSize: 7 * fontSizeScale, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ),
              pw.Text(
                '${total.toStringAsFixed(1)} $currencySymbol',
                style: pw.TextStyle(
                  fontSize: 8 * fontSizeScale,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// تخطيط الفاتورة العريضة (في حال اختيار 1 عمود)
  static pw.Widget _buildWideInvoiceLayout(IndividualOrder order, PrintOptions options) {
    final currencySymbol = _getCurrencySymbol(order.currency);
    final isPaid = order.isFullyPaid;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          // رأس الفاتورة
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'print_invoice_for_order'.trParams({'number': order.orderNumber}),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'print_creation_date'.trParams({'date': DateFormat('yyyy/MM/dd HH:mm').format(order.createdAt)}),
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  if (order.customerName != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'print_customer_label'.trParams({'name': order.customerName!}),
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                    ),
                  ],
                ],
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: isPaid ? PdfColors.green50 : PdfColors.amber50,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: isPaid ? PdfColors.green700 : PdfColors.amber700, width: 1),
                ),
                child: pw.Text(
                  _getPaymentStatusText(order.paymentStatus),
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: isPaid ? PdfColors.green900 : PdfColors.amber900),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // جدول الأصناف
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
            cellAlignment: pw.Alignment.centerRight,
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: <String>[
              '#',
              'print_item_col'.i18n(),
              'print_qty_col'.i18n(),
              'print_unit_price'.i18n(),
              'print_total_price'.i18n(),
            ],
            data: List<List<dynamic>>.generate(
              order.items.length,
              (index) {
                final item = order.items[index];
                final price = item.sellPrice ?? item.costPrice;
                final total = item.totalSell ?? item.totalCost;
                return [
                  '${index + 1}',
                  item.name,
                  '${item.quantity}',
                  '${price.toStringAsFixed(1)} $currencySymbol',
                  '${total.toStringAsFixed(1)} $currencySymbol',
                ];
              },
            ),
          ),

          pw.SizedBox(height: 16),

          // الملخص المالي
          pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  _buildSummaryRow(
                    label: 'print_invoice_total'.i18n(),
                    value: '${order.totalSellPrice.toStringAsFixed(1)} $currencySymbol',
                    fontSize: 11,
                    isBold: true,
                  ),
                  pw.SizedBox(height: 4),
                  _buildSummaryRow(
                    label: 'print_paid_amount'.i18n(),
                    value: '${order.paidAmount.toStringAsFixed(1)} $currencySymbol',
                    fontSize: 10,
                    color: PdfColors.green800,
                  ),
                  pw.SizedBox(height: 4),
                  _buildSummaryRow(
                    label: 'print_remaining_debt'.i18n(),
                    value: '${order.remainingDebt.toStringAsFixed(1)} $currencySymbol',
                    fontSize: 11,
                    color: PdfColors.red800,
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSummaryRow({
    required String label,
    required String value,
    required double fontSize,
    PdfColor? color,
    bool isBold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.grey800,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  /// استرجاع رمز العملة المعتمد للطباعة
  static String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode.toUpperCase()) {
      case AppConstants.currencySar:
        // استخدام النص العربي المعتمد (ر.س) للطباعة لضمان التوافق التام مع خطوط PDF المضمنة
        return 'ر.س';
      case AppConstants.currencyUsd:
        return AppConstants.usdSymbol;
      case AppConstants.currencyYer:
      default:
        return AppConstants.yerSymbol;
    }
  }

  static String _getPaymentStatusText(String status) {
    switch (status) {
      case AppConstants.paymentPrepaid:
        return 'print_status_paid'.i18n();
      case AppConstants.paymentDebt:
        return 'print_status_debt'.i18n();
      case AppConstants.paymentCod:
        return 'print_status_cod'.i18n();
      case AppConstants.paymentPartial:
        return 'print_status_partial'.i18n();
      default:
        return status;
    }
  }
}
