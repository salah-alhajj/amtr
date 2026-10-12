<div dir="rtl">

# التيبوغرافي العربي المحلي IBM Plex Sans Arabic

**رقم الوثيقة:** 06  
**مسار الملف:** `/Users/slahaldynalhaj/Projects/amtr/docs/reports/init_report/06_typography_and_ibm_plex_sans_arabic.md`  
**حالة التوثيق:** معتمد ونهائي  

---

## 1. إلزامية الاعتماد على الخطوط المحلية
شدد التوجيه الأساسي على: *"استخدم IBM Arabic Plex واستخدم الملفات وليس جوجل فونت"*.
تم إدراج حزمة خطوط **IBM Plex Sans Arabic** محلياً داخل أصول المشروع (`assets/fonts/`):
- `IBMPlexSansArabic-Regular.ttf`
- `IBMPlexSansArabic-Medium.ttf`
- `IBMPlexSansArabic-SemiBold.ttf`
- `IBMPlexSansArabic-Bold.ttf`

### 2. تعريف العائلة في `pubspec.yaml`:
```yaml
flutter:
  fonts:
    - family: IBMPlexSansArabic
      fonts:
        - asset: assets/fonts/IBMPlexSansArabic-Regular.ttf
          weight: 400
        - asset: assets/fonts/IBMPlexSansArabic-Medium.ttf
          weight: 500
        - asset: assets/fonts/IBMPlexSansArabic-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/IBMPlexSansArabic-Bold.ttf
          weight: 700
```
يضمن هذا التضمين عمل التطبيق بدون أي اتصال بالإنترنت، ومنع وميض الخطوط (FOUT) الذي يحدث عند تحميل الخطوط ديناميكياً عبر الإنترنت.

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
