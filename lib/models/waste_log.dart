import '../core/constants.dart';

/// نموذج سجل الهدر والتالف لمنتج جاهز أو مادة خام (Waste Log)
class WasteLog {
  final String id;
  final String itemType; // 'product' | 'material'
  final String itemId;
  final String itemName;
  final double quantity;
  final String unit;
  final double estimatedLossYer;
  final String reason;
  final String? notes;
  final DateTime loggedAt;

  WasteLog({
    required this.id,
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    this.unit = 'حبة',
    required this.estimatedLossYer,
    this.reason = AppConstants.wasteReasonSpoiled,
    this.notes,
    DateTime? loggedAt,
  }) : loggedAt = loggedAt ?? DateTime.now();

  bool get isProduct => itemType == 'product';
  bool get isMaterial => itemType == 'material';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemType': itemType,
      'itemId': itemId,
      'itemName': itemName,
      'quantity': quantity,
      'unit': unit,
      'estimatedLossYer': estimatedLossYer,
      'reason': reason,
      'notes': notes,
      'loggedAt': loggedAt.toIso8601String(),
    };
  }

  factory WasteLog.fromMap(Map<String, dynamic> map) {
    return WasteLog(
      id: map['id'] as String,
      itemType: (map['itemType'] as String?) ?? 'product',
      itemId: map['itemId'] as String,
      itemName: (map['itemName'] as String?) ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      unit: (map['unit'] as String?) ?? 'حبة',
      estimatedLossYer: (map['estimatedLossYer'] as num?)?.toDouble() ?? 0.0,
      reason: (map['reason'] as String?) ?? AppConstants.wasteReasonSpoiled,
      notes: map['notes'] as String?,
      loggedAt: map['loggedAt'] != null
          ? DateTime.parse(map['loggedAt'] as String)
          : DateTime.now(),
    );
  }

  WasteLog copyWith({
    String? id,
    String? itemType,
    String? itemId,
    String? itemName,
    double? quantity,
    String? unit,
    double? estimatedLossYer,
    String? reason,
    String? notes,
    DateTime? loggedAt,
  }) {
    return WasteLog(
      id: id ?? this.id,
      itemType: itemType ?? this.itemType,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      estimatedLossYer: estimatedLossYer ?? this.estimatedLossYer,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
