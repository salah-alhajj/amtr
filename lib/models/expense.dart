import '../core/constants.dart';

/// نموذج مصروف تشغيلي أو مشتريات عامة (مواد خام، تغليف، توصيل، تسويق...)
class Expense {
  final String id;
  final String title;
  final String category;
  final String expenseType; // business | personal
  final double amount;
  final String currency;
  final DateTime expenseDate;
  final String? notes;
  final String recurrence; // once | daily | weekly | monthly
  final bool isPettyCash;
  final String? supplierId;
  final String? receiptPhotoPath;
  final String? parentRuleId;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.title,
    this.category = 'exp_cat_materials',
    this.expenseType = AppConstants.expenseTypeBusiness,
    required this.amount,
    this.currency = AppConstants.currencyYer,
    DateTime? expenseDate,
    this.notes,
    this.recurrence = AppConstants.expenseRecurrenceOnce,
    this.isPettyCash = false,
    this.supplierId,
    this.receiptPhotoPath,
    this.parentRuleId,
    DateTime? createdAt,
  })  : expenseDate = expenseDate ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  /// هل المصروف سحب شخصي / مصروف بيت (لا ينقص ربح المشروع)؟
  bool get isPersonalDrawing => expenseType == AppConstants.expenseTypePersonal;

  /// هل المصروف دوري (يومي / أسبوعي / شهري)؟
  bool get isRecurring => recurrence != AppConstants.expenseRecurrenceOnce;

  /// المكافئ الشهري التقريبي للمصروف الدوري
  double get monthlyEquivalentAmount {
    switch (recurrence) {
      case AppConstants.expenseRecurrenceDaily:
        return amount * 30.0;
      case AppConstants.expenseRecurrenceWeekly:
        return amount * 4.0;
      case AppConstants.expenseRecurrenceMonthly:
        return amount;
      default:
        return 0.0;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'expenseType': expenseType,
      'amount': amount,
      'currency': currency,
      'expenseDate': expenseDate.toIso8601String(),
      'notes': notes,
      'recurrence': recurrence,
      'isPettyCash': isPettyCash ? 1 : 0,
      'supplierId': supplierId,
      'receiptPhotoPath': receiptPhotoPath,
      'parentRuleId': parentRuleId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      category: (map['category'] as String?) ?? 'exp_cat_materials',
      expenseType:
          (map['expenseType'] as String?) ?? AppConstants.expenseTypeBusiness,
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?) ?? AppConstants.currencyYer,
      expenseDate: map['expenseDate'] != null
          ? DateTime.parse(map['expenseDate'] as String)
          : DateTime.now(),
      notes: map['notes'] as String?,
      recurrence:
          (map['recurrence'] as String?) ?? AppConstants.expenseRecurrenceOnce,
      isPettyCash: (map['isPettyCash'] as num?)?.toInt() == 1,
      supplierId: map['supplierId'] as String?,
      receiptPhotoPath: map['receiptPhotoPath'] as String?,
      parentRuleId: map['parentRuleId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Expense copyWith({
    String? id,
    String? title,
    String? category,
    String? expenseType,
    double? amount,
    String? currency,
    DateTime? expenseDate,
    String? notes,
    String? recurrence,
    bool? isPettyCash,
    String? supplierId,
    bool clearSupplierId = false,
    String? receiptPhotoPath,
    bool clearReceiptPhotoPath = false,
    String? parentRuleId,
    bool clearParentRuleId = false,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      expenseType: expenseType ?? this.expenseType,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      expenseDate: expenseDate ?? this.expenseDate,
      notes: notes ?? this.notes,
      recurrence: recurrence ?? this.recurrence,
      isPettyCash: isPettyCash ?? this.isPettyCash,
      supplierId: clearSupplierId ? null : (supplierId ?? this.supplierId),
      receiptPhotoPath: clearReceiptPhotoPath
          ? null
          : (receiptPhotoPath ?? this.receiptPhotoPath),
      parentRuleId:
          clearParentRuleId ? null : (parentRuleId ?? this.parentRuleId),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
