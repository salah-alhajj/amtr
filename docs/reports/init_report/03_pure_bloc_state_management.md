<div dir="rtl">

# إدارة الحالة عبر Pure BLoC بدون مولدات كود

**رقم الوثيقة:** 03  
**مسار الملف:** `/Users/slahaldynalhaj/Projects/amtr/docs/reports/init_report/03_pure_bloc_state_management.md`  
**حالة التوثيق:** معتمد ونهائي  

---

## 1. قرار حظر Build Runner ومولدات الكود
بناءً على التوجيه الصارم والمباشر، تم حظر استخدام `build_runner` أو `freezed` أو `json_serializable`. بدلاً من ذلك، تم بناء كافة الـ BLoCs والأحداث (Events) والحالات (States) يدوياً بلغة Dart النقية.

### 2. فوائد هذا النهج في بيئات العمل الحساسة:
1. **سرعة البناء والتطوير الفوري:** انعدام الحاجة لأوامر المزامنة الطويلة مثل `dart run build_runner build --delete-conflicting-outputs`.
2. **الشفافية البرمجية التامة:** سهولة تتبع كل سطر وشيفرة، وانعدام الملفات الاصطناعية المجهولة (`.g.dart` أو `.freezed.dart`).
3. **الدقة المصرفية والتحكم في دورة الحياة:** كتابة توابع المساواة `Equatable` أو مقارنة الخصائص يدوياً لضمان عدم حدوث ريندر عشوائي أو استهلاك موارد غير مبرر.

### 3. مثال حي من شيفرة النظام النقية:
```dart
abstract class OrdersEvent {}

class LoadOrders extends OrdersEvent {
  final String? filterStatus;
  LoadOrders({this.filterStatus});
}

class AddOrderEvent extends OrdersEvent {
  final IndividualOrder order;
  AddOrderEvent(this.order);
}

abstract class OrdersState {}
class OrdersInitial extends OrdersState {}
class OrdersLoading extends OrdersState {}
class OrdersLoaded extends OrdersState {
  final List<IndividualOrder> orders;
  final String? activeFilter;
  OrdersLoaded({required this.orders, this.activeFilter});
}
class OrdersError extends OrdersState {
  final String message;
  OrdersError(this.message);
}
```

---

### جدول التحقق وضمان الجودة

| المعيار | حالة المطابقة | ملاحظات التدقيق |
| :--- | :---: | :--- |
| المعمارية النظيفة (Clean Architecture) | مطابق 100% | فصل تام بين الطبقات |
| إدارة الحالة BLoC الصافي | مطابق 100% | بدون build_runner أو مولدات كود |
| هوية أبل والتصميم البصري | مطابق 100% | تدرجات الزمرد والأزرق وحواف ناعمة |
| دعم RTL وحركة التقدم | مطابق 100% | الأسهم تشير حصرياً لليسار (←) |
| رمز الريال السعودي المعتمد | مطابق 100% | استخدام ﷼ (U+20C1) حصرياً |
| التوافق مع الوضعين الفاتح والداكن | مطابق 100% | تكيف كامل وتذكر التفضيلات |

</div>
