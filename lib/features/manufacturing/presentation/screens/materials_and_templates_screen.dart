import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/manufacturing_template.dart';
import '../../../../models/raw_material.dart';
import '../../../products/data/repositories/product_repository_impl.dart';
import '../../../suppliers/data/repositories/supplier_repository_impl.dart';
import '../../data/repositories/manufacturing_template_repository.dart';
import '../../data/repositories/raw_material_repository.dart';
import '../../domain/manufacturing_cost_service.dart';
import '../widgets/add_edit_material_sheet.dart';
import '../widgets/production_recipe_builder_sheet.dart';
import 'daily_prep_shopping_screen.dart';
import 'production_batches_screen.dart';

/// شاشة إدارة مكتبة المواد الخام وقوالب التصنيع القابلة لإعادة الاستخدام
class MaterialsAndTemplatesScreen extends StatefulWidget {
  const MaterialsAndTemplatesScreen({super.key});

  @override
  State<MaterialsAndTemplatesScreen> createState() =>
      _MaterialsAndTemplatesScreenState();
}

class _MaterialsAndTemplatesScreenState
    extends State<MaterialsAndTemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _materialRepo = RawMaterialRepository();
  final _templateRepo = ManufacturingTemplateRepository();
  final _supplierRepo = SupplierRepositoryImpl();
  final _productRepo = ProductRepositoryImpl();
  final _costService = ManufacturingCostService();
  final _searchController = TextEditingController();

  List<RawMaterial> _materials = const [];
  List<ManufacturingTemplate> _templates = const [];
  Map<String, String> _supplierNames = const {};
  String _searchQuery = '';
  bool _isLoading = true;
  StreamSubscription<DataDomain>? _syncSub;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (!mounted) return;
      if (domain == DataDomain.materials || domain == DataDomain.suppliers) {
        _loadData();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _materialRepo.getAll(),
        _templateRepo.getAllTemplates(),
        _supplierRepo.getAllSuppliers(),
      ]);
      if (!mounted) return;
      final suppliers = results[2] as List;
      final names = <String, String>{};
      for (final s in suppliers) {
        names[s.id as String] = s.name as String;
      }
      setState(() {
        _materials = results[0] as List<RawMaterial>;
        _templates = results[1] as List<ManufacturingTemplate>;
        _supplierNames = names;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatQty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  Future<void> _openMaterialSheet([RawMaterial? material]) async {
    final saved = await AddEditMaterialSheet.show(
      context,
      materialToEdit: material,
    );
    if (saved == null || !mounted) return;

    await _materialRepo.save(saved);
    if (!mounted) return;
    AppToast.showSuccess(context, 'material_saved_success'.i18n());

    final priceChanged = material != null &&
        ((saved.unitCost - material.unitCost).abs() > 0.0001 ||
            saved.currency != material.currency);

    List<MaterialPriceImpact> impacts = const [];
    if (priceChanged) {
      impacts = await _costService.recalculateOnMaterialPriceChange(saved);
    }

    if (!mounted) return;
    await _loadData();
    if (!mounted) return;

    final eroded = impacts.where((i) => i.isMarginEroded).toList();
    if (eroded.isNotEmpty) {
      await _showMarginErosionSheet(eroded);
    } else if (impacts.isNotEmpty) {
      AppToast.showInfo(
        context,
        'mfg_products_cost_recalculated_fmt'.trParams({
          'count': impacts.length.toString(),
        }),
      );
    }
  }

  Future<void> _showMarginErosionSheet(List<MaterialPriceImpact> eroded) async {
    final cs = CurrencyService.instance;
    final appliedIds = <String>{};

    await showAppModalSheet<void>(
      context: context,
      title: 'mfg_margin_erosion_title'.i18n(),
      subtitle: 'mfg_margin_erosion_subtitle'.i18n(),
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          final maxHeight = MediaQuery.sizeOf(sheetCtx).height * 0.65;
          return ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: eroded.map((impact) {
                  final p = impact.product;
                  final isApplied = appliedIds.contains(p.id);
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.trending_down_rounded,
                              size: 18,
                              color: AppColors.statusDanger,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                p.name,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (isApplied)
                              AppBadge(
                                label: 'mfg_price_updated_badge'.i18n(),
                                color: AppColors.primaryGreen,
                                icon: Icons.check_circle_outline_rounded,
                                fontSize: 10.5,
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            AppBadge(
                              label: 'mfg_old_to_new_cost_fmt'.trParams({
                                'old': cs.formatAmount(
                                  impact.oldCost,
                                  currencyCode: p.currency,
                                ),
                                'new': cs.formatAmount(
                                  impact.newCost,
                                  currencyCode: p.currency,
                                ),
                              }),
                              color: AppColors.primaryBlue,
                              fontSize: 10.5,
                            ),
                            AppBadge(
                              label: 'mfg_margin_change_fmt'.trParams({
                                'old': impact.oldMarginPercent.toStringAsFixed(0),
                                'new': impact.newMarginPercent.toStringAsFixed(0),
                              }),
                              color: AppColors.statusDanger,
                              fontSize: 10.5,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${'pricing_suggested_price'.i18n()}: ${cs.formatAmount(impact.suggestedSellPrice, currencyCode: p.currency)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: isApplied
                                  ? null
                                  : () async {
                                      await _productRepo.updateProduct(
                                        p.copyWith(
                                          sellPrice: impact.suggestedSellPrice,
                                        ),
                                      );
                                      setSheetState(() {
                                        appliedIds.add(p.id);
                                      });
                                      if (mounted) {
                                        AppToast.showSuccess(
                                          context,
                                          'product_updated_success'.i18n(),
                                        );
                                      }
                                    },
                              child: Text(
                                'mfg_apply_suggested_price_btn'.i18n(),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openTemplateBuilder([ManufacturingTemplate? template]) async {
    final result = await ProductionRecipeBuilderSheet.showForTemplate(
      context,
      currency: PreferencesService.instance.getDefaultCurrency(),
      templateToEdit: template,
    );
    if (result != null && mounted) {
      AppToast.showSuccess(context, 'template_saved_success'.i18n());
      await _loadData();
    }
  }

  Future<void> _deleteMaterial(RawMaterial m) async {
    final ok = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'material_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    await _materialRepo.delete(m.id);
    DataSyncBus.instance.notify(DataDomain.materials);
    await _loadData();
  }

  Future<void> _deleteTemplate(ManufacturingTemplate t) async {
    final ok = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'template_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    await _templateRepo.deleteTemplate(t.id);
    DataSyncBus.instance.notify(DataDomain.materials);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final isMaterialsTab = _tabController.index == 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('manufacturing_hub_title'.i18n()),
        actions: [
          IconButton(
            icon: const Icon(Icons.hourglass_bottom_rounded),
            tooltip: 'batches_screen_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductionBatchesScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.checklist_rtl_rounded),
            tooltip: 'prep_screen_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DailyPrepAndShoppingScreen(),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.science_outlined, size: 18),
              text: 'mfg_tab_materials'.i18n(),
            ),
            Tab(
              icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 18),
              text: 'mfg_tab_templates'.i18n(),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: AppSearchBar(
              controller: _searchController,
              hintText: isMaterialsTab
                  ? 'material_search_hint'.i18n()
                  : 'template_search_hint'.i18n(),
              onChanged: (val) => setState(() => _searchQuery = val),
              onClear: () => setState(() => _searchQuery = ''),
            ),
          ),
          Expanded(
            child: _isLoading
                ? AppShimmer.list(itemCount: 4)
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMaterialsTab(cs),
                      _buildTemplatesTab(cs),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'manufacturing_fab',
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          isMaterialsTab
              ? 'material_add_title'.i18n()
              : 'template_add_title'.i18n(),
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () => isMaterialsTab
            ? _openMaterialSheet()
            : _openTemplateBuilder(),
      ),
    );
  }

  Widget _buildMaterialsTab(CurrencyService cs) {
    final q = _searchQuery.trim().toLowerCase();
    final items = q.isEmpty
        ? _materials
        : _materials
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.unit.toLowerCase().contains(q))
            .toList();

    if (items.isEmpty) {
      return EmptyStateView(
        icon: Icons.science_outlined,
        title: 'materials_empty_title'.i18n(),
        subtitle: 'materials_empty_subtitle'.i18n(),
        actionLabel: 'material_add_title'.i18n(),
        actionIcon: Icons.add,
        onActionPressed: () => _openMaterialSheet(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, idx) {
          final m = items[idx];
          final supplierName =
              m.supplierId != null ? _supplierNames[m.supplierId!] : null;
          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => _openMaterialSheet(m),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          AppBadge(
                            label:
                                '${cs.formatAmount(m.unitCost, currencyCode: m.currency)} / ${m.unit}',
                            color: AppColors.primaryBlue,
                          ),
                          if (m.stockQuantity > 0 || m.lowStockThreshold > 0)
                            AppBadge(
                              label: (m.isLowStock
                                      ? 'material_low_stock_badge_fmt'
                                      : 'material_stock_badge_fmt')
                                  .trParams({
                                'qty': _formatQty(m.stockQuantity),
                                'unit': m.unit,
                              }),
                              color: m.isLowStock
                                  ? AppColors.statusDanger
                                  : AppColors.primaryGreen,
                              icon: m.isLowStock
                                  ? Icons.warning_amber_rounded
                                  : Icons.inventory_2_outlined,
                            ),
                          if (supplierName != null)
                            AppBadge(
                              label: supplierName,
                              color: AppColors.vibrantTeal,
                              icon: Icons.local_shipping_outlined,
                            ),
                        ],
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
                  onPressed: () => _deleteMaterial(m),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTemplatesTab(CurrencyService cs) {
    final q = _searchQuery.trim().toLowerCase();
    final items = q.isEmpty
        ? _templates
        : _templates
            .where((t) => t.name.toLowerCase().contains(q))
            .toList();

    if (items.isEmpty) {
      return EmptyStateView(
        icon: Icons.auto_awesome_mosaic_outlined,
        title: 'templates_empty_title'.i18n(),
        subtitle: 'templates_empty_subtitle'.i18n(),
        actionLabel: 'template_add_title'.i18n(),
        actionIcon: Icons.add,
        onActionPressed: () => _openTemplateBuilder(),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        itemBuilder: (context, idx) {
          final t = items[idx];
          final matCount = t.items.where((i) => i.isMaterial).length;
          final ovCount = t.items.where((i) => !i.isMaterial).length;
          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => _openTemplateBuilder(t),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          AppBadge(
                            label: 'template_yield_fmt'.trParams({
                              'count': t.yieldCount.toString(),
                            }),
                            color: AppColors.primaryBlue,
                            fontSize: 10,
                          ),
                          AppBadge(
                            label: 'mfg_items_summary_fmt'.trParams({
                              'materials': matCount.toString(),
                              'overhead': ovCount.toString(),
                            }),
                            color: AppColors.vibrantTeal,
                            fontSize: 10,
                          ),
                          AppBadge(
                            label:
                                '${'pricing_unit_cost_label'.i18n()}: ${cs.formatAmount(t.unitCost, currencyCode: t.currency)}',
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                          ),
                        ],
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
                  onPressed: () => _deleteTemplate(t),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
