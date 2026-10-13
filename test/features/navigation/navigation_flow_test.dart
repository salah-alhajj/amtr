import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:amtr/core/localization/locale_bloc.dart';
import 'package:amtr/core/localization/localization_helper.dart';
import 'package:amtr/features/navigation/widgets/directional_slide_indexed_stack.dart';
import 'package:amtr/features/navigation/widgets/amtr_bottom_nav_bar.dart';
import 'package:amtr/features/navigation/main_navigation_shell.dart';

void main() {
  group('DirectionalSlideIndexedStack Tests', () {
    testWidgets('renders current index and transitions smoothly', (tester) async {
      int activeIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: DirectionalSlideIndexedStack(
                    index: activeIndex,
                    children: const [
                      Text('Screen 0 (Home)'),
                      Text('Screen 1 (Orders)'),
                      Text('Screen 2 (Shipments)'),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() => activeIndex = 1),
                    child: const Icon(Icons.arrow_forward),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Screen 0 (Home)'), findsOneWidget);
      expect(find.text('Screen 1 (Orders)'), findsNothing);

      // Trigger transition to index 1 (forward in RTL)
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 160)); // Halfway

      // Both widgets should be present during transition
      expect(find.text('Screen 0 (Home)'), findsOneWidget);
      expect(find.text('Screen 1 (Orders)'), findsOneWidget);

      // Complete transition
      await tester.pumpAndSettle();
      expect(find.text('Screen 1 (Orders)'), findsOneWidget);
    });

    testWidgets('preserves state across tab switches', (tester) async {
      int activeIndex = 0;
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setState) {
                return Scaffold(
                  body: DirectionalSlideIndexedStack(
                    index: activeIndex,
                    children: [
                      TextField(controller: controller),
                      const Text('Second Screen'),
                    ],
                  ),
                  floatingActionButton: FloatingActionButton(
                    onPressed: () => setState(() => activeIndex = 1),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Mosaed Preservation Test');
      expect(controller.text, 'Mosaed Preservation Test');

      // Switch to tab 1
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('Second Screen'), findsOneWidget);

      // Value in controller should remain intact
      expect(controller.text, 'Mosaed Preservation Test');
    });
  });

  group('AmtrBottomNavBar Tests', () {
    testWidgets('renders all items and responds to taps', (tester) async {
      int selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              bottomNavigationBar: StatefulBuilder(
                builder: (context, setState) {
                  return AmtrBottomNavBar(
                    selectedIndex: selected,
                    onItemSelected: (idx) => setState(() => selected = idx),
                    items: const [
                      AmtrNavItemData(
                        icon: Icons.home_outlined,
                        activeIcon: Icons.home,
                        label: 'Home',
                        activeColor: Colors.blue,
                      ),
                      AmtrNavItemData(
                        icon: Icons.list_outlined,
                        activeIcon: Icons.list,
                        label: 'Orders',
                        activeColor: Colors.green,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);

      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(selected, 1);
    });
  });

  group('MainNavigationScope Tests', () {
    testWidgets('provides navigateTo to descendants', (tester) async {
      int currentIdx = 0;
      int? navigatedTo;

      await tester.pumpWidget(
        MaterialApp(
          home: MainNavigationScope(
            currentIndex: currentIdx,
            navigateTo: (idx) => navigatedTo = idx,
            child: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () => MainNavigationScope.of(ctx).navigateTo(3),
                  child: const Text('Go to Customers'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      expect(navigatedTo, 3);
    });
  });

  group('Page Title Localization Dynamic Tests', () {
    testWidgets('rebuilds page title when locale changes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final localeBloc = LocaleBloc();

      // Seed dictionaries for testing
      LocalizationHelper.setStrings({'orders_title': 'الطلبات'}, 'ar');

      await tester.pumpWidget(
        BlocProvider<LocaleBloc>.value(
          value: localeBloc,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                context.watch<LocaleBloc>();
                return Scaffold(
                  appBar: AppBar(
                    title: Text(LocalizationHelper.translate('orders_title')),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('الطلبات'), findsOneWidget);
      expect(find.text('Orders'), findsNothing);

      // Now switch to English
      LocalizationHelper.setStrings({'orders_title': 'Orders'}, 'en');
      localeBloc.add(const ChangeLocale(Locale('en')));
      await tester.pumpAndSettle();

      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('الطلبات'), findsNothing);
    });
  });
}
