import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/localization/localization.dart';
import '../../../../models/individual_order.dart';
import '../models/print_options.dart';
import '../presentation/screens/pdf_preview_screen.dart';
import 'excel_invoice_generator.dart';
import 'pdf_invoice_generator.dart';

/// الخدمة المركزية الموحدة لعمليات الطباعة وتصدير الفواتير
class PrintingService {
  /// طباعة الفواتير مباشرة عبر نافذة النظام إلى أي طابعة متصلة (AirPrint / Wi-Fi / Bluetooth / حرارية)
  static Future<void> printInvoices({
    required BuildContext context,
    required List<IndividualOrder> orders,
    required PrintOptions options,
  }) async {
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('print_no_orders_selected'.i18n())),
      );
      return;
    }

    try {
      final docName = options.documentTitle ?? 'invoices_${DateTime.now().millisecondsSinceEpoch}';
      await Printing.layoutPdf(
        name: docName,
        format: options.paperSize.pageFormat,
        onLayout: (format) async {
          return PdfInvoiceGenerator.generateInvoicesPdf(
            orders: orders,
            options: options,
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('print_error_sending'.trParams({'error': e.toString()}))),
        );
      }
    }
  }

  /// مشاركة أو حفظ ملف الفواتير كـ PDF
  static Future<void> sharePdf({
    required BuildContext context,
    required List<IndividualOrder> orders,
    required PrintOptions options,
  }) async {
    if (orders.isEmpty) return;

    try {
      final bytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: orders,
        options: options,
      );
      final filename = '${options.documentTitle ?? 'invoices'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('print_error_pdf'.trParams({'error': e.toString()}))),
        );
      }
    }
  }

  /// تصدير ومشاركة الفواتير كملف إكسل Excel (.xlsx)
  static Future<void> exportExcel({
    required BuildContext context,
    required List<IndividualOrder> orders,
    String? title,
  }) async {
    if (orders.isEmpty) return;

    try {
      final bytes = ExcelInvoiceGenerator.generateInvoicesExcel(
        orders: orders,
        title: title,
      );

      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = (title ?? 'orders_invoices')
          .replaceAll(RegExp(r'[^\w\s\u0600-\u06FF-]'), '_');
      final filePath =
          '${tempDir.path}/${sanitizedTitle}_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: title ?? 'excel_report_title'.i18n(),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('print_error_excel'.trParams({'error': e.toString()}))),
        );
      }
    }
  }

  /// فتح شاشة المعاينة الحية للفاتورة قبل الطباعة
  static void previewPdf({
    required BuildContext context,
    required List<IndividualOrder> orders,
    required PrintOptions options,
    String? title,
  }) {
    if (orders.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfPreviewScreen(
          orders: orders,
          initialOptions: options,
          title: title ?? 'print_preview_title'.i18n(),
        ),
      ),
    );
  }
}
