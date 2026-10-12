import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/individual_order.dart';
import '../../models/print_options.dart';
import '../../services/pdf_invoice_generator.dart';
import '../../services/printing_service.dart';

/// شاشة المعاينة التفاعلية للفواتير قبل الطباعة
/// تتيح تعديل حجم الورقة، عدد الفواتير المتجاورة، تضمين الصور،
/// والطباعة المباشرة لأي طابعة أو التصدير كـ PDF و Excel
class PdfPreviewScreen extends StatefulWidget {
  final List<IndividualOrder> orders;
  final PrintOptions initialOptions;
  final String title;

  const PdfPreviewScreen({
    super.key,
    required this.orders,
    required this.initialOptions,
    required this.title,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late PrintOptions _options;

  @override
  void initState() {
    super.initState();
    _options = widget.initialOptions;
  }

  void _openSettingsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'print_options_title'.i18n(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // اختيار حجم الورقة
                    Text(
                      'print_paper_size_title'.i18n(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PrintPaperSize.values.map((size) {
                        final isSelected = _options.paperSize == size;
                        return ChoiceChip(
                          label: Text(size.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) {
                              setModalState(() {
                                _options = _options.copyWith(
                                  paperSize: size,
                                  // إذا كانت طابعة حرارية نقفل على عمود واحد
                                  columnsPerRow: size.isThermalRoll ? 1 : _options.columnsPerRow,
                                );
                              });
                              setState(() {});
                            }
                          },
                          selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryBlue : Colors.black87,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // عدد الفواتير المتجاورة في الصف (الافتراضي 3 في A4)
                    if (!_options.paperSize.isThermalRoll) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'print_grid_title'.i18n(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Text(
                                'print_grid_subtitle'.i18n(),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          SegmentedButton<int>(
                            segments: [
                              ButtonSegment(value: 1, label: Text('print_grid_1'.i18n())),
                              ButtonSegment(value: 2, label: Text('print_grid_2'.i18n())),
                              ButtonSegment(value: 3, label: Text('print_grid_3'.i18n())),
                            ],
                            selected: {_options.effectiveColumnsPerRow},
                            onSelectionChanged: (val) {
                              setModalState(() {
                                _options = _options.copyWith(columnsPerRow: val.first);
                              });
                              setState(() {});
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // خيار تضمين الصور
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'print_photos_switch_title'.i18n(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      subtitle: Text(
                        'print_photos_switch_subtitle'.i18n(),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      value: _options.includeItemPhotos,
                      activeThumbColor: AppColors.primaryBlue,
                      onChanged: (val) {
                        setModalState(() {
                          _options = _options.copyWith(includeItemPhotos: val);
                        });
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text('print_apply_changes'.i18n(), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            // زر تخصيص الإعدادات
            IconButton(
              icon: const Icon(Icons.tune_outlined),
              tooltip: 'print_customize_tooltip'.i18n(),
              onPressed: _openSettingsDialog,
            ),
            // زر تصدير إكسل
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'print_excel_tooltip'.i18n(),
              onPressed: () {
                PrintingService.exportExcel(
                  context: context,
                  orders: widget.orders,
                  title: widget.title,
                );
              },
            ),
          ],
        ),
        body: PdfPreview(
          build: (format) => PdfInvoiceGenerator.generateInvoicesPdf(
            orders: widget.orders,
            options: _options,
          ),
          initialPageFormat: _options.paperSize.pageFormat,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: '${_options.documentTitle ?? 'invoices'}.pdf',
          actions: [
            PdfPreviewAction(
              icon: const Icon(Icons.tune),
              onPressed: (context, build, pageFormat) => _openSettingsDialog(),
            ),
          ],
        ),
      ),
    );
  }
}
