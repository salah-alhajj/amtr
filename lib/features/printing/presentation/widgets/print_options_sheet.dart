import 'package:flutter/material.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/individual_order.dart';
import '../../models/print_options.dart';
import '../../services/printing_service.dart';

/// نطاق الطلبات المختارة للطباعة
enum PrintOrdersScope {
  all,
  pending,
  delivered,
  custom,
}

/// ورقة خيارات وتخصيص الطباعة والتصدير الشاملة
/// تتيح تحديد:
/// 1. الطلبات المستهدفة: كامل الطلبات / السابقة / المعلقة / تحديد مخصص
/// 2. حجم الورقة: الافتراضي A4 مع إمكانية التغيير (A5, A3, Letter, Thermal)
/// 3. توزيع الفاتورة: الافتراضي في A4 هو 3 فواتير عمودية متجاورة بالصف، مع إمكانية التحكم
/// 4. تضمين الصور لكل بند: افتراضياً غير مفعل
/// 5. خيارات الإخراج: طباعة مباشرة للطابعة / معاينة تفاعلية / تصدير PDF / تصدير Excel
class PrintOptionsSheet extends StatefulWidget {
  final List<IndividualOrder> allOrders;
  final Set<String>? initialSelectedOrderIds;
  final String? customerName;
  final String? customerPhone;
  final String? shipmentTitle;
  final String? defaultDocumentTitle;

  const PrintOptionsSheet({
    super.key,
    required this.allOrders,
    this.initialSelectedOrderIds,
    this.customerName,
    this.customerPhone,
    this.shipmentTitle,
    this.defaultDocumentTitle,
  });

  /// دالة مساعدة سريعة لفتح الشيت من أي صفحة
  static Future<void> show(
    BuildContext context, {
    required List<IndividualOrder> allOrders,
    Set<String>? initialSelectedOrderIds,
    String? customerName,
    String? customerPhone,
    String? shipmentTitle,
    String? title,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrintOptionsSheet(
        allOrders: allOrders,
        initialSelectedOrderIds: initialSelectedOrderIds,
        customerName: customerName,
        customerPhone: customerPhone,
        shipmentTitle: shipmentTitle,
        defaultDocumentTitle: title,
      ),
    );
  }

  @override
  State<PrintOptionsSheet> createState() => _PrintOptionsSheetState();
}

class _PrintOptionsSheetState extends State<PrintOptionsSheet> {
  late PrintOrdersScope _scope;
  late Set<String> _selectedIds;

  // إعدادات الطباعة
  PrintPaperSize _paperSize = PrintPaperSize.a4;
  int _columnsPerRow = 3; // الافتراضي في A4 هو 3 فواتير متجاورة في الصف
  bool _includeItemPhotos = false; // الافتراضي غير مفعل

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedOrderIds != null &&
        widget.initialSelectedOrderIds!.isNotEmpty) {
      _scope = PrintOrdersScope.custom;
      _selectedIds = Set.from(widget.initialSelectedOrderIds!);
    } else {
      _scope = PrintOrdersScope.all;
      _selectedIds = widget.allOrders.map((o) => o.id).toSet();
    }
  }

  /// تصفية الطلبات وفق النطاق المحدد
  List<IndividualOrder> get _filteredOrders {
    switch (_scope) {
      case PrintOrdersScope.all:
        return widget.allOrders;
      case PrintOrdersScope.pending:
        return widget.allOrders
            .where((o) => o.orderStatus != AppConstants.orderStatusDelivered)
            .toList();
      case PrintOrdersScope.delivered:
        return widget.allOrders
            .where((o) => o.orderStatus == AppConstants.orderStatusDelivered)
            .toList();
      case PrintOrdersScope.custom:
        return widget.allOrders
            .where((o) => _selectedIds.contains(o.id))
            .toList();
    }
  }

  PrintOptions _buildOptions() {
    return PrintOptions(
      paperSize: _paperSize,
      columnsPerRow: _columnsPerRow,
      includeItemPhotos: _includeItemPhotos,
      documentTitle: widget.defaultDocumentTitle ?? 'print_default_doc_title'.i18n(),
      customerName: widget.customerName,
      customerPhone: widget.customerPhone,
      showCutLines: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = _filteredOrders;
    final effectiveTitle = widget.defaultDocumentTitle ?? 'print_default_doc_title'.i18n();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AppModalSheet(
        title: effectiveTitle,
        subtitle: 'print_options_available_and_selected'.trParams({
          'total': widget.allOrders.length.toString(),
          'selected': activeOrders.length.toString(),
        }),
        trailing: AppIconButton(
          icon: Icons.close_rounded,
          size: 32,
          iconSize: 18,
          onPressed: () => Navigator.pop(context),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // محتوى الإعدادات القابل للتمرير
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                    // 1. نطاق الطلبات
                    _buildSectionTitle('print_scope_title'.i18n()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildScopeChip(
                          scope: PrintOrdersScope.all,
                          label: 'print_scope_all'.trParams({'count': widget.allOrders.length.toString()}),
                          icon: Icons.all_inclusive,
                        ),
                        _buildScopeChip(
                          scope: PrintOrdersScope.pending,
                          label: 'print_scope_pending'.trParams({
                            'count': widget.allOrders
                                .where((o) => o.orderStatus != AppConstants.orderStatusDelivered)
                                .length
                                .toString(),
                          }),
                          icon: Icons.hourglass_top,
                        ),
                        _buildScopeChip(
                          scope: PrintOrdersScope.delivered,
                          label: 'print_scope_delivered'.trParams({
                            'count': widget.allOrders
                                .where((o) => o.orderStatus == AppConstants.orderStatusDelivered)
                                .length
                                .toString(),
                          }),
                          icon: Icons.check_circle_outline,
                        ),
                        _buildScopeChip(
                          scope: PrintOrdersScope.custom,
                          label: 'print_scope_custom'.trParams({'count': _selectedIds.length.toString()}),
                          icon: Icons.checklist,
                        ),
                      ],
                    ),

                    // قائمة التحديد المخصص إذا كان النطاق مخصص
                    if (_scope == PrintOrdersScope.custom) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          itemCount: widget.allOrders.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final o = widget.allOrders[i];
                            final isChecked = _selectedIds.contains(o.id);
                            return CheckboxListTile(
                              dense: true,
                              value: isChecked,
                              title: Text(
                                '${'print_order_tag'.trParams({'number': o.orderNumber})} - ${o.customerName ?? 'print_no_customer'.i18n()}',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                '${o.totalSellPrice.toStringAsFixed(1)} ${o.currency} • ${'print_items_count'.trParams({'count': o.items.length.toString()})}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedIds.add(o.id);
                                  } else {
                                    _selectedIds.remove(o.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // 2. حجم الورقة (الافتراضي A4)
                    _buildSectionTitle('print_paper_size_title'.i18n()),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: PrintPaperSize.values.map((size) {
                        final isSelected = _paperSize == size;
                        return AppFilterChip(
                          label: size.displayName,
                          isSelected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _paperSize = size;
                                if (size.isThermalRoll) {
                                  _columnsPerRow = 1;
                                }
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // 3. عدد الفواتير المتجاورة بالصف (الافتراضي في A4 هو 3 فواتير عمودية متجاورة)
                    if (!_paperSize.isThermalRoll) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle('print_grid_title'.i18n()),
                          const SizedBox(height: 2),
                          Text(
                            'print_grid_subtitle'.i18n(),
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<int>(
                              segments: [
                                const ButtonSegment(value: 1, label: Text('1')),
                                const ButtonSegment(value: 2, label: Text('2')),
                                ButtonSegment(value: 3, label: Text('print_grid_3'.i18n())),
                              ],
                              selected: {_columnsPerRow.clamp(1, 3)},
                              onSelectionChanged: (set) {
                                setState(() {
                                  _columnsPerRow = set.first;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 4. تضمين الصور لكل بند (افتراضياً غير مفعل)
                    AppSwitchTile(
                      title: 'print_photos_switch_title'.i18n(),
                      subtitle: 'print_photos_switch_subtitle'.i18n(),
                      value: _includeItemPhotos,
                      onChanged: (val) {
                        setState(() {
                          _includeItemPhotos = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // أزرار العمليات (طباعة مباشرة، معاينة، تصدير PDF، تصدير Excel)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // زر الطباعة المباشرة للطابعة
                AppPrimaryButton(
                  icon: Icons.print,
                  label: 'print_btn_direct'.trParams({'count': activeOrders.length.toString()}),
                  height: 48,
                  onPressed: activeOrders.isEmpty
                      ? null
                      : () {
                          Navigator.pop(context);
                          PrintingService.printInvoices(
                            context: context,
                            orders: activeOrders,
                            options: _buildOptions(),
                          );
                        },
                ),
                const SizedBox(height: 8),

                // صف الأزرار الإضافية: معاينة، تصدير PDF، تصدير Excel
                Row(
                  children: [
                    // زر المعاينة
                    Expanded(
                      child: AppOutlinedButton(
                        icon: Icons.remove_red_eye_outlined,
                        label: 'print_btn_preview'.i18n(),
                        height: 44,
                        onPressed: activeOrders.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                PrintingService.previewPdf(
                                  context: context,
                                  orders: activeOrders,
                                  options: _buildOptions(),
                                  title: effectiveTitle,
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // زر تصدير PDF
                    Expanded(
                      child: AppOutlinedButton(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'print_btn_pdf'.i18n(),
                        height: 44,
                        onPressed: activeOrders.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                PrintingService.sharePdf(
                                  context: context,
                                  orders: activeOrders,
                                  options: _buildOptions(),
                                );
                              },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // زر تصدير Excel
                    Expanded(
                      child: AppOutlinedButton(
                        icon: Icons.table_chart_outlined,
                        label: 'print_btn_excel'.i18n(),
                        height: 44,
                        onPressed: activeOrders.isEmpty
                            ? null
                            : () {
                                Navigator.pop(context);
                                PrintingService.exportExcel(
                                  context: context,
                                  orders: activeOrders,
                                  title: effectiveTitle,
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildScopeChip({
    required PrintOrdersScope scope,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _scope == scope;
    return AppFilterChip(
      icon: icon,
      label: label,
      isSelected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _scope = scope;
            if (scope == PrintOrdersScope.custom && _selectedIds.isEmpty) {
              _selectedIds = widget.allOrders.map((o) => o.id).toSet();
            }
          });
        }
      },
    );
  }
}
