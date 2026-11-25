import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../services/data_sync_bus.dart';
import '../data/audit_repository.dart';
import '../domain/audit_diff_engine.dart';

/// خدمة التدقيق المركزي الموحدة لكافة عمليات النظام
class CentralAuditService {
  CentralAuditService._internal();
  static final CentralAuditService instance = CentralAuditService._internal();

  AuditRepository _repo = AuditRepositoryImpl();
  bool enabled = true;

  AuditRepository get repository => _repo;

  void overrideRepositoryForTesting(AuditRepository? repo) {
    _repo = repo ?? AuditRepositoryImpl();
  }

  /// تسجيل حدث تدقيق مع حساب الفوارق التلقائي بين قبل وبعد
  Future<void> log({
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  }) async {
    if (!enabled) return;
    final diffs = AuditDiffEngine.computeDiff(before, after);
    await _repo.recordEntry(
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      action: action,
      summary: summary,
      beforeJson: before != null ? jsonEncode(before) : null,
      afterJson: after != null ? jsonEncode(after) : null,
      diffJson: jsonEncode(diffs.map((d) => d.toMap()).toList()),
      changedFieldsCount: diffs.length,
      financialImpactYer: financialImpactYer,
      currency: currency,
      actorLabel: actorLabel,
      sourceModule: sourceModule,
    );
    DataSyncBus.instance.notify(DataDomain.audit);
  }

  /// تسجيل حدث تدقيق ذرياً داخل معاملة SQLite نفسها لضمان التطابق الكامل
  Future<void> logInTxn(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  }) async {
    if (!enabled) return;
    final diffs = AuditDiffEngine.computeDiff(before, after);
    await _repo.recordInTransaction(
      txn,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      action: action,
      summary: summary,
      beforeJson: before != null ? jsonEncode(before) : null,
      afterJson: after != null ? jsonEncode(after) : null,
      diffJson: jsonEncode(diffs.map((d) => d.toMap()).toList()),
      changedFieldsCount: diffs.length,
      financialImpactYer: financialImpactYer,
      currency: currency,
      actorLabel: actorLabel,
      sourceModule: sourceModule,
    );
  }

  /// إطلاق إشعار التحديث بعد اكتمال المعاملة في قاعدة البيانات
  void notifyAuditChanged() {
    if (enabled) {
      DataSyncBus.instance.notify(DataDomain.audit);
    }
  }
}
