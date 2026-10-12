import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
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
              child: AppModalSheet(
                title: 'print_options_title'.i18n(),
                trailing: AppIconButton(
                  icon: Icons.close_rounded,
                  size: 32,
                  iconSize: 18,
                  onPressed: () => Navigator.pop(context),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // اختيار حجم الورقة
                    Text(
                      'print_paper_size_title'.i18n(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PrintPaperSize.values.map((size) {
                        final isSelected = _options.paperSize == size;
                        return AppFilterChip(
                          label: size.displayName,
                          isSelected: isSelected,
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
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // عدد الفواتير المتجاورة في الصف (الافتراضي 3 في A4)
                    if (!_options.paperSize.isThermalRoll) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'print_grid_title'.i18n(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'print_grid_subtitle'.i18n(),
                            style: TextStyle(
                              fontSize: 11,
                              color: context.textSecondary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
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
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

                    // خيار تضمين الصور
                    AppSwitchTile(
                      title: 'print_photos_switch_title'.i18n(),
                      subtitle: 'print_photos_switch_subtitle'.i18n(),
                      value: _options.includeItemPhotos,
                      onChanged: (val) {
                        setModalState(() {
                          _options = _options.copyWith(includeItemPhotos: val);
                        });
                        setState(() {});
                      },
                    ),

                    const SizedBox(height: 16),
                    AppPrimaryButton(
                      label: 'print_apply_changes'.i18n(),
                      height: 46,
                      onPressed: () => Navigator.pop(context),
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
