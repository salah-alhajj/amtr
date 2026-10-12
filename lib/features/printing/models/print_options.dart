import 'package:pdf/pdf.dart';
import '../../../core/localization/localization.dart';

/// أحجام الورق المدعومة للطباعة
enum PrintPaperSize {
  a4,
  a5,
  a3,
  letter,
  thermal80,
  thermal58,
}

extension PrintPaperSizeExtension on PrintPaperSize {
  String get displayName {
    switch (this) {
      case PrintPaperSize.a4:
        return 'print_paper_a4'.i18n();
      case PrintPaperSize.a5:
        return 'print_paper_a5'.i18n();
      case PrintPaperSize.a3:
        return 'print_paper_a3'.i18n();
      case PrintPaperSize.letter:
        return 'print_paper_letter'.i18n();
      case PrintPaperSize.thermal80:
        return 'print_paper_thermal80'.i18n();
      case PrintPaperSize.thermal58:
        return 'print_paper_thermal58'.i18n();
    }
  }

  PdfPageFormat get pageFormat {
    switch (this) {
      case PrintPaperSize.a4:
        return PdfPageFormat.a4;
      case PrintPaperSize.a5:
        return PdfPageFormat.a5;
      case PrintPaperSize.a3:
        return PdfPageFormat.a3;
      case PrintPaperSize.letter:
        return PdfPageFormat.letter;
      case PrintPaperSize.thermal80:
        return PdfPageFormat.roll80;
      case PrintPaperSize.thermal58:
        return PdfPageFormat.roll57;
    }
  }

  /// هل الحجم طابعة حرارية رول؟
  bool get isThermalRoll =>
      this == PrintPaperSize.thermal80 || this == PrintPaperSize.thermal58;
}

/// خيارات وإعدادات توليد الفواتير والطباعة
class PrintOptions {
  /// حجم الورق (الافتراضي A4)
  final PrintPaperSize paperSize;

  /// عدد الفواتير المتجاورة في الصف الواحد (الافتراضي 3 في A4)
  final int columnsPerRow;

  /// تضمين الصور لكل بند ضمن الفاتورة (الافتراضي غير مفعل / false)
  final bool includeItemPhotos;

  /// عنوان اختياري للمستند (مثال: فواتير شحنة مجمعة، كشف حساب عميل)
  final String? documentTitle;

  /// اسم العميل في حال تخصيص الفاتورة لعميل معين
  final String? customerName;

  /// هاتف العميل
  final String? customerPhone;

  /// ملاحظات تذييل الفاتورة
  final String? footerNotes;

  /// إظهار خطوط القص والتنقيط بين الفواتير المتجاورة
  final bool showCutLines;

  const PrintOptions({
    this.paperSize = PrintPaperSize.a4,
    this.columnsPerRow = 3,
    this.includeItemPhotos = false,
    this.documentTitle,
    this.customerName,
    this.customerPhone,
    this.footerNotes,
    this.showCutLines = true,
  });

  /// حساب عدد الأعمدة الفعلي وفقاً لحجم الورقة
  /// في الطابعات الحرارية الرول يكون دائماً 1 عمود
  int get effectiveColumnsPerRow {
    if (paperSize.isThermalRoll) {
      return 1;
    }
    if (paperSize == PrintPaperSize.a5 && columnsPerRow > 2) {
      return 2;
    }
    return columnsPerRow.clamp(1, 4);
  }

  PrintOptions copyWith({
    PrintPaperSize? paperSize,
    int? columnsPerRow,
    bool? includeItemPhotos,
    String? documentTitle,
    String? customerName,
    String? customerPhone,
    String? footerNotes,
    bool? showCutLines,
  }) {
    return PrintOptions(
      paperSize: paperSize ?? this.paperSize,
      columnsPerRow: columnsPerRow ?? this.columnsPerRow,
      includeItemPhotos: includeItemPhotos ?? this.includeItemPhotos,
      documentTitle: documentTitle ?? this.documentTitle,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      footerNotes: footerNotes ?? this.footerNotes,
      showCutLines: showCutLines ?? this.showCutLines,
    );
  }
}
