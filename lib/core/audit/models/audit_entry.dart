import 'dart:convert';

/// أنواع العمليات المسجلة في سجل التدقيق المركزي
abstract class AuditAction {
  static const String create = 'create';
  static const String update = 'update';
  static const String delete = 'delete';
  static const String payment = 'payment';
  static const String statusChange = 'status_change';
  static const String stockAdjust = 'stock_adjust';
  static const String settlement = 'settlement';
  static const String closing = 'closing';
  static const String rateUpdate = 'rate_update';
  static const String backupExport = 'backup_export';
  static const String backupRestore = 'backup_restore';

  static const List<String> all = [
    create,
    update,
    delete,
    payment,
    statusChange,
    stockAdjust,
    settlement,
    closing,
    rateUpdate,
    backupExport,
    backupRestore,
  ];
}

/// أنواع الكيانات الخاضعة للتدقيق في المنظومة
abstract class AuditEntityType {
  static const String order = 'order';
  static const String payment = 'payment';
  static const String product = 'product';
  static const String customer = 'customer';
  static const String expense = 'expense';
  static const String supplier = 'supplier';
  static const String supplierTx = 'supplier_tx';
  static const String shipment = 'shipment';
  static const String courier = 'courier';
  static const String courierSettlement = 'courier_settlement';
  static const String material = 'material';
  static const String productionBatch = 'production_batch';
  static const String wasteLog = 'waste_log';
  static const String dailyClosing = 'daily_closing';
  static const String exchangeRate = 'exchange_rate';
  static const String backup = 'backup';

  static const List<String> all = [
    order,
    payment,
    product,
    customer,
    expense,
    supplier,
    supplierTx,
    shipment,
    courier,
    courierSettlement,
    material,
    productionBatch,
    wasteLog,
    dailyClosing,
    exchangeRate,
    backup,
  ];
}

/// نوع التغيير على مستوى الحقل الواحد
enum DiffChangeType { added, removed, modified }

/// يمثل فارقاً واحداً بين قيمة قبل التعديل وقيمة بعد التعديل
class FieldDiff {
  final String fieldKey;
  final DiffChangeType changeType;
  final dynamic oldValue;
  final dynamic newValue;
  final double? numericDelta;

  const FieldDiff({
    required this.fieldKey,
    required this.changeType,
    this.oldValue,
    this.newValue,
    this.numericDelta,
  });

  Map<String, dynamic> toMap() {
    return {
      'fieldKey': fieldKey,
      'changeType': changeType.name,
      'oldValue': oldValue,
      'newValue': newValue,
      'numericDelta': numericDelta,
    };
  }

  factory FieldDiff.fromMap(Map<String, dynamic> map) {
    final typeName = (map['changeType'] as String?) ?? 'modified';
    final changeType = DiffChangeType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => DiffChangeType.modified,
    );
    return FieldDiff(
      fieldKey: (map['fieldKey'] as String?) ?? '',
      changeType: changeType,
      oldValue: map['oldValue'],
      newValue: map['newValue'],
      numericDelta: (map['numericDelta'] as num?)?.toDouble(),
    );
  }
}

/// قيد تدقيق مركزي غير قابل للتعديل مع بصمة ترابطية وسجل قبل/بعد
class AuditEntry {
  final String id;
  final int sequenceNo;
  final String entityType;
  final String entityId;
  final String entityLabel;
  final String action;
  final String summary;
  final String? beforeJson;
  final String? afterJson;
  final String diffJson;
  final int changedFieldsCount;
  final double financialImpactYer;
  final String? currency;
  final String actorLabel;
  final String sourceModule;
  final String checksum;
  final DateTime createdAt;

  const AuditEntry({
    required this.id,
    required this.sequenceNo,
    required this.entityType,
    required this.entityId,
    required this.entityLabel,
    required this.action,
    required this.summary,
    this.beforeJson,
    this.afterJson,
    required this.diffJson,
    this.changedFieldsCount = 0,
    this.financialImpactYer = 0.0,
    this.currency,
    this.actorLabel = 'owner',
    this.sourceModule = 'app',
    required this.checksum,
    required this.createdAt,
  });

  Map<String, dynamic>? get beforeMap => _decodeJsonMap(beforeJson);
  Map<String, dynamic>? get afterMap => _decodeJsonMap(afterJson);

  List<FieldDiff> get diffs {
    if (diffJson.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(diffJson);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((m) => FieldDiff.fromMap(Map<String, dynamic>.from(m)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static Map<String, dynamic>? _decodeJsonMap(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sequenceNo': sequenceNo,
      'entityType': entityType,
      'entityId': entityId,
      'entityLabel': entityLabel,
      'action': action,
      'summary': summary,
      'beforeJson': beforeJson,
      'afterJson': afterJson,
      'diffJson': diffJson,
      'changedFieldsCount': changedFieldsCount,
      'financialImpactYer': financialImpactYer,
      'currency': currency,
      'actorLabel': actorLabel,
      'sourceModule': sourceModule,
      'checksum': checksum,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AuditEntry.fromMap(Map<String, dynamic> map) {
    return AuditEntry(
      id: (map['id'] as String?) ?? '',
      sequenceNo: (map['sequenceNo'] as num?)?.toInt() ?? 0,
      entityType: (map['entityType'] as String?) ?? '',
      entityId: (map['entityId'] as String?) ?? '',
      entityLabel: (map['entityLabel'] as String?) ?? '',
      action: (map['action'] as String?) ?? AuditAction.update,
      summary: (map['summary'] as String?) ?? '',
      beforeJson: map['beforeJson'] as String?,
      afterJson: map['afterJson'] as String?,
      diffJson: (map['diffJson'] as String?) ?? '[]',
      changedFieldsCount: (map['changedFieldsCount'] as num?)?.toInt() ?? 0,
      financialImpactYer:
          (map['financialImpactYer'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] as String?,
      actorLabel: (map['actorLabel'] as String?) ?? 'owner',
      sourceModule: (map['sourceModule'] as String?) ?? 'app',
      checksum: (map['checksum'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.now(),
    );
  }
}

/// تقرير التحقق من سلامة سلسلة التدقيق وكشف أي تلاعب بالسجلات
class AuditIntegrityReport {
  final int totalEntries;
  final int verifiedEntries;
  final List<String> tamperedEntryIds;

  const AuditIntegrityReport({
    required this.totalEntries,
    required this.verifiedEntries,
    this.tamperedEntryIds = const [],
  });

  bool get isIntact => tamperedEntryIds.isEmpty;
}

/// ملخص إحصائي لسجل التدقيق
class AuditStatsSummary {
  final int totalLogs;
  final int todayLogs;
  final int createCount;
  final int updateCount;
  final int deleteCount;
  final int financialCount;

  const AuditStatsSummary({
    this.totalLogs = 0,
    this.todayLogs = 0,
    this.createCount = 0,
    this.updateCount = 0,
    this.deleteCount = 0,
    this.financialCount = 0,
  });
}
