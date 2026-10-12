import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/localization/localization.dart';
import 'package:amtr/core/widgets/design_system.dart';

void main() {
  setUpAll(() {
    LocalizationHelper.setStrings({
      'toast_title_success': 'تمت العملية بنجاح',
      'toast_title_error': 'خطأ في العملية',
      'toast_title_warning': 'تنبيه هام',
      'toast_title_info': 'معلومات',
      'photo_attach_button': 'إرفاق صور',
      'photo_attach_title': 'إرفاق الصور والمستندات',
      'photo_add_more': 'إضافة صور',
      'item_photos_attached': '{count} صور مرفقة',
      'common_cancel': 'إلغاء',
    }, 'ar');
  });

  group('AppToast Unified In-App Notification System Tests', () {
    testWidgets('AppToast renders success notification properly in overlay', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AppToast.showSuccess(
                    context,
                    'تم حفظ البيانات بنجاح',
                    actionLabel: 'تراجع',
                    onAction: () {},
                  );
                },
                child: const Text('Show Success'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Success'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('تمت العملية بنجاح'), findsOneWidget);
      expect(find.text('تم حفظ البيانات بنجاح'), findsOneWidget);
      expect(find.text('تراجع'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle();
    });

    testWidgets('AppToast renders error and warning types with correct icons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppToast.showError(context, 'فشل الاتصال بالخادم'),
                    child: const Text('Show Error'),
                  ),
                  ElevatedButton(
                    onPressed: () => AppToast.showWarning(context, 'يرجى مراجعة الرصيد'),
                    child: const Text('Show Warning'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // اختبار الخطأ
      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('فشل الاتصال بالخادم'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle();

      // اختبار التحذير
      await tester.tap(find.text('Show Warning'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('يرجى مراجعة الرصيد'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);

      AppToast.dismiss();
      await tester.pumpAndSettle();
    });
  });

  group('AppPhotoAttachment Unified Component Tests', () {
    testWidgets('AppPhotoAttachButton displays count and label correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AppPhotoAttachButton(
                onPressed: () {},
                photosCount: 3,
                isCompact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('إرفاق صور'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
    });

    testWidgets('AppPhotoAttachmentSection renders in compact and readOnly modes', (tester) async {
      final samplePhotos = ['/path/to/dummy1.jpg', '/path/to/dummy2.jpg'];
      List<String> currentPhotos = List.from(samplePhotos);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppPhotoAttachmentSection(
              photos: currentPhotos,
              compact: true,
              readOnly: true,
              onPhotosChanged: (newList) => currentPhotos = newList,
            ),
          ),
        ),
      );

      expect(find.text('2 صور مرفقة'), findsOneWidget);
      expect(find.byType(AppPhotoThumbnail), findsNWidgets(2));
      // في وضع القراءة فقط، لا يظهر زر الحذف
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
