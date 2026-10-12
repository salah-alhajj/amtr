import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/theme/app_theme.dart';
import 'package:amtr/core/widgets/design_system.dart';
import 'package:amtr/models/customer.dart';

void main() {
  group('AppTheme Dropdown & Menu Font Configuration', () {
    test('lightTheme has dropdownMenuTheme and popupMenuTheme configured with AppTheme.fontFamily', () {
      final theme = AppTheme.lightTheme;
      expect(theme.dropdownMenuTheme.textStyle?.fontFamily, equals(AppTheme.fontFamily));
      expect(theme.popupMenuTheme.textStyle?.fontFamily, equals(AppTheme.fontFamily));
    });

    test('darkTheme has dropdownMenuTheme and popupMenuTheme configured with AppTheme.fontFamily', () {
      final theme = AppTheme.darkTheme;
      expect(theme.dropdownMenuTheme.textStyle?.fontFamily, equals(AppTheme.fontFamily));
      expect(theme.popupMenuTheme.textStyle?.fontFamily, equals(AppTheme.fontFamily));
    });
  });

  group('AppDropdownField Font Enforcement', () {
    testWidgets('AppDropdownField label and dropdown items enforce AppTheme.fontFamily', (tester) async {
      String? selected = 'item1';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppDropdownField<String>(
                label: 'قائمة مخصصة',
                value: selected,
                items: const [
                  DropdownMenuItem(
                    value: 'item1',
                    child: Text('خيار أول عادي'),
                  ),
                  DropdownMenuItem(
                    value: 'item2',
                    child: Text(
                      'خيار ثان مخصص',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                onChanged: (val) => selected = val,
              ),
            ),
          ),
        ),
      );

      // Check the label text
      final labelFinder = find.text('قائمة مخصصة');
      expect(labelFinder, findsOneWidget);
      final labelTextWidget = tester.widget<Text>(labelFinder);
      expect(labelTextWidget.style?.fontFamily, equals(AppTheme.fontFamily));

      // Check the DropdownButton style
      final dropdownFinder = find.byType(DropdownButton<String>);
      expect(dropdownFinder, findsOneWidget);
      final dropdownWidget = tester.widget<DropdownButton<String>>(dropdownFinder);
      expect(dropdownWidget.style?.fontFamily, equals(AppTheme.fontFamily));

      // The selected item in the dropdown
      final selectedTextFinder = find.text('خيار أول عادي');
      expect(selectedTextFinder, findsOneWidget);
      final selectedTextWidget = tester.widget<Text>(selectedTextFinder);
      expect(selectedTextWidget.style?.fontFamily, equals(AppTheme.fontFamily));

      // Open dropdown menu
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Check that menu items all have AppTheme.fontFamily
      final option2Finder = find.text('خيار ثان مخصص');
      expect(option2Finder, findsOneWidget);
      final option2TextWidget = tester.widget<Text>(option2Finder);
      expect(option2TextWidget.style?.fontFamily, equals(AppTheme.fontFamily));
      expect(option2TextWidget.style?.fontWeight, equals(FontWeight.bold));
    });

    testWidgets('AppDropdownField with composite child wraps in DefaultTextStyle with AppTheme.fontFamily', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppDropdownField<String>(
                label: 'قائمة برموز',
                value: 'sar',
                items: const [
                  DropdownMenuItem(
                    value: 'sar',
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.monetization_on),
                        Text('ريال سعودي'),
                      ],
                    ),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      final textElement = tester.element(find.text('ريال سعودي'));
      final inheritedDefaultTextStyle = DefaultTextStyle.of(textElement);
      expect(inheritedDefaultTextStyle.style.fontFamily, equals(AppTheme.fontFamily));
    });
  });

  group('AppCustomerSearchDropdown Font Enforcement', () {
    testWidgets('AppCustomerSearchDropdown uses AppTheme.fontFamily for label, hint, and picker', (tester) async {
      final customer = Customer(id: 'c1', name: 'أحمد علي', phone: '777123456');

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: AppCustomerSearchDropdown(
                label: 'اختر عميلاً',
                selectedCustomerId: customer.id,
                customers: [customer],
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Label font
      final labelFinder = find.text('اختر عميلاً');
      expect(labelFinder, findsOneWidget);
      final labelTextWidget = tester.widget<Text>(labelFinder);
      expect(labelTextWidget.style?.fontFamily, equals(AppTheme.fontFamily));

      // Selected customer name font
      final nameFinder = find.text('أحمد علي');
      expect(nameFinder, findsOneWidget);
      final nameTextWidget = tester.widget<Text>(nameFinder);
      expect(nameTextWidget.style?.fontFamily, equals(AppTheme.fontFamily));

      // Customer avatar letter font
      final avatarFinder = find.text('أ');
      expect(avatarFinder, findsOneWidget);
      final avatarTextWidget = tester.widget<Text>(avatarFinder);
      expect(avatarTextWidget.style?.fontFamily, equals(AppTheme.fontFamily));
    });
  });
}
