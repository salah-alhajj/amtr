import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/audit/audit.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// ورقة مقارنة الفوارق البصرية والتاريخية لكل عملية تدقيق (فوارق بصرية، قبل/بعد، ومقارنة نسختين)
class AuditDiffComparisonSheet extends StatefulWidget {
  final AuditEntry entry;

  const AuditDiffComparisonSheet({
    super.key,
    required this.entry,
  });

  static Future<void> show(
    BuildContext context, {
    required AuditEntry entry,
  }) {
    return showAppModalSheet<void>(
      context: context,
      title: 'audit_diff_sheet_title'.i18n(),
      subtitle: '${('audit_entity_${entry.entityType}').i18n()} • ${entry.entityLabel}',
      child: AuditDiffComparisonSheet(entry: entry),
    );
  }

  @override
  State<AuditDiffComparisonSheet> createState() =>
      _AuditDiffComparisonSheetState();
}

class _AuditDiffComparisonSheetState extends State<AuditDiffComparisonSheet> {
  int _selectedTab = 0; // 0: Visual Diff, 1: Side-by-Side, 2: Compare Revisions
  bool _changesOnlySideBySide = true;
  bool _loadingHistory = false;
  List<AuditEntry> _history = const [];
  String? _olderEntryId;
  String? _newerEntryId;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final list = await AppServices.instance.auditRepository.getEntityHistory(
        widget.entry.entityType,
        widget.entry.entityId,
      );
      if (!mounted) return;
      setState(() {
        _history = list;
        if (list.length >= 2) {
          _olderEntryId = list.first.id;
          _newerEntryId = list.last.id;
        } else if (list.isNotEmpty) {
          _olderEntryId = list.first.id;
          _newerEntryId = list.first.id;
        }
        _loadingHistory = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  String _translateFieldName(String key) {
    final mappedKey = AuditDiffEngine.fieldLabelKey(key);
    final translated = mappedKey.i18n();
    return translated == mappedKey ? key : translated;
  }

  String _formatRawVal(dynamic val) {
    final base = AuditDiffEngine.formatDisplayValue(val);
    if (base == '—') return base;
    final parsed = num.tryParse(base);
    if (parsed != null && (base.contains('.') == false || parsed >= 1000)) {
      if (parsed is int || parsed == parsed.roundToDouble()) {
        return NumberFormat('#,##0', 'en').format(parsed.toInt());
      }
      return NumberFormat('#,##0.##', 'en').format(parsed);
    }
    return base;
  }

  Color _diffColor(DiffChangeType type) {
    switch (type) {
      case DiffChangeType.added:
        return AppColors.primaryGreen;
      case DiffChangeType.removed:
        return AppColors.statusDanger;
      case DiffChangeType.modified:
        return AppColors.primaryBlue;
    }
  }

  String _diffBadgeLabel(DiffChangeType type) {
    switch (type) {
      case DiffChangeType.added:
        return 'audit_diff_added_badge'.i18n();
      case DiffChangeType.removed:
        return 'audit_diff_removed_badge'.i18n();
      case DiffChangeType.modified:
        return 'audit_diff_modified_badge'.i18n();
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeaderSummaryBar(context),
          const SizedBox(height: 10),
          _buildModeTabs(context),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: _buildSelectedTabBody(context),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'audit_checksum_label'.trParams({
              'seq': widget.entry.sequenceNo.toString(),
              'hash': widget.entry.checksum.length >= 12
                  ? widget.entry.checksum.substring(0, 12)
                  : widget.entry.checksum,
            }),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: context.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummaryBar(BuildContext context) {
    final entry = widget.entry;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderSubtle, width: 0.8),
      ),
      child: Row(
        children: [
          AppBadge(
            label: ('audit_action_${entry.action}').i18n(),
            color: entry.action == AuditAction.delete
                ? AppColors.statusDanger
                : (entry.action == AuditAction.create
                    ? AppColors.primaryGreen
                    : AppColors.primaryBlue),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            DateFormat('MM/dd HH:mm').format(entry.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labels = [
      'audit_tab_visual_diff'.i18n(),
      'audit_tab_side_by_side'.i18n(),
      'audit_tab_revisions'.i18n(),
    ];

    return Row(
      children: List.generate(labels.length, (idx) {
        final selected = _selectedTab == idx;
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: idx < 2 ? 6 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = idx),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primaryBlue
                      : (isDark
                          ? AppColors.darkSurfaceMuted
                          : AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.primaryBlue
                        : context.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  labels[idx],
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? Colors.white : context.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSelectedTabBody(BuildContext context) {
    switch (_selectedTab) {
      case 1:
        return _buildSideBySideTab(context);
      case 2:
        return _buildRevisionCompareTab(context);
      case 0:
      default:
        return _buildVisualDiffList(context, widget.entry.diffs);
    }
  }

  Widget _buildVisualDiffList(BuildContext context, List<FieldDiff> diffs) {
    if (diffs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: EmptyStateView(
          icon: Icons.compare_arrows_rounded,
          title: 'audit_diff_no_changes'.i18n(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: diffs.map((diff) => _buildDiffTile(context, diff)).toList(),
    );
  }

  Widget _buildDiffTile(BuildContext context, FieldDiff diff) {
    final badgeColor = _diffColor(diff.changeType);
    final fieldTitle = _translateFieldName(diff.fieldKey);
    final oldStr = _formatRawVal(diff.oldValue);
    final newStr = _formatRawVal(diff.newValue);
    final delta = diff.numericDelta;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  fieldTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              if (delta != null && delta.abs() > 0.0001) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  margin: const EdgeInsetsDirectional.only(end: 6),
                  decoration: BoxDecoration(
                    color: (delta >= 0
                            ? AppColors.primaryGreen
                            : AppColors.statusDanger)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${delta >= 0 ? '+' : ''}${_formatRawVal(delta)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: delta >= 0
                          ? AppColors.primaryGreen
                          : AppColors.statusDanger,
                    ),
                  ),
                ),
              ],
              AppBadge(
                label: _diffBadgeLabel(diff.changeType),
                color: badgeColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (diff.changeType == DiffChangeType.modified)
            Row(
              children: [
                Expanded(
                  child: _buildValueBox(
                    context,
                    label: 'audit_diff_before_label'.i18n(),
                    value: oldStr,
                    color: AppColors.statusDanger,
                    strikethrough: true,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                ),
                Expanded(
                  child: _buildValueBox(
                    context,
                    label: 'audit_diff_after_label'.i18n(),
                    value: newStr,
                    color: AppColors.primaryGreen,
                    strikethrough: false,
                  ),
                ),
              ],
            )
          else if (diff.changeType == DiffChangeType.added)
            _buildValueBox(
              context,
              label: 'audit_diff_after_label'.i18n(),
              value: '+ $newStr',
              color: AppColors.primaryGreen,
              strikethrough: false,
            )
          else
            _buildValueBox(
              context,
              label: 'audit_diff_before_label'.i18n(),
              value: '− $oldStr',
              color: AppColors.statusDanger,
              strikethrough: true,
            ),
        ],
      ),
    );
  }

  Widget _buildValueBox(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required bool strikethrough,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withValues(alpha: 0.22), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: strikethrough ? TextDecoration.lineThrough : null,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideBySideTab(BuildContext context) {
    final before = widget.entry.beforeMap ?? const <String, dynamic>{};
    final after = widget.entry.afterMap ?? const <String, dynamic>{};
    final diffKeys = widget.entry.diffs.map((d) => d.fieldKey).toSet();
    final allKeys = <String>{...before.keys, ...after.keys}.toList()..sort();
    final visibleKeys = _changesOnlySideBySide
        ? allKeys.where(diffKeys.contains).toList()
        : allKeys;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSwitchTile(
          title: 'audit_diff_changes_only'.i18n(),
          value: _changesOnlySideBySide,
          onChanged: (v) => setState(() => _changesOnlySideBySide = v),
        ),
        const SizedBox(height: 8),
        if (visibleKeys.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: EmptyStateView(
              icon: Icons.table_rows_outlined,
              title: 'audit_diff_no_changes'.i18n(),
            ),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'audit_diff_before_label'.i18n(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusDanger,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'audit_diff_after_label'.i18n(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...visibleKeys.map((key) {
            final isChanged = diffKeys.contains(key);
            final oldStr = _formatRawVal(before[key]);
            final newStr = _formatRawVal(after[key]);
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: isChanged
                    ? AppColors.primaryBlue.withValues(alpha: 0.05)
                    : context.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isChanged
                      ? AppColors.primaryBlue.withValues(alpha: 0.25)
                      : context.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _translateFieldName(key),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          oldStr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isChanged
                                ? AppColors.statusDanger
                                : context.textSecondary,
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 13),
                      ),
                      Expanded(
                        child: Text(
                          newStr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isChanged
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isChanged
                                ? AppColors.primaryGreen
                                : context.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildRevisionCompareTab(BuildContext context) {
    if (_loadingHistory) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_history.length < 2) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: EmptyStateView(
          icon: Icons.history_toggle_off_rounded,
          title: 'audit_rev_single_hint'.i18n(),
        ),
      );
    }

    final older = _history.firstWhere(
      (e) => e.id == _olderEntryId,
      orElse: () => _history.first,
    );
    final newer = _history.firstWhere(
      (e) => e.id == _newerEntryId,
      orElse: () => _history.last,
    );

    final olderSnap = older.afterMap ?? older.beforeMap ?? const <String, dynamic>{};
    final newerSnap = newer.afterMap ?? newer.beforeMap ?? const <String, dynamic>{};
    final cumulativeDiffs = AuditDiffEngine.compareSnapshots(olderSnap, newerSnap);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppDropdownField<String>(
                label: 'audit_rev_older_label'.i18n(),
                value: older.id,
                items: _history
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '#${e.sequenceNo} (${DateFormat('MM/dd HH:mm').format(e.createdAt)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _olderEntryId = val),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: AppDropdownField<String>(
                label: 'audit_rev_newer_label'.i18n(),
                value: newer.id,
                items: _history
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.id,
                        child: Text(
                          '#${e.sequenceNo} (${DateFormat('MM/dd HH:mm').format(e.createdAt)})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _newerEntryId = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildVisualDiffList(context, cumulativeDiffs),
      ],
    );
  }
}
