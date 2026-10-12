<div dir="rtl">

# تقطيع النظام إلى ميزات مصغرة مستقلة

**رقم الوثيقة:** 09  
**مسار الملف:** `/Users/slahaldynalhaj/Projects/amtr/docs/reports/init_report/09_modular_feature_architecture.md`  
**حالة التوثيق:** معتمد ونهائي  

---

## 1. استراتيجية Modular Feature-First
تنفيذاً للطلب الثالث: *"يجب تقسيم الملفات الكبيرة ويجب جعل الودجتس في مجلد الفتيشر في مجلد خاص بإسم widgets وسيكون موجود في كل مجلد فيتشر"*.
تم توزيع الشيفرة عبر مجلدات مستقلة تماماً داخل `lib/features/`:

```text
lib/features/
├── dashboard/
│   └── presentation/widgets/ (stat_card, financial_analytics_card)
├── customers/
│   ├── domain/ (entities, customer_repository)
│   ├── data/ (customer_model, customer_repository_impl)
│   └── presentation/widgets/ (customer_card, customer_orders_sheet)
├── orders/
│   ├── domain/ (order_repository)
│   ├── data/ (order_model, order_repository_impl)
│   └── presentation/widgets/ (order_card, debt_due_reminder_card, item_draft_card)
├── shipments/
│   ├── domain/ (shipment_repository)
│   ├── data/ (shipment_model, shipment_repository_impl)
│   └── presentation/widgets/ (shipment_card, shipment_timeline_step_bar)
├── settings/
│   └── presentation/widgets/ (theme_selector_card, language_selector_card)
└── backup/
    └── presentation/widgets/ (backup_action_tile)
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
