import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/widgets/design_system.dart';
import 'package:amtr/core/theme/app_colors.dart';

void main() {
  group('Design System - Buttons', () {
    testWidgets('AppPrimaryButton renders and responds to tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppPrimaryButton(
                label: 'زر تجريبي',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('زر تجريبي'), findsOneWidget);
      await tester.tap(find.text('زر تجريبي'));
      await tester.pumpAndSettle();
      expect(tapped, isTrue);
    });

    testWidgets('AppPrimaryButton shows loading indicator when isLoading is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppPrimaryButton(
              label: 'حفظ',
              isLoading: true,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('حفظ'), findsNothing);
    });

    testWidgets('AppSecondaryButton renders correctly with default horizontal padding',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSecondaryButton(
              label: 'إلغاء',
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('إلغاء'), findsOneWidget);
      final containerFinder = find.ancestor(
        of: find.text('إلغاء'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 16));
    });

    testWidgets('AppSecondaryButton respects custom padding when provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppSecondaryButton(
              label: 'إلغاء',
              padding: EdgeInsets.symmetric(horizontal: 8),
              onPressed: null,
            ),
          ),
        ),
      );

      final containerFinder = find.ancestor(
        of: find.text('إلغاء'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      expect(container.padding, const EdgeInsets.symmetric(horizontal: 8));
    });

    testWidgets('AppOutlinedButton renders correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppOutlinedButton(
              label: 'تعديل',
              icon: Icons.edit,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.text('تعديل'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('AppIconButton triggers tap callback', (tester) async {
      bool pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppIconButton(
              icon: Icons.add,
              onPressed: () => pressed = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      expect(pressed, isTrue);
    });
  });

  group('Design System - Text Fields & Inputs', () {
    testWidgets('AppTextField renders and receives text input', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppTextField(
                controller: controller,
                label: 'اسم العميل',
                hint: 'أدخل الاسم',
              ),
            ),
          ),
        ),
      );

      expect(find.text('اسم العميل'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'أحمد علي');
      expect(controller.text, 'أحمد علي');
    });

    testWidgets('AppSwitchTile toggles value', (tester) async {
      bool value = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Directionality(
                  textDirection: TextDirection.rtl,
                  child: AppSwitchTile(
                    title: 'تفعيل التنبيه',
                    value: value,
                    onChanged: (val) {
                      setState(() => value = val);
                    },
                  ),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('تفعيل التنبيه'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(value, isTrue);
    });
  });

  group('Design System - Cards & Grouped Lists', () {
    testWidgets('AppCard renders child with subtle border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: Text('محتوى البطاقة'),
            ),
          ),
        ),
      );

      expect(find.text('محتوى البطاقة'), findsOneWidget);
    });

    testWidgets('AppGroupedListCard displays children with dividers',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppGroupedListCard(
              children: [
                Text('عنصر 1'),
                Text('عنصر 2'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('عنصر 1'), findsOneWidget);
      expect(find.text('عنصر 2'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('Design System - Badges & Status Indicators', () {
    testWidgets('AppBadge renders text and custom tint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppBadge(
              label: 'مسدد',
              color: AppColors.statusSuccess,
            ),
          ),
        ),
      );

      expect(find.text('مسدد'), findsOneWidget);
    });

    testWidgets('AppFilterChip renders and toggles selection', (tester) async {
      bool isSelected = false;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: AppFilterChip(
                  label: 'الطلبات العاجلة',
                  isSelected: isSelected,
                  onSelected: (val) => setState(() => isSelected = val),
                ),
              ),
            );
          },
        ),
      );

      expect(find.text('الطلبات العاجلة'), findsOneWidget);
      await tester.tap(find.text('الطلبات العاجلة'));
      await tester.pumpAndSettle();
      expect(isSelected, isTrue);
    });
  });

  group('Design System - Headers & Banners', () {
    testWidgets('AppSectionHeader renders title and action', (tester) async {
      bool actionTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppSectionHeader(
                title: 'أحدث العمليات',
                subtitle: 'سجل آخر الحركات',
                actionTitle: 'عرض الكل',
                onActionTap: () => actionTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('أحدث العمليات'), findsOneWidget);
      expect(find.text('سجل آخر الحركات'), findsOneWidget);
      expect(find.text('عرض الكل'), findsOneWidget);

      await tester.tap(find.text('عرض الكل'));
      await tester.pumpAndSettle();
      expect(actionTapped, isTrue);
    });

    testWidgets('AppStatusBanner renders and handles tap', (tester) async {
      bool bannerTapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppStatusBanner.warning(
                title: 'تنبيه استحقاق',
                message: 'يوجد دين مستحق اليوم',
                onTap: () => bannerTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('تنبيه استحقاق'), findsOneWidget);
      expect(find.text('يوجد دين مستحق اليوم'), findsOneWidget);

      await tester.tap(find.text('تنبيه استحقاق'));
      await tester.pumpAndSettle();
      expect(bannerTapped, isTrue);
    });
  });
}
