import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/production_batch.dart';
import '../../../../models/waste_log.dart';
import '../../data/repositories/production_batch_repository.dart';
import '../../data/repositories/waste_log_repository.dart';
import '../widgets/produce_batch_sheet.dart';
import '../widgets/record_waste_sheet.dart';

/// شاشة متابعة تشغيلات الإنتاج والتعتيق وسجل الهالك والتالف
class ProductionBatchesScreen extends StatefulWidget {
  const ProductionBatchesScreen({super.key});

  @override
  State<ProductionBatchesScreen> createState() =>
      _ProductionBatchesScreenState();
}

class _ProductionBatchesScreenState extends State<ProductionBatchesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _batchRepo = ProductionBatchRepository();
  final _wasteRepo = WasteLogRepository();

  List<ProductionBatch> _batches = const [];
  List<WasteLog> _wasteLogs = const [];
  final Set<String> _markingBatchIds = {};
  String _batchFilter = 'all'; // 'all' | 'curing' | 'ready'
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
      if (domain == DataDomain.products || domain == DataDomain.materials) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _batchRepo.getAllBatches(),
        _wasteRepo.getAll(),
      ]);
      if (!mounted) return;
      setState(() {
        _batches = results[0] as List<ProductionBatch>;
        _wasteLogs = results[1] as List<WasteLog>;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markReady(ProductionBatch batch) async {
    if (_markingBatchIds.contains(batch.id)) return;
    setState(() => _markingBatchIds.add(batch.id));
    try {
      await _batchRepo.markBatchReady(batch);
      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'batch_marked_ready_toast'.trParams({'name': batch.productName}),
      );
      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _markingBatchIds.remove(batch.id));
      }
    }
  }

  Future<void> _deleteWasteLog(WasteLog log) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'waste_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;
    try {
      await _wasteRepo.delete(log.id);
      if (!mounted) return;
      AppToast.showSuccess(context, 'waste_deleted_success'.i18n());
      await _loadData();
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, e.toString());
      }
    }
  }

  Future<void> _openProduceBatch() async {
    final created = await ProduceBatchSheet.show(context);
    if (created != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _openRecordWaste() async {
    final created = await RecordWasteSheet.show(context);
    if (created != null && mounted) {
      await _loadData();
    }
  }

  List<ProductionBatch> get _filteredBatches {
    switch (_batchFilter) {
      case AppConstants.batchStatusCuring:
        return _batches.where((b) => b.isCuring).toList();
      case AppConstants.batchStatusReady:
        return _batches.where((b) => b.isReady).toList();
      default:
        return _batches;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final isWasteTab = _tabController.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('batches_screen_title'.i18n()),
        actions: [
          IconButton(
            icon: Icon(
              isWasteTab
                  ? Icons.delete_sweep_outlined
                  : Icons.precision_manufacturing_outlined,
            ),
            tooltip: isWasteTab
                ? 'waste_sheet_title'.i18n()
                : 'batch_add_btn'.i18n(),
            onPressed: isWasteTab ? _openRecordWaste : _openProduceBatch,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: context.borderDivider, width: 0.7),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded, size: 17),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'batches_tab_production'.i18n(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.delete_sweep_outlined, size: 17),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'batches_tab_waste'.i18n(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isWasteTab ? _openRecordWaste : _openProduceBatch,
        backgroundColor:
            isWasteTab ? AppColors.statusDanger : AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          isWasteTab ? 'waste_add_btn'.i18n() : 'batch_add_btn'.i18n(),
        ),
      ),
      body: _isLoading
          ? AppShimmer.list(itemCount: 4)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBatchesTab(cs),
                _buildWasteTab(cs),
              ],
            ),
    );
  }

  Widget _buildBatchesTab(CurrencyService cs) {
    if (_batches.isEmpty) {
      return EmptyStateView(
        icon: Icons.hourglass_empty_rounded,
        title: 'batches_empty_title'.i18n(),
        subtitle: 'batches_empty_subtitle'.i18n(),
        actionLabel: 'batch_add_btn'.i18n(),
        actionIcon: Icons.add_rounded,
        onActionPressed: _openProduceBatch,
      );
    }

    final curingCount = _batches.where((b) => b.isCuring).length;
    final readyCount = _batches.where((b) => b.isReady).length;
    final expiringCount = _batches.where((b) => b.isExpiringSoon).length;
    final visible = _filteredBatches;
    final fmt = DateFormat('yyyy/MM/dd');

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
        children: [
          // ملخص KPI سريع لحالة التشغيلات
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _buildKpiPill(
                  label: 'batch_kpi_curing'.i18n(),
                  value: '$curingCount',
                  color: AppColors.statusWarning,
                  icon: Icons.hourglass_top_rounded,
                ),
                const SizedBox(width: 8),
                _buildKpiPill(
                  label: 'batch_kpi_ready'.i18n(),
                  value: '$readyCount',
                  color: AppColors.primaryGreen,
                  icon: Icons.check_circle_outline_rounded,
                ),
                const SizedBox(width: 8),
                _buildKpiPill(
                  label: 'batch_kpi_expiring'.i18n(),
                  value: '$expiringCount',
                  color: AppColors.statusDanger,
                  icon: Icons.warning_amber_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // فلاتر الحالة
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildFilterChip('all', 'batch_filter_all'.i18n()),
              _buildFilterChip(
                AppConstants.batchStatusCuring,
                'batch_status_curing'.i18n(),
              ),
              _buildFilterChip(
                AppConstants.batchStatusReady,
                'batch_status_ready'.i18n(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (visible.isEmpty)
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'batches_empty_title'.i18n(),
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
            )
          else
            ...visible.map((batch) => _buildBatchCard(batch, cs, fmt)),
        ],
      ),
    );
  }

  Widget _buildKpiPill({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final selected = _batchFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _batchFilter = filterKey),
    );
  }

  Widget _buildBatchCard(
    ProductionBatch batch,
    CurrencyService cs,
    DateFormat fmt,
  ) {
    final isCuring = batch.isCuring;
    final isMarking = _markingBatchIds.contains(batch.id);
    final statusColor = AppConstants.getBatchStatusColor(batch.batchStatus);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      backgroundColor:
          isCuring ? AppColors.statusWarning.withValues(alpha: 0.05) : null,
      border: isCuring
          ? Border.all(
              color: AppColors.statusWarning.withValues(alpha: 0.35),
              width: 1.1,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isCuring
                      ? Icons.hourglass_bottom_rounded
                      : Icons.inventory_2_outlined,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  batch.productName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppBadge(
                label: AppConstants.getBatchStatusLabel(batch.batchStatus),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              AppBadge(
                label: '×${batch.yieldCount}',
                color: AppColors.primaryBlue,
                fontSize: 11,
              ),
              if (batch.totalCost > 0)
                AppBadge(
                  label: cs.formatAmount(
                    batch.totalCost,
                    currencyCode: batch.currency,
                  ),
                  color: AppColors.vibrantTeal,
                  fontSize: 11,
                ),
              if (isCuring)
                AppBadge(
                  label: batch.daysUntilReady > 0
                      ? 'batch_days_until_ready_fmt'.trParams({
                          'days': batch.daysUntilReady.toString(),
                        })
                      : 'batch_ready_today_label'.i18n(),
                  color: AppColors.statusWarning,
                  icon: Icons.schedule_rounded,
                  fontSize: 11,
                ),
              if (batch.isExpiringSoon)
                AppBadge(
                  label: 'batch_expiring_soon_badge'.i18n(),
                  color: AppColors.statusDanger,
                  icon: Icons.warning_amber_rounded,
                  fontSize: 11,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '${'batch_produced_at_label'.i18n()}: ${fmt.format(batch.producedAt)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.textSecondary,
                ),
              ),
              if (batch.readyAt != null)
                Text(
                  '${'batch_ready_at_label'.i18n()}: ${fmt.format(batch.readyAt!)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.textSecondary,
                  ),
                ),
              if (batch.expiresAt != null)
                Text(
                  '${'batch_expires_at_label'.i18n()}: ${fmt.format(batch.expiresAt!)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: batch.isExpiringSoon
                        ? AppColors.statusDanger
                        : context.textSecondary,
                  ),
                ),
            ],
          ),
          if (batch.notes != null && batch.notes!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              batch.notes!,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
              ),
            ),
          ],
          if (isCuring) ...[
            const SizedBox(height: 12),
            AppPrimaryButton(
              label: 'batch_mark_ready_btn'.i18n(),
              icon: Icons.check_circle_outline_rounded,
              height: 40,
              backgroundColor: AppColors.primaryGreen,
              isLoading: isMarking,
              onPressed: isMarking ? null : () => _markReady(batch),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWasteTab(CurrencyService cs) {
    final totalLossYer = _wasteLogs.fold<double>(
      0.0,
      (sum, log) => sum + log.estimatedLossYer,
    );

    if (_wasteLogs.isEmpty) {
      return EmptyStateView(
        icon: Icons.delete_sweep_outlined,
        title: 'waste_empty_title'.i18n(),
        subtitle: 'waste_empty_subtitle'.i18n(),
        actionLabel: 'waste_add_btn'.i18n(),
        actionIcon: Icons.add_rounded,
        onActionPressed: _openRecordWaste,
      );
    }

    final fmt = DateFormat('yyyy/MM/dd');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
        itemCount: _wasteLogs.length + 1,
        itemBuilder: (context, idx) {
          if (idx == 0) {
            return AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              backgroundColor: AppColors.statusDanger.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.statusDanger.withValues(alpha: 0.25),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.statusDanger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.delete_sweep_outlined,
                      size: 22,
                      color: AppColors.statusDanger,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'waste_total_loss_label'.i18n(),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          cs.formatAmount(
                            totalLossYer,
                            currencyCode: AppConstants.currencyYer,
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: '${_wasteLogs.length}',
                    color: AppColors.statusDanger,
                  ),
                ],
              ),
            );
          }

          final log = _wasteLogs[idx - 1];
          final qtyStr = log.quantity == log.quantity.roundToDouble()
              ? log.quantity.toStringAsFixed(0)
              : log.quantity
                  .toStringAsFixed(2)
                  .replaceFirst(RegExp(r'\.?0+$'), '');

          return AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (log.isProduct
                            ? AppColors.primaryBlue
                            : AppColors.vibrantTeal)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    log.isProduct
                        ? Icons.inventory_2_outlined
                        : Icons.science_outlined,
                    size: 18,
                    color: log.isProduct
                        ? AppColors.primaryBlue
                        : AppColors.vibrantTeal,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.itemName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          AppBadge(
                            label: log.isProduct
                                ? 'waste_type_product'.i18n()
                                : 'waste_type_material'.i18n(),
                            color: log.isProduct
                                ? AppColors.primaryBlue
                                : AppColors.vibrantTeal,
                            fontSize: 10,
                          ),
                          AppBadge(
                            label: '$qtyStr ${log.unit}',
                            color: AppColors.deepNavy,
                            fontSize: 10,
                          ),
                          AppBadge(
                            label: AppConstants.getWasteReasonLabel(log.reason),
                            color: AppColors.statusWarning,
                            fontSize: 10,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            cs.formatAmount(
                              log.estimatedLossYer,
                              currencyCode: AppConstants.currencyYer,
                            ),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusDanger,
                            ),
                          ),
                          Text(
                            fmt.format(log.loggedAt),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      if (log.notes != null &&
                          log.notes!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          log.notes!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
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
                  onPressed: () => _deleteWasteLog(log),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
