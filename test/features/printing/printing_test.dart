import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/constants.dart';
import 'package:amtr/models/individual_order.dart';
import 'package:amtr/models/order_item.dart';
import 'package:amtr/features/printing/models/print_options.dart';
import 'package:amtr/features/printing/services/excel_invoice_generator.dart';
import 'package:amtr/features/printing/services/pdf_invoice_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testOrders = [
    IndividualOrder(
      id: 'ord-1',
      orderNumber: 'ORD-101',
      customerId: 'cust-1',
      customerName: 'أحمد صالح',
      currency: AppConstants.currencyYer,
      paymentStatus: AppConstants.paymentPartial,
      orderStatus: AppConstants.orderStatusPending,
      paidAmount: 5000.0,
      createdAt: DateTime(2026, 10, 10, 14, 30),
      items: [
        OrderItem(
          id: 'item-1',
          orderId: 'ord-1',
          name: 'شاحن سريع أنكر 65W',
          quantity: 2,
          costPrice: 4000.0,
          sellPrice: 6000.0,
          currency: AppConstants.currencyYer,
        ),
        OrderItem(
          id: 'item-2',
          orderId: 'ord-1',
          name: 'سماعة بلوتوث لاسلكية',
          quantity: 1,
          costPrice: 8000.0,
          sellPrice: 11000.0,
          currency: AppConstants.currencyYer,
        ),
      ],
    ),
    IndividualOrder(
      id: 'ord-2',
      orderNumber: 'ORD-102',
      customerId: 'cust-2',
      customerName: 'سالم العمودي',
      currency: AppConstants.currencySar,
      paymentStatus: AppConstants.paymentPrepaid,
      orderStatus: AppConstants.orderStatusDelivered,
      paidAmount: 250.0,
      createdAt: DateTime(2026, 10, 11, 10, 15),
      items: [
        OrderItem(
          id: 'item-3',
          orderId: 'ord-2',
          name: 'ساعة ذكية مقاومة للماء',
          quantity: 1,
          costPrice: 180.0,
          sellPrice: 250.0,
          currency: AppConstants.currencySar,
        ),
      ],
    ),
  ];

  group('PrintOptions Model Tests', () {
    test('Default print options match requirements', () {
      const options = PrintOptions();
      // الافتراضي في A4 هو 3 فواتير متجاورة في الصف
      expect(options.paperSize, equals(PrintPaperSize.a4));
      expect(options.columnsPerRow, equals(3));
      expect(options.effectiveColumnsPerRow, equals(3));
      // تضمين الصور افتراضياً غير مفعل
      expect(options.includeItemPhotos, isFalse);
    });

    test('Thermal roll overrides columns to 1 regardless of user setting', () {
      const options80 = PrintOptions(
        paperSize: PrintPaperSize.thermal80,
        columnsPerRow: 3,
      );
      expect(options80.effectiveColumnsPerRow, equals(1));

      const options58 = PrintOptions(
        paperSize: PrintPaperSize.thermal58,
        columnsPerRow: 4,
      );
      expect(options58.effectiveColumnsPerRow, equals(1));
    });

    test('A5 caps columns to maximum 2', () {
      const optionsA5 = PrintOptions(
        paperSize: PrintPaperSize.a5,
        columnsPerRow: 3,
      );
      expect(optionsA5.effectiveColumnsPerRow, equals(2));
    });
  });

  group('ExcelInvoiceGenerator Tests', () {
    test('Generates non-empty Excel bytes with summary and items', () {
      final bytes = ExcelInvoiceGenerator.generateInvoicesExcel(
        orders: testOrders,
        title: 'كشف مبيعات تجريبي',
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });

  group('PdfInvoiceGenerator Tests', () {
    test('Generates valid PDF in standard A4 3-columns layout', () async {
      const options = PrintOptions(
        paperSize: PrintPaperSize.a4,
        columnsPerRow: 3,
        includeItemPhotos: false,
      );

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: testOrders,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      // PDF documents start with %PDF-
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Generates valid PDF in single wide column mode', () async {
      const options = PrintOptions(
        paperSize: PrintPaperSize.a4,
        columnsPerRow: 1,
      );

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: testOrders,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('Generates valid PDF in thermal roll mode', () async {
      const options = PrintOptions(
        paperSize: PrintPaperSize.thermal80,
      );

      final pdfBytes = await PdfInvoiceGenerator.generateInvoicesPdf(
        orders: testOrders,
        options: options,
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}
