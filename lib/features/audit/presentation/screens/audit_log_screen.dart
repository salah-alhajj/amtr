import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/audit/audit.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../widgets/audit_diff_comparison_sheet.dart';

/// مركز التدقيق المركزي الشامل لعرض كافة العمليات وفحص السلامة ومقارنة الفوارق البصرية
class AuditLogScreen extends StatefulWidget {
  final String? entityType;
  final String? entityId;
  final String? entityTitle;

  const AuditLogScreen({
    super.key,
    this.entityType,
    this.entityId,
    this.entityTitle,
  });

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final AuditRepository _repo = AppServices.instance.auditRepository;

  List<AuditEntry> _entries = const [];
  AuditStatsSummary _stats = const AuditStatsSummary();
  AuditIntegrityReport? _integrityReport;
  String? _selectedAction;
  String? _selectedEntityType;
  bool _isLoading = true;
  bool _isVerifying = false;
  StreamSubscription<DataDomain>? _syncSub;

  bool get _isScoped =>
      widget.entityType != null &&
      widget.entityType!.isNotEmpty &&
      widget.entityId != null &&
      widget.entityId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _selectedEntityType = widget.entityType;
    _loadData();
    _syncSub = DataSyncBus.instance.stream.listen((domain) {
      if (domain == DataDomain.audit && mounted) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.queryLogs(
          entityType: _isScoped ? widget.entityType : _selectedEntityType,
          entityId: _isScoped ? widget.entityId : null,
          action: _selectedAction,
          searchQuery: _searchCtrl.text.trim(),
          limit: 200,
        ),
        _repo.getStatsSummary(),
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0] as List<AuditEntry>;
        _stats = results[1] as AuditStatsSummary;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyChain() async {
    setState(() => _isVerifying = true);
    try {
      final report = await _repo.verifyIntegrityChain();
      if (!mounted) return;
      setState(() {
        _integrityReport = report;
        _isVerifying = false;
      });
      if (report.isIntact) {
        AppToast.showSuccess(
          context,
          'audit_chain_intact'.trParams({
            'count': report.verifiedEntries.toString(),
            'total': report.totalEntries.toString(),
          }),
        );
      } else {
        AppToast.showError(
          context,
          'audit_chain_tampered'.trParams({
            'count': report.tamperedEntryIds.length.toString(),
          }),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Color _actionColor(String action) {
    switch (action) {
      case AuditAction.create:
        return AppColors.primaryGreen;
      case AuditAction.delete:
        return AppColors.statusDanger;
      case AuditAction.payment:
      case AuditAction.settlement:
      case AuditAction.closing:
        return AppColors.vibrantTeal;
      case AuditAction.stockAdjust:
      case AuditAction.rateUpdate:
        return AppColors.statusWarning;
      case AuditAction.update:
      case AuditAction.statusChange:
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case AuditAction.create:
        return Icons.add_circle_outline_rounded;
      case AuditAction.delete:
        return Icons.delete_outline_rounded;
      case AuditAction.payment:
      case AuditAction.settlement:
        return Icons.payments_outlined;
      case AuditAction.closing:
        return Icons.lock_clock_outlined;
      case AuditAction.stockAdjust:
        return Icons.inventory_2_outlined;
      case AuditAction.rateUpdate:
        return Icons.currency_exchange_rounded;
      case AuditAction.statusChange:
        return Icons.sync_alt_rounded;
      case AuditAction.update:
      default:
        return Icons.edit_note_rounded;
    }
  }

  String _translateFieldName(String key) {
    final k = AuditDiffEngine.fieldLabelKey(key);
    final t = k.i18n();
    return t == k ? key : t;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final title = _isScoped
        ? 'audit_entity_history_title'.trParams({
            'name': widget.entityTitle ?? widget.entityId!,
          })
        : 'audit_center_title'.i18n();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.verified_user_outlined),
              tooltip: 'audit_verify_chain_btn'.i18n(),
              onPressed: _verifyChain,
            ),
        ],
      ),
      body: Column(
        children: [
          AppSearchBar(
            controller: _searchCtrl,
            hintText: 'audit_search_hint'.i18n(),
            onChanged: (_) => _loadData(),
            onClear: _loadData,
          ),
          if (!_isScoped) _buildStatsHeader(context),
          if (_integrityReport != null) _buildIntegrityBanner(context),
          _buildFilterStrip(context),
          Expanded(
            child: _isLoading
                ? AppShimmer.list(itemCount: 6)
                : _entries.isEmpty
                    ? EmptyStateView(
                        icon: Icons.manage_search_rounded,
                        title: 'audit_empty_title'.i18n(),
                        subtitle: 'audit_empty_subtitle'.i18n(),
                        actionLabel: (_selectedAction != null ||
                                (!_isScoped && _selectedEntityType != null) ||
                                _searchCtrl.text.isNotEmpty)
                            ? 'audit_reset_filters'.i18n()
                            : null,
                        onActionPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _selectedAction = null;
                            if (!_isScoped) _selectedEntityType = null;
                          });
                          _loadData();
                        },
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _buildAuditCard(context, _entries[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          _buildStatPill(
            context,
            label: 'audit_stats_total'.i18n(),
            value: _stats.totalLogs.toString(),
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          _buildStatPill(
            context,
            label: 'audit_stats_today'.i18n(),
            value: _stats.todayLogs.toString(),
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 8),
          _buildStatPill(
            context,
            label: 'audit_stats_financial'.i18n(),
            value: _stats.financialCount.toString(),
            color: AppColors.vibrantTeal,
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntegrityBanner(BuildContext context) {
    final report = _integrityReport!;
    final color =
        report.isIntact ? AppColors.primaryGreen : AppColors.statusDanger;
    final msg = report.isIntact
        ? 'audit_chain_intact'.trParams({
            'count': report.verifiedEntries.toString(),
            'total': report.totalEntries.toString(),
          })
        : 'audit_chain_tampered'.trParams({
            'count': report.tamperedEntryIds.length.toString(),
          });

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: AppStatusBanner(
        message: msg,
        icon: report.isIntact
            ? Icons.verified_rounded
            : Icons.gpp_bad_outlined,
        tintColor: color,
      ),
    );
  }

  Widget _buildFilterStrip(BuildContext context) {
    final actions = [
      null,
      AuditAction.create,
      AuditAction.update,
      AuditAction.delete,
      AuditAction.payment,
      AuditAction.stockAdjust,
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: actions.map((action) {
          final isSelected = _selectedAction == action;
          final label = action == null
              ? 'audit_filter_all'.i18n()
              : ('audit_action_$action').i18n();
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppFilterChip(
              label: label,
              isSelected: isSelected,
              activeColor:
                  action == null ? AppColors.primaryBlue : _actionColor(action),
              onSelected: (_) {
                setState(() => _selectedAction = action);
                _loadData();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAuditCard(BuildContext context, AuditEntry entry) {
    final color = _actionColor(entry.action);
    final diffs = entry.diffs;
    final previewDiffs = diffs.take(2).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: () => AuditDiffComparisonSheet.show(context, entry: entry),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Icon(_actionIcon(entry.action), size: 17, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${('audit_entity_${entry.entityType}').i18n()} • ${entry.entityLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        entry.summary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppBadge(
                      label: ('audit_action_${entry.action}').i18n(),
                      color: color,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('MM/dd HH:mm').format(entry.createdAt),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (previewDiffs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: context.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...previewDiffs.map((d) {
                      final fieldLabel = _translateFieldName(d.fieldKey);
                      final oldVal = AuditDiffEngine.formatDisplayValue(d.oldValue);
                      final newVal = AuditDiffEngine.formatDisplayValue(d.newValue);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                fieldLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondary,
                                ),
                              ),
                            ),
                            if (d.changeType == DiffChangeType.modified) ...[
                              Flexible(
                                child: Text(
                                  oldVal,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.statusDanger,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 12,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  newVal,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                              ),
                            ] else
                              Flexible(
                                flex: 2,
                                child: Text(
                                  d.changeType == DiffChangeType.added
                                      ? '+ $newVal'
                                      : '− $oldVal',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: d.changeType == DiffChangeType.added
                                        ? AppColors.primaryGreen
                                        : AppColors.statusDanger,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'audit_fields_changed_count'.trParams({
                    'count': entry.changedFieldsCount.toString(),
                  }),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textSecondary,
                  ),
                ),
                if (entry.financialImpactYer.abs() > 0.01)
                  CurrencyPriceDisplay(
                    amount: entry.financialImpactYer,
                    currency: AppConstants.currencyYer,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: entry.financialImpactYer >= 0
                          ? AppColors.primaryGreen
                          : AppColors.statusDanger,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
