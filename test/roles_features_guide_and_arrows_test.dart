import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mosaed/core/business/app_feature_flags.dart';
import 'package:mosaed/core/business/business_mode_cubit.dart';
import 'package:mosaed/core/constants.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/core/widgets/business_drawer.dart';
import 'package:mosaed/core/widgets/design_system.dart';
import 'package:mosaed/features/guide/presentation/screens/app_user_guide_screen.dart';
import 'package:mosaed/features/orders/presentation/widgets/order_card.dart';
import 'package:mosaed/features/settings/presentation/screens/feature_settings_screen.dart';
import 'package:mosaed/models/individual_order.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> arStrings;
  late Map<String, String> enStrings;

  setUpAll(() {
    final arJson =
        json.decode(File('i18n/ar.json').readAsStringSync()) as Map<String, dynamic>;
    arStrings = arJson.map((k, v) => MapEntry(k, v.toString()));

    final enJson =
        json.decode(File('i18n/en.json').readAsStringSync()) as Map<String, dynamic>;
    enStrings = enJson.map((k, v) => MapEntry(k, v.toString()));
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PreferencesService.instance.init();
    LocalizationHelper.setStrings(arStrings, 'ar');
  });

  Future<void> runNarrowWithErrorTrap(
    WidgetTester tester, {
    required Widget child,
    Brightness brightness = Brightness.light,
    String langCode = 'ar',
    required Future<void> Function() body,
  }) async {
    LocalizationHelper.setStrings(
      langCode == 'ar' ? arStrings : enStrings,
      langCode,
    );
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final errors = <FlutterErrorDetails>[];
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
    };

    try {
      final businessCubit = BusinessModeCubit()..loadFromPreferences();
      addTearDown(businessCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<LocaleBloc>(create: (_) => LocaleBloc()),
            BlocProvider<ThemeBloc>(create: (_) => ThemeBloc()),
            BlocProvider<BusinessModeCubit>.value(value: businessCubit),
          ],
          child: MaterialApp(
            theme: brightness == Brightness.dark
                ? AppTheme.darkTheme
                : AppTheme.lightTheme,
            locale: Locale(langCode),
            home: Directionality(
              textDirection:
                  langCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child,
            ),
          ),
        ),
      );
      await tester.pump();
      await body();
    } finally {
      FlutterError.onError = prevOnError;
    }

    expect(
      errors,
      isEmpty,
      reason: errors.map((e) => e.exceptionAsString()).join('\n'),
    );
  }

  group('Role Presets & Feature Visibility Flags', () {
    test('Role defaults and manual overrides persist and reset cleanly', () async {
      final cubit = BusinessModeCubit()..loadFromPreferences();
      addTearDown(cubit.close);

      // Default productive_family keeps backward compatibility (shipments=false, 7 enabled)
      expect(cubit.state.businessMode, AppConstants.businessModeProductiveFamily);
      expect(cubit.state.features.shipments, isFalse);
      expect(cubit.state.features.enabledCount, 7);

      // Simple Home Seller hides all 8 advanced modules
      await cubit.applyRolePreset(AppConstants.businessModeSimpleSeller);
      expect(cubit.state.businessMode, AppConstants.businessModeSimpleSeller);
      expect(cubit.state.isProductiveFamily, isTrue);
      expect(cubit.state.features.enabledCount, 0);
      expect(PreferencesService.instance.getFeatureFlags().enabledCount, 0);

      // Toggle one feature on manually
      await cubit.toggleFeature(AppFeatureFlags.keyCouriers, true);
      expect(cubit.state.features.couriers, isTrue);
      expect(cubit.state.features.enabledCount, 1);
      expect(PreferencesService.instance.getFeatureFlags().couriers, isTrue);

      // Reset clears overrides back to simple_home_seller defaults
      await cubit.resetFeaturesToRoleDefaults();
      expect(cubit.state.features.enabledCount, 0);

      // Artisan Craft & Retail Shop & Trade Logistics presets
      await cubit.applyRolePreset(AppConstants.businessModeArtisanCraft);
      expect(cubit.state.features.manufacturing, isTrue);
      expect(cubit.state.features.curingWaste, isTrue);
      expect(cubit.state.features.dailyPrep, isFalse);
      expect(cubit.state.features.enabledCount, 6);

      await cubit.applyRolePreset(AppConstants.businessModeRetailShop);
      expect(cubit.state.features.manufacturing, isFalse);
      expect(cubit.state.features.suppliers, isTrue);
      expect(cubit.state.features.variantsBundles, isTrue);
      expect(cubit.state.features.enabledCount, 3);

      await cubit.applyRolePreset(AppConstants.businessModeTradeLogistics);
      expect(cubit.state.isProductiveFamily, isFalse);
      expect(cubit.state.features.shipments, isTrue);
      expect(cubit.state.multiCurrencyEnabled, isTrue);
      expect(cubit.state.features.enabledCount, 3);
    });
  });

  group('ListTile Material & Directional Arrow Checks', () {
    testWidgets('AppModalSheet and AppCard with ListTile throw zero Material assertions', (tester) async {
      await runNarrowWithErrorTrap(
        tester,
        child: Scaffold(
          body: ListView(
            children: [
              AppCard(
                onTap: () {},
                child: const ListTile(
                  title: Text('Card ListTile'),
                ),
              ),
              AppModalSheet(
                title: 'Modal Sheet',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Option 1'),
                      onTap: () {},
                    ),
                    SwitchListTile(
                      title: const Text('Toggle 1'),
                      value: true,
                      onChanged: (_) {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        body: () async {
          await tester.pump();
        },
      );
    });

    testWidgets('Forward/Back chevrons & OrderCard advance arrow respect RTL/LTR', (tester) async {
      final order = IndividualOrder(
        id: 'o_arrow_1',
        orderNumber: 'ORD-101',
        customerName: 'سارة',
        orderStatus: AppConstants.orderStatusPending,
        paymentStatus: AppConstants.paymentPrepaid,
      );

      for (final lang in ['ar', 'en']) {
        await runNarrowWithErrorTrap(
          tester,
          langCode: lang,
          child: Scaffold(
            body: Column(
              children: [
                const ForwardChevron(),
                const BackChevron(),
                OrderCard(
                  order: order,
                  nextStatusLabel: 'جاري التجهيز',
                  onTap: () {},
                  onAdvanceStatus: () {},
                ),
              ],
            ),
          ),
          body: () async {
            final forwardIcon = tester.widget<Icon>(
              find.byIcon(Icons.arrow_forward_rounded),
            );
            expect(forwardIcon.icon!.matchTextDirection, isTrue);
            final backIcon = tester.widget<Icon>(
              find.byIcon(Icons.arrow_back_ios_new_rounded),
            );
            expect(backIcon.icon!.matchTextDirection, isTrue);
          },
        );
      }
    });
  });

  group('FeatureSettingsScreen, AppUserGuideScreen & Drawer (360x740 Light & Dark)', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final themeName = brightness == Brightness.dark ? 'Dark' : 'Light';

      testWidgets('FeatureSettingsScreen renders & toggles roles ($themeName)', (tester) async {
        await runNarrowWithErrorTrap(
          tester,
          brightness: brightness,
          child: const FeatureSettingsScreen(),
          body: () async {
            expect(find.text('business_mode_simple_seller'.i18n()), findsOneWidget);
            await tester.tap(find.text('business_mode_simple_seller'.i18n()));
            await tester.pump();
            // Flush AppToast auto-dismiss timer cleanly
            await tester.pump(const Duration(seconds: 5));
            expect(PreferencesService.instance.getBusinessMode(), AppConstants.businessModeSimpleSeller);
            expect(PreferencesService.instance.getFeatureFlags().enabledCount, 0);
          },
        );
      });

      testWidgets('AppUserGuideScreen searches, filters & expands ($themeName)', (tester) async {
        await runNarrowWithErrorTrap(
          tester,
          brightness: brightness,
          child: const AppUserGuideScreen(),
          body: () async {
            expect(find.text('guide_ch1_title'.i18n()), findsOneWidget);
            await tester.enterText(find.byType(TextField).first, 'JSON');
            await tester.pump();
            expect(find.text('guide_ch8_title'.i18n()), findsOneWidget);
            expect(find.text('guide_ch2_title'.i18n()), findsNothing);
          },
        );
      });

      testWidgets('BusinessDrawer hides advanced modules in Simple Seller mode ($themeName)', (tester) async {
        await PreferencesService.instance.setBusinessMode(
          AppConstants.businessModeSimpleSeller,
          resetFeatureOverrides: true,
        );
        await runNarrowWithErrorTrap(
          tester,
          brightness: brightness,
          child: const Scaffold(
            body: BusinessDrawer(),
          ),
          body: () async {
            expect(find.text('nav_orders'.i18n()), findsOneWidget);
            expect(find.text('manufacturing_hub_title'.i18n()), findsNothing);
            expect(find.text('suppliers_title'.i18n()), findsNothing);
            expect(find.text('couriers_title'.i18n()), findsNothing);
            expect(find.text('nav_shipments'.i18n()), findsNothing);
            final drawerScrollable = find.descendant(
              of: find.byType(BusinessDrawer),
              matching: find.byType(Scrollable),
            );
            await tester.scrollUntilVisible(
              find.text('feature_settings_title'.i18n()),
              200,
              scrollable: drawerScrollable,
            );
            expect(find.text('feature_settings_title'.i18n()), findsOneWidget);
            await tester.scrollUntilVisible(
              find.text('guide_screen_title'.i18n()),
              200,
              scrollable: drawerScrollable,
            );
            expect(find.text('guide_screen_title'.i18n()), findsOneWidget);
          },
        );
      });
    }
  });
}
