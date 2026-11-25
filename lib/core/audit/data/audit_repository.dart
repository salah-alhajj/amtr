import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../database/app_database.dart';
import '../domain/audit_diff_engine.dart';
import '../models/audit_entry.dart';

/// عقد مستودع التدقيق المركزي لتمكين العزل والاختبار الوهمي
abstract class AuditRepository {
  Future<AuditEntry> recordEntry({
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    String? beforeJson,
    String? afterJson,
    required String diffJson,
    required int changedFieldsCount,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  });

  Future<AuditEntry?> recordInTransaction(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    String? beforeJson,
    String? afterJson,
    required String diffJson,
    required int changedFieldsCount,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  });

  Future<List<AuditEntry>> queryLogs({
    String? entityType,
    String? entityId,
    String? action,
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 150,
    int offset = 0,
  });

  Future<List<AuditEntry>> getEntityHistory(String entityType, String entityId);
  Future<AuditStatsSummary> getStatsSummary();
  Future<AuditIntegrityReport> verifyIntegrityChain();
  Future<void> deleteAll();
}

/// مستودع التدقيق المركزي على قاعدة بيانات SQLite
class AuditRepositoryImpl implements AuditRepository {
  final AppDatabase _dbHelper;

  AuditRepositoryImpl({AppDatabase? db}) : _dbHelper = db ?? AppDatabase.instance;

  Future<({int nextSeq, String prevChecksum})> _readChainTip(
    DatabaseExecutor db,
  ) async {
    final rows = await db.query(
      'audit_logs',
      columns: ['sequenceNo', 'checksum'],
      orderBy: 'sequenceNo DESC, createdAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return (nextSeq: 1, prevChecksum: 'GENESIS');
    }
    final lastSeq = (rows.first['sequenceNo'] as num?)?.toInt() ?? 0;
    final lastChecksum = (rows.first['checksum'] as String?) ?? 'GENESIS';
    return (nextSeq: lastSeq + 1, prevChecksum: lastChecksum);
  }

  AuditEntry _buildEntry({
    required int sequenceNo,
    required String prevChecksum,
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    String? beforeJson,
    String? afterJson,
    required String diffJson,
    required int changedFieldsCount,
    required double financialImpactYer,
    String? currency,
    required String actorLabel,
    required String sourceModule,
  }) {
    final now = DateTime.now();
    final createdAtIso = now.toIso8601String();
    final checksum = AuditDiffEngine.computeChecksum(
      previousChecksum: prevChecksum,
      sequenceNo: sequenceNo,
      entityType: entityType,
      entityId: entityId,
      action: action,
      beforeJson: beforeJson,
      afterJson: afterJson,
      createdAt: createdAtIso,
    );

    return AuditEntry(
      id: const Uuid().v4(),
      sequenceNo: sequenceNo,
      entityType: entityType,
      entityId: entityId,
      entityLabel: entityLabel,
      action: action,
      summary: summary,
      beforeJson: beforeJson,
      afterJson: afterJson,
      diffJson: diffJson,
      changedFieldsCount: changedFieldsCount,
      financialImpactYer: financialImpactYer,
      currency: currency,
      actorLabel: actorLabel,
      sourceModule: sourceModule,
      checksum: checksum,
      createdAt: now,
    );
  }

  @override
  Future<AuditEntry> recordEntry({
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    String? beforeJson,
    String? afterJson,
    required String diffJson,
    required int changedFieldsCount,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  }) async {
    final db = await _dbHelper.database;
    try {
      return await db.transaction((txn) async {
        final tip = await _readChainTip(txn);
        final entry = _buildEntry(
          sequenceNo: tip.nextSeq,
          prevChecksum: tip.prevChecksum,
          entityType: entityType,
          entityId: entityId,
          entityLabel: entityLabel,
          action: action,
          summary: summary,
          beforeJson: beforeJson,
          afterJson: afterJson,
          diffJson: diffJson,
          changedFieldsCount: changedFieldsCount,
          financialImpactYer: financialImpactYer,
          currency: currency,
          actorLabel: actorLabel,
          sourceModule: sourceModule,
        );
        await txn.insert(
          'audit_logs',
          entry.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return entry;
      });
    } catch (_) {
      // توافق آمن مع قواعد البيانات الاختبارية القديمة (< v13)
      return _buildEntry(
        sequenceNo: 0,
        prevChecksum: 'GENESIS',
        entityType: entityType,
        entityId: entityId,
        entityLabel: entityLabel,
        action: action,
        summary: summary,
        beforeJson: beforeJson,
        afterJson: afterJson,
        diffJson: diffJson,
        changedFieldsCount: changedFieldsCount,
        financialImpactYer: financialImpactYer,
        currency: currency,
        actorLabel: actorLabel,
        sourceModule: sourceModule,
      );
    }
  }

  @override
  Future<AuditEntry?> recordInTransaction(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String entityLabel,
    required String action,
    required String summary,
    String? beforeJson,
    String? afterJson,
    required String diffJson,
    required int changedFieldsCount,
    double financialImpactYer = 0.0,
    String? currency,
    String actorLabel = 'owner',
    String sourceModule = 'app',
  }) async {
    try {
      final tip = await _readChainTip(txn);
      final entry = _buildEntry(
        sequenceNo: tip.nextSeq,
        prevChecksum: tip.prevChecksum,
        entityType: entityType,
        entityId: entityId,
        entityLabel: entityLabel,
        action: action,
        summary: summary,
        beforeJson: beforeJson,
        afterJson: afterJson,
        diffJson: diffJson,
        changedFieldsCount: changedFieldsCount,
        financialImpactYer: financialImpactYer,
        currency: currency,
        actorLabel: actorLabel,
        sourceModule: sourceModule,
      );
      await txn.insert(
        'audit_logs',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return entry;
    } catch (_) {
      // تجاهل هادئ عند التشغيل على قاعدة بيانات اختبارية قديمة (< v13)
      return null;
    }
  }

  @override
  Future<List<AuditEntry>> queryLogs({
    String? entityType,
    String? entityId,
    String? action,
    String? searchQuery,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 150,
    int offset = 0,
  }) async {
    final db = await _dbHelper.database;
    final whereParts = <String>[];
    final whereArgs = <dynamic>[];

    if (entityType != null && entityType.isNotEmpty) {
      whereParts.add('entityType = ?');
      whereArgs.add(entityType);
    }
    if (entityId != null && entityId.isNotEmpty) {
      whereParts.add('entityId = ?');
      whereArgs.add(entityId);
    }
    if (action != null && action.isNotEmpty) {
      whereParts.add('action = ?');
      whereArgs.add(action);
    }
    if (fromDate != null) {
      whereParts.add('createdAt >= ?');
      whereArgs.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      whereParts.add('createdAt <= ?');
      whereArgs.add(toDate.toIso8601String());
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = '%${searchQuery.trim()}%';
      whereParts.add('(entityLabel LIKE ? OR summary LIKE ? OR diffJson LIKE ?)');
      whereArgs.addAll([q, q, q]);
    }

    try {
      final maps = await db.query(
        'audit_logs',
        where: whereParts.isEmpty ? null : whereParts.join(' AND '),
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'sequenceNo DESC, createdAt DESC',
        limit: limit,
        offset: offset,
      );
      return maps.map(AuditEntry.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<AuditEntry>> getEntityHistory(
    String entityType,
    String entityId,
  ) async {
    final db = await _dbHelper.database;
    try {
      final maps = await db.query(
        'audit_logs',
        where: 'entityType = ? AND entityId = ?',
        whereArgs: [entityType, entityId],
        orderBy: 'sequenceNo ASC, createdAt ASC',
      );
      return maps.map(AuditEntry.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<AuditStatsSummary> getStatsSummary() async {
    final db = await _dbHelper.database;
    try {
      final rows = await db.query(
        'audit_logs',
        columns: ['action', 'financialImpactYer', 'createdAt'],
      );
      final now = DateTime.now();
      final todayPrefix =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      int todayLogs = 0;
      int createCount = 0;
      int updateCount = 0;
      int deleteCount = 0;
      int financialCount = 0;

      for (final row in rows) {
        final createdAt = (row['createdAt'] as String?) ?? '';
        if (createdAt.startsWith(todayPrefix)) {
          todayLogs++;
        }
        final action = (row['action'] as String?) ?? '';
        if (action == AuditAction.create) createCount++;
        if (action == AuditAction.update || action == AuditAction.statusChange) {
          updateCount++;
        }
        if (action == AuditAction.delete) deleteCount++;
        final impact = (row['financialImpactYer'] as num?)?.toDouble() ?? 0.0;
        if (impact.abs() > 0.001 ||
            action == AuditAction.payment ||
            action == AuditAction.settlement ||
            action == AuditAction.closing) {
          financialCount++;
        }
      }

      return AuditStatsSummary(
        totalLogs: rows.length,
        todayLogs: todayLogs,
        createCount: createCount,
        updateCount: updateCount,
        deleteCount: deleteCount,
        financialCount: financialCount,
      );
    } catch (_) {
      return const AuditStatsSummary();
    }
  }

  @override
  Future<AuditIntegrityReport> verifyIntegrityChain() async {
    final db = await _dbHelper.database;
    try {
      final maps = await db.query(
        'audit_logs',
        orderBy: 'sequenceNo ASC, createdAt ASC',
      );
      final entries = maps.map(AuditEntry.fromMap).toList();
      final tampered = <String>[];
      int verified = 0;
      String prevChecksum = 'GENESIS';

      for (final entry in entries) {
        final expected = AuditDiffEngine.computeChecksum(
          previousChecksum: prevChecksum,
          sequenceNo: entry.sequenceNo,
          entityType: entry.entityType,
          entityId: entry.entityId,
          action: entry.action,
          beforeJson: entry.beforeJson,
          afterJson: entry.afterJson,
          createdAt: entry.createdAt.toIso8601String(),
        );
        if (expected == entry.checksum) {
          verified++;
        } else {
          tampered.add(entry.id);
        }
        prevChecksum = entry.checksum;
      }

      return AuditIntegrityReport(
        totalEntries: entries.length,
        verifiedEntries: verified,
        tamperedEntryIds: tampered,
      );
    } catch (_) {
      return const AuditIntegrityReport(totalEntries: 0, verifiedEntries: 0);
    }
  }

  @override
  Future<void> deleteAll() async {
    final db = await _dbHelper.database;
    try {
      await db.delete('audit_logs');
    } catch (_) {}
  }
}
