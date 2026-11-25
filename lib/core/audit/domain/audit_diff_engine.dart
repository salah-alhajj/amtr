import 'dart:convert';
import '../models/audit_entry.dart';

/// محرك نقي لحساب الفوارق الحقلية وبصمات التكامل الترابطية بدون أي اعتماد على واجهات المستخدم
class AuditDiffEngine {
  const AuditDiffEngine._();

  static const Set<String> _noiseKeys = {'createdAt', 'updatedAt'};

  /// حساب قائمة الفوارق الدقيقة بين لقطتي (قبل) و(بعد)
  static List<FieldDiff> computeDiff(
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  ) {
    final beforeMap = before ?? const <String, dynamic>{};
    final afterMap = after ?? const <String, dynamic>{};

    final keys = <String>{...beforeMap.keys, ...afterMap.keys}.toList()..sort();
    final List<FieldDiff> diffs = [];

    for (final key in keys) {
      final hasBefore = beforeMap.containsKey(key);
      final hasAfter = afterMap.containsKey(key);
      final oldVal = beforeMap[key];
      final newVal = afterMap[key];

      if (before == null && hasAfter) {
        if (_isEmptyValue(newVal)) continue;
        diffs.add(
          FieldDiff(
            fieldKey: key,
            changeType: DiffChangeType.added,
            oldValue: null,
            newValue: newVal,
            numericDelta: _asDouble(newVal),
          ),
        );
        continue;
      }

      if (after == null && hasBefore) {
        if (_isEmptyValue(oldVal)) continue;
        diffs.add(
          FieldDiff(
            fieldKey: key,
            changeType: DiffChangeType.removed,
            oldValue: oldVal,
            newValue: null,
            numericDelta: _asDouble(oldVal) != null ? -_asDouble(oldVal)! : null,
          ),
        );
        continue;
      }

      if (!hasBefore && hasAfter) {
        if (_isEmptyValue(newVal)) continue;
        diffs.add(
          FieldDiff(
            fieldKey: key,
            changeType: DiffChangeType.added,
            oldValue: null,
            newValue: newVal,
            numericDelta: _asDouble(newVal),
          ),
        );
        continue;
      }

      if (hasBefore && !hasAfter) {
        if (_isEmptyValue(oldVal)) continue;
        diffs.add(
          FieldDiff(
            fieldKey: key,
            changeType: DiffChangeType.removed,
            oldValue: oldVal,
            newValue: null,
            numericDelta: _asDouble(oldVal) != null ? -_asDouble(oldVal)! : null,
          ),
        );
        continue;
      }

      if (_valuesEqual(oldVal, newVal)) {
        continue;
      }
      if (_noiseKeys.contains(key) && _valuesEqual(oldVal, newVal)) {
        continue;
      }

      final oldNum = _asDouble(oldVal);
      final newNum = _asDouble(newVal);
      final double? delta =
          (oldNum != null && newNum != null) ? (newNum - oldNum) : null;

      diffs.add(
        FieldDiff(
          fieldKey: key,
          changeType: DiffChangeType.modified,
          oldValue: oldVal,
          newValue: newVal,
          numericDelta: delta,
        ),
      );
    }

    return diffs;
  }

  /// مقارنة نسختين تاريخيتين لنفس الكيان وإرجاع الفوارق التراكمية بين الأقدم والأحدث
  static List<FieldDiff> compareSnapshots(
    Map<String, dynamic>? older,
    Map<String, dynamic>? newer,
  ) {
    return computeDiff(older, newer);
  }

  /// حساب بصمة تكامل ترابطية (Chained 256-bit digest) لربط كل سجل بما قبله ومنع التلاعب
  static String computeChecksum({
    required String previousChecksum,
    required int sequenceNo,
    required String entityType,
    required String entityId,
    required String action,
    String? beforeJson,
    String? afterJson,
    required String createdAt,
  }) {
    final payload = [
      previousChecksum,
      sequenceNo.toString(),
      entityType,
      entityId,
      action,
      beforeJson ?? '',
      afterJson ?? '',
      createdAt,
    ].join('|');

    final bytes = utf8.encode(payload);
    // خلط رباعي المسارات بعرض 32-بت لإنتاج بصمة 256-بت حتمية
    final lanes = <int>[
      0x9e3779b1,
      0x85ebca77,
      0xc2b2ae3d,
      0x27d4eb2f,
      0x165667b1,
      0xd3a2646c,
      0xfd7046c5,
      0xb55a4f09,
    ];

    for (var i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      for (var j = 0; j < lanes.length; j++) {
        var h = lanes[j];
        h = (h ^ ((b + i * 31 + j * 17) & 0xffffffff)) & 0xffffffff;
        h = ((h * (0x45d9f3b + j * 2)) + 0x27d4eb2d) & 0xffffffff;
        h = ((h << 13) | (h >> 19)) & 0xffffffff;
        lanes[j] = (h ^ lanes[(j + 3) % lanes.length]) & 0xffffffff;
      }
    }

    // جولة نشر إضافية بين المسارات لضمان تأثير الفراشة (avalanche effect)
    for (var round = 0; round < 3; round++) {
      for (var j = 0; j < lanes.length; j++) {
        var h = lanes[j];
        h = (h ^ (h >> 15)) & 0xffffffff;
        h = (h * 0x2c1b3c6d) & 0xffffffff;
        h = (h ^ lanes[(j + 1) % lanes.length]) & 0xffffffff;
        lanes[j] = h;
      }
    }

    return lanes.map((v) => v.toRadixString(16).padLeft(8, '0')).join();
  }

  /// تنسيق القيمة بصورة مقروءة للمقارنة البصرية
  static String formatDisplayValue(dynamic value) {
    if (value == null) return '—';
    if (value is num) {
      if (value is int || value == value.roundToDouble()) {
        return value.toInt().toString();
      }
      return value.toStringAsFixed(2);
    }
    if (value is bool) return value ? '1' : '0';
    if (value is List) return '[${value.length}]';
    if (value is Map) return jsonEncode(value);
    final str = value.toString().trim();
    return str.isEmpty ? '—' : str;
  }

  /// إرجاع مفتاح الترجمة القياسي لاسم الحقل إن وُجد
  static String fieldLabelKey(String fieldKey) {
    return AuditFieldLabels.keyFor(fieldKey);
  }

  static bool _isEmptyValue(dynamic val) {
    if (val == null) return true;
    if (val is String && val.trim().isEmpty) return true;
    return false;
  }

  static double? _asDouble(dynamic val) {
    if (val is num) return val.toDouble();
    return null;
  }

  static bool _valuesEqual(dynamic a, dynamic b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a is num && b is num) {
      return (a.toDouble() - b.toDouble()).abs() < 0.0001;
    }
    if (a is List && b is List) {
      return jsonEncode(a) == jsonEncode(b);
    }
    if (a is Map && b is Map) {
      return jsonEncode(a) == jsonEncode(b);
    }
    return a.toString() == b.toString();
  }
}

/// ربط أسماء حقول قاعدة البيانات بمفاتيح الترجمة الواضحة للمستخدم
class AuditFieldLabels {
  const AuditFieldLabels._();

  static const Set<String> knownFields = {
    'name',
    'title',
    'sellPrice',
    'costPrice',
    'paidAmount',
    'totalSellPrice',
    'stockQuantity',
    'trackStock',
    'paymentStatus',
    'orderStatus',
    'customerName',
    'amount',
    'expenseType',
    'category',
    'discount',
    'deliveryFee',
    'notes',
    'phone',
    'whatsapp',
    'yieldCount',
    'batchStatus',
    'sarToYer',
    'usdToYer',
    'itemsCount',
    'currency',
    'type',
    'unit',
    'unitCost',
    'lowStockThreshold',
    'quantity',
    'netRemittedYer',
    'cashInYer',
    'businessExpensesYer',
    'personalDrawingsYer',
    'status',
    'carrierName',
    'transportCost',
    'courierStatus',
    'defaultFee',
  };

  static String keyFor(String fieldKey) {
    if (knownFields.contains(fieldKey)) {
      return 'audit_field_$fieldKey';
    }
    return fieldKey;
  }
}
