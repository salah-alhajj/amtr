import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import '../../../core/constants.dart';
import '../../../core/localization/localization.dart';
import '../../../core/services/currency_service.dart';
import '../../../models/individual_order.dart';

/// مولي ملفات إكسل (Excel .xlsx) للفواتير والطلبات
/// يولد صفحات منسقة تشمل ملخص الفواتير والمديونيات وتفاصيل الأصناف
class ExcelInvoiceGenerator {
  /// توليد بايتات ملف الإكسل لقائمة الطلبات
  static List<int> generateInvoicesExcel({
    required List<IndividualOrder> orders,
    String? title,
  }) {
    final excel = Excel.createExcel();

    // 1. ورقة ملخص الفواتير
    final summarySheetName = 'excel_sheet_summary'.i18n();
    excel.rename('Sheet1', summarySheetName);
    final summarySheet = excel[summarySheetName];
    summarySheet.isRTL = true;

    // عنوان التقرير
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).value =
        TextCellValue(title ?? 'excel_report_title'.i18n());

    final formattedDate = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
    summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).value =
        TextCellValue('excel_export_date'.trParams({'date': formattedDate}));

    // ترويسة الجدول
    final headers = [
      '#',
      'excel_col_order_num'.i18n(),
      'excel_col_customer'.i18n(),
      'excel_col_order_date'.i18n(),
      'excel_col_items_count'.i18n(),
      'excel_col_total_sell'.i18n(),
      'excel_col_paid'.i18n(),
      'excel_col_debt'.i18n(),
      'excel_col_currency'.i18n(),
      'excel_col_payment_status'.i18n(),
      'excel_col_order_status'.i18n(),
      'excel_col_notes'.i18n(),
    ];

    for (int col = 0; col < headers.length; col++) {
      summarySheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 3))
          .value = TextCellValue(headers[col]);
    }

    // تعبئة صفوف الطلبات
    int rowIndex = 4;

    for (int i = 0; i < orders.length; i++) {
      final o = orders[i];

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value =
          IntCellValue(i + 1);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
          TextCellValue(o.orderNumber);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value =
          TextCellValue(o.customerName ?? '-');
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value =
          TextCellValue(DateFormat('yyyy/MM/dd').format(o.createdAt));
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
          IntCellValue(o.items.length);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
          DoubleCellValue(o.totalSellPrice);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
          DoubleCellValue(o.paidAmount);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value =
          DoubleCellValue(o.remainingDebt);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value =
          TextCellValue(o.currency);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: rowIndex)).value =
          TextCellValue(AppConstants.getPaymentStatusLabel(o.paymentStatus));
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: rowIndex)).value =
          TextCellValue(o.orderStatus);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 11, rowIndex: rowIndex)).value =
          TextCellValue(o.notes ?? '');

      rowIndex++;
    }

    // صف الإجماليات (مجمعة بدقة حسب كل عملة لتفادي الخلط المحاسبي)
    final currencyStats = <String, ({double sell, double paid, double debt, int items})>{};
    for (final o in orders) {
      final curr = o.currency;
      final existing = currencyStats[curr] ?? (sell: 0.0, paid: 0.0, debt: 0.0, items: 0);
      currencyStats[curr] = (
        sell: existing.sell + o.totalSellPrice,
        paid: existing.paid + o.paidAmount,
        debt: existing.debt + o.remainingDebt,
        items: existing.items + o.items.length,
      );
    }

    rowIndex++;
    if (currencyStats.length <= 1) {
      final singleCurrency = currencyStats.keys.firstOrNull ?? AppConstants.currencyYer;
      final stats = currencyStats[singleCurrency] ?? (sell: 0.0, paid: 0.0, debt: 0.0, items: 0);

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
          TextCellValue('excel_row_grand_total'.i18n());
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
          IntCellValue(stats.items);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
          DoubleCellValue(stats.sell);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
          DoubleCellValue(stats.paid);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value =
          DoubleCellValue(stats.debt);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value =
          TextCellValue(singleCurrency);
    } else {
      // تفقيط الإجماليات لكل عملة بشكل مستقل
      for (final entry in currencyStats.entries) {
        final curr = entry.key;
        final stats = entry.value;
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
            TextCellValue('${'excel_row_grand_total'.i18n()} ($curr)');
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
            IntCellValue(stats.items);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
            DoubleCellValue(stats.sell);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
            DoubleCellValue(stats.paid);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value =
            DoubleCellValue(stats.debt);
        summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value =
            TextCellValue(curr);
        rowIndex++;
      }

      // صف إجمالي موحد محول إلى العملة الأساسية (الريال اليمني)
      double equivSellYer = 0.0;
      double equivPaidYer = 0.0;
      double equivDebtYer = 0.0;
      for (final o in orders) {
        equivSellYer += CurrencyService.instance.toBaseYer(o.totalSellPrice, o.currency);
        equivPaidYer += CurrencyService.instance.toBaseYer(o.paidAmount, o.currency);
        equivDebtYer += CurrencyService.instance.toBaseYer(o.remainingDebt, o.currency);
      }

      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value =
          TextCellValue('${'excel_row_grand_total'.i18n()} (${'converter_equiv_yer'.i18n()})');
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value =
          IntCellValue(orders.fold<int>(0, (prev, o) => prev + o.items.length));
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value =
          DoubleCellValue(equivSellYer);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value =
          DoubleCellValue(equivPaidYer);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value =
          DoubleCellValue(equivDebtYer);
      summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value =
          TextCellValue(AppConstants.currencyYer);
    }

    // 2. ورقة تفاصيل كل صنف / بند
    final itemsSheetName = 'excel_sheet_items'.i18n();
    final itemsSheet = excel[itemsSheetName];
    itemsSheet.isRTL = true;

    final itemHeaders = [
      '#',
      'excel_col_order_num'.i18n(),
      'excel_col_customer'.i18n(),
      'excel_col_item_name'.i18n(),
      'excel_col_description'.i18n(),
      'common_quantity'.i18n(),
      'excel_col_cost_price'.i18n(),
      'print_unit_price'.i18n(),
      'excel_col_total_sell'.i18n(),
      'excel_col_currency'.i18n(),
    ];

    for (int col = 0; col < itemHeaders.length; col++) {
      itemsSheet
          .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0))
          .value = TextCellValue(itemHeaders[col]);
    }

    int itemRow = 1;
    int itemSeq = 1;
    for (final o in orders) {
      for (final item in o.items) {
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: itemRow)).value =
            IntCellValue(itemSeq++);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: itemRow)).value =
            TextCellValue(o.orderNumber);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: itemRow)).value =
            TextCellValue(o.customerName ?? '-');
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: itemRow)).value =
            TextCellValue(item.name);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: itemRow)).value =
            TextCellValue(item.description ?? '');
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: itemRow)).value =
            IntCellValue(item.quantity);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: itemRow)).value =
            DoubleCellValue(item.costPrice);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: itemRow)).value =
            DoubleCellValue(item.sellPrice ?? item.costPrice);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: itemRow)).value =
            DoubleCellValue(item.totalSell ?? item.totalCost);
        itemsSheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: itemRow)).value =
            TextCellValue(item.currency);

        itemRow++;
      }
    }

    final bytes = excel.save();
    return bytes ?? Uint8List(0);
  }
}
