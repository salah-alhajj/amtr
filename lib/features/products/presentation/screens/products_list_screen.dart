import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../../manufacturing/presentation/screens/materials_and_templates_screen.dart';
import '../../../printing/services/catalog_pdf_generator.dart';
import '../../../suppliers/presentation/screens/suppliers_list_screen.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../domain/services/product_catalog_service.dart';
import '../bloc/products_bloc.dart';
import '../widgets/add_edit_product_sheet.dart';

class ProductsListScreen extends StatefulWidget {
  const ProductsListScreen({super.key});

  @override
  State<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends State<ProductsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProductCatalogService _catalogService =
      AppServices.instance.productCatalogService;
  Map<String, String> _supplierNames = const {};
  Set<String> _variantProductIds = const {};
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _loadCatalogMetadata();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!mounted) return;
      if (domain == DataDomain.suppliers) {
        _loadSupplierNames();
      } else if (domain == DataDomain.products) {
        _loadVariantProductIds();
      }
    });
  }

  Future<void> _loadCatalogMetadata() async {
    try {
      final meta = await _catalogService.loadCatalogMetadata();
      if (!mounted) return;
      setState(() {
        _supplierNames = meta.supplierNames;
        _variantProductIds = meta.variantProductIds;
      });
    } catch (_) {}
  }

  Future<void> _loadVariantProductIds() async {
    try {
      final ids = await _catalogService.loadVariantProductIds();
      if (!mounted) return;
      setState(() => _variantProductIds = ids);
    } catch (_) {}
  }

  Future<void> _loadSupplierNames() async {
    try {
      final map = await _catalogService.loadSupplierNames();
      if (!mounted) return;
      setState(() => _supplierNames = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddEditSheet([Product? product]) {
    AddEditProductSheet.show(
      context,
      productToEdit: product,
      onSave: (saved) {
        if (product == null) {
          context.read<ProductsBloc>().add(CreateProductEvent(saved));
          AppToast.showSuccess(context, 'product_added_success'.i18n());
        } else {
          context.read<ProductsBloc>().add(UpdateProductEvent(saved));
          AppToast.showSuccess(context, 'product_updated_success'.i18n());
        }
      },
    );
  }

  Future<void> _shareCatalog(List<Product> products) async {
    final activeProducts = products.where((p) => p.isActive).toList();
    if (activeProducts.isEmpty) {
      AppToast.showError(context, 'products_empty_title'.i18n());
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AppModalSheet(
          title: 'product_share_catalog'.i18n(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A2E7D32),
                  child: Icon(Icons.chat_outlined, color: AppColors.primaryGreen),
                ),
                title: Text(
                  'catalog_share_text'.i18n(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final text = WhatsAppTemplateEngine.buildCategorizedCatalogText(
                    activeProducts,
                  );
                  await SharePlus.instance.share(ShareParams(text: text));
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0x1A1565C0),
                  child: Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryBlue),
                ),
                title: Text(
                  'catalog_share_pdf'.i18n(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _shareCatalogPdf(activeProducts);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareCatalogPdf(List<Product> activeProducts) async {
    try {
      final bytes = await CatalogPdfGenerator.generateCatalogPdf(activeProducts);
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/catalog_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(filePath)],
          text: 'catalog_pdf_title'.i18n(),
        ),
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString());
      }
    }
  }

  Future<void> _showProduceBatchDialog(Product product) async {
    final yieldCtrl = TextEditingController(
      text: (product.batchYield > 0 ? product.batchYield : 1).toString(),
    );
    final curingDaysCtrl = TextEditingController();
    final shelfLifeDaysCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    bool deductMaterials = true;
    bool logExpense = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                'mfg_batch_dialog_title'.i18n(),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: ctx.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: yieldCtrl,
                      label: 'mfg_batch_yield_input_label'.i18n(),
                      keyboardType: TextInputType.number,
                      inputFormatters:
                          AppFormatters.positiveInteger(maxDigits: 4),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'mfg_batch_deduct_materials'.i18n(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'mfg_batch_deduct_materials_hint'.i18n(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: deductMaterials,
                      onChanged: (v) =>
                          setDialogState(() => deductMaterials = v),
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        'mfg_batch_log_expense'.i18n(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'mfg_batch_log_expense_hint'.i18n(),
                        style: const TextStyle(fontSize: 11),
                      ),
                      value: logExpense,
                      onChanged: (v) => setDialogState(() => logExpense = v),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: curingDaysCtrl,
                            label: 'mfg_batch_curing_days_label'.i18n(),
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters:
                                AppFormatters.positiveInteger(maxDigits: 3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppTextField(
                            controller: shelfLifeDaysCtrl,
                            label: 'mfg_batch_shelf_life_days_label'.i18n(),
                            hint: '0',
                            keyboardType: TextInputType.number,
                            inputFormatters:
                                AppFormatters.positiveInteger(maxDigits: 3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: notesCtrl,
                      label: 'common_notes'.i18n(),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('common_cancel'.i18n()),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('mfg_batch_confirm_btn'.i18n()),
                ),
              ],
            );
          },
        );
      },
    );

    final parsedYield = int.tryParse(yieldCtrl.text.trim());
    final curingDays = int.tryParse(curingDaysCtrl.text.trim()) ?? 0;
    final shelfLifeDays = int.tryParse(shelfLifeDaysCtrl.text.trim()) ?? 0;
    final notesText = notesCtrl.text.trim();
    yieldCtrl.dispose();
    curingDaysCtrl.dispose();
    shelfLifeDaysCtrl.dispose();
    notesCtrl.dispose();

    if (confirmed != true || !mounted) return;

    try {
      final batch = await _catalogService.produceBatch(
        product: product,
        customYield: (parsedYield != null && parsedYield > 0)
            ? parsedYield
            : product.batchYield,
        deductMaterials: deductMaterials,
        logExpense: logExpense,
        notes: notesText.isEmpty ? null : notesText,
        curingDays: curingDays,
        shelfLifeDays: shelfLifeDays,
      );
      if (mounted) {
        AppToast.showSuccess(
          context,
          curingDays > 0
              ? 'mfg_batch_curing_toast'.trParams({
                  'count': batch.yieldCount.toString(),
                  'days': curingDays.toString(),
                })
              : 'mfg_batch_produced_toast'.trParams({
                  'count': batch.yieldCount.toString(),
                }),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text('products_catalog_title'.i18n()),
        actions: [
          IconButton(
            icon: const Icon(Icons.local_shipping_outlined),
            tooltip: 'suppliers_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SuppliersListScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome_mosaic_outlined),
            tooltip: 'manufacturing_hub_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MaterialsAndTemplatesScreen(),
                ),
              );
            },
          ),
          BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final list = state is ProductsLoaded ? state.allProducts : <Product>[];
              return IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: 'product_share_catalog'.i18n(),
                onPressed: list.isEmpty ? null : () => _shareCatalog(list),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          final selectedFilter =
              state is ProductsLoaded ? state.selectedFilter : 'all';

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppSearchBar(
                  controller: _searchController,
                  hintText: 'product_search_hint'.i18n(),
                  onChanged: (val) =>
                      context.read<ProductsBloc>().add(SearchProducts(val)),
                  onClear: () =>
                      context.read<ProductsBloc>().add(const SearchProducts('')),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    _buildFilterChip(
                      'status_all'.i18n(),
                      'all',
                      selectedFilter,
                    ),
                    _buildFilterChip(
                      'product_type_resale'.i18n(),
                      'type_resale',
                      selectedFilter,
                    ),
                    _buildFilterChip(
                      'product_type_manufactured'.i18n(),
                      'type_manufactured',
                      selectedFilter,
                    ),
                    _buildFilterChip(
                      'product_low_stock_filter'.i18n(),
                      'low_stock',
                      selectedFilter,
                    ),
                    ...AppConstants.productCategories.map(
                      (cat) => _buildFilterChip(cat.i18n(), cat, selectedFilter),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody(context, state, cs)),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'products_fab',
        onPressed: () => _openAddEditSheet(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'product_add_title'.i18n(),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String current) {
    final isSelected = value == current;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: AppFilterChip(
        label: label,
        isSelected: isSelected,
        activeColor: value == 'low_stock'
            ? AppColors.statusDanger
            : AppColors.primaryBlue,
        onSelected: (_) {
          context.read<ProductsBloc>().add(FilterProducts(value));
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ProductsState state,
    CurrencyService cs,
  ) {
    if (state is ProductsLoading || state is ProductsInitial) {
      return AppShimmer.list(itemCount: 5);
    }
    if (state is ProductsError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => context.read<ProductsBloc>().add(const LoadProducts()),
      );
    }
    if (state is ProductsLoaded) {
      if (state.displayedProducts.isEmpty) {
        return EmptyStateView(
          icon: Icons.storefront_outlined,
          title: 'products_empty_title'.i18n(),
          subtitle: 'products_empty_subtitle'.i18n(),
          actionLabel: 'product_add_title'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () => _openAddEditSheet(),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<ProductsBloc>().add(const LoadProducts());
        },
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: state.displayedProducts.length,
          itemBuilder: (context, idx) {
            final p = state.displayedProducts[idx];
            final supplierName =
                p.supplierId != null ? _supplierNames[p.supplierId!] : null;
            return AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () => _openAddEditSheet(p),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AppBadge(
                        label: p.category.i18n(),
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      AppBadge(
                        label: AppConstants.getProductTypeLabel(p.productType),
                        color: AppConstants.getProductTypeColor(p.productType),
                        icon: p.isManufactured
                            ? Icons.precision_manufacturing_outlined
                            : Icons.storefront_outlined,
                        fontSize: 10,
                      ),
                      if (supplierName != null)
                        AppBadge(
                          label: supplierName,
                          color: AppColors.vibrantTeal,
                          icon: Icons.local_shipping_outlined,
                          fontSize: 10,
                        ),
                      if (p.isBundle)
                        AppBadge(
                          label: 'product_badge_bundle'.i18n(),
                          color: AppColors.deepNavy,
                          icon: Icons.inventory_2_outlined,
                          fontSize: 10,
                        ),
                      if (_variantProductIds.contains(p.id))
                        AppBadge(
                          label: 'product_badge_has_variants'.i18n(),
                          color: AppColors.primaryBlue,
                          icon: Icons.style_outlined,
                          fontSize: 10,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${'product_sell_price_clean_label'.i18n()}: ',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      Text(
                        cs.formatAmount(p.sellPrice, currencyCode: p.currency),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      Text(
                        '(${p.unit})',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                        ),
                      ),
                      if (p.costPrice > 0)
                        Text(
                          '${'order_estimated_profit'.i18n()}: ${cs.formatAmount(p.unitProfit, currencyCode: p.currency)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (p.trackStock) ...[
                              AppBadge(
                                label: p.isOutOfStock
                                    ? 'product_out_of_stock'.i18n()
                                    : '${'product_stock_label'.i18n()}: ${p.stockQuantity}',
                                color: p.isLowStock
                                    ? AppColors.statusDanger
                                    : AppColors.primaryGreen,
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: p.stockQuantity > 0
                                    ? () => context
                                        .read<ProductsBloc>()
                                        .add(AdjustProductStockEvent(p.id, -1))
                                    : null,
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => context
                                    .read<ProductsBloc>()
                                    .add(AdjustProductStockEvent(p.id, 1)),
                              ),
                              if (p.isManufactured && p.batchYield > 1)
                                TextButton.icon(
                                  onPressed: () => _showProduceBatchDialog(p),
                                  icon: const Icon(Icons.bolt_rounded, size: 16),
                                  label: Text(
                                    'mfg_produce_batch_btn'.trParams({
                                      'count': p.batchYield.toString(),
                                    }),
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                            ] else
                              AppBadge(
                                label: 'product_made_to_order'.i18n(),
                                color: AppColors.deepNavy,
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.statusDanger,
                          size: 20,
                        ),
                        visualDensity: VisualDensity.compact,
                        onPressed: () async {
                          final confirm = await showAppConfirmationDialog(
                            context: context,
                            title: 'common_delete'.i18n(),
                            message: 'product_delete_confirm'.i18n(),
                            isDestructive: true,
                          );
                          if (confirm == true && context.mounted) {
                            context
                                .read<ProductsBloc>()
                                .add(DeleteProductEvent(p.id));
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
