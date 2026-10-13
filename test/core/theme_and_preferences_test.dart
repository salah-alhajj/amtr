import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/services/preferences_service.dart';
import 'package:mosaed/core/theme/theme.dart';
import 'package:mosaed/features/settings/presentation/widgets/theme_selector_card.dart';

void main() {
  group('PreferencesService & Theme Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await PreferencesService.instance.init();
      LocalizationHelper.setStrings({
        'theme_settings': 'المظهر والسمة',
        'theme_mode': 'نمط المظهر',
        'theme_system': 'تلقائي (حسب النظام)',
        'theme_light': 'فاتح',
        'theme_dark': 'داكن',
        'theme_system_desc': 'مزامنة المظهر تلقائياً مع إعدادات نظام الجهاز',
        'theme_light_desc': 'مظهر نهاري ناصع ومريح للعين',
        'theme_dark_desc': 'مظهر ليلي عميق بتقنية OLED وموفر للطاقة',
      }, 'ar');
    });

    test('PreferencesService saves and retrieves ThemeMode correctly', () async {
      final prefs = PreferencesService.instance;
      await prefs.init();

      // الافتراضي هو النظام
      expect(prefs.getThemeMode(), ThemeMode.system);

      // حفظ واسترجاع النمط الداكن
      await prefs.setThemeMode(ThemeMode.dark);
      expect(prefs.getThemeMode(), ThemeMode.dark);

      // حفظ واسترجاع النمط الفاتح
      await prefs.setThemeMode(ThemeMode.light);
      expect(prefs.getThemeMode(), ThemeMode.light);

      // العودة لنمط النظام
      await prefs.setThemeMode(ThemeMode.system);
      expect(prefs.getThemeMode(), ThemeMode.system);
    });

    test('PreferencesService saves and retrieves locale preferences', () async {
      final prefs = PreferencesService.instance;
      await prefs.init();

      expect(prefs.getLocaleCode(), 'ar');

      await prefs.setLocaleCode('en');
      expect(prefs.getLocaleCode(), 'en');

      await prefs.setLocaleCode('ar');
      expect(prefs.getLocaleCode(), 'ar');
    });

    test('ThemeBloc state transitions work for system, light, and dark modes', () async {
      final bloc = ThemeBloc();

      expect(bloc.state.themeMode, ThemeMode.system);
      expect(bloc.state.isSystem, true);
      expect(bloc.state.isLight, false);
      expect(bloc.state.isDark, false);

      bloc.add(const ChangeThemeMode(ThemeMode.dark));
      await pumpEventQueue();

      expect(bloc.state.themeMode, ThemeMode.dark);
      expect(bloc.state.isDark, true);
      expect(bloc.state.isSystem, false);

      bloc.add(const ChangeThemeMode(ThemeMode.light));
      await pumpEventQueue();

      expect(bloc.state.themeMode, ThemeMode.light);
      expect(bloc.state.isLight, true);
      expect(bloc.state.isDark, false);

      await bloc.close();
    });

    test('ThemeBloc loads persisted theme mode upon LoadPersistedTheme', () async {
      final prefs = PreferencesService.instance;
      await prefs.init();
      await prefs.setThemeMode(ThemeMode.dark);

      final bloc = ThemeBloc();
      bloc.add(const LoadPersistedTheme());
      await pumpEventQueue();

      expect(bloc.state.themeMode, ThemeMode.dark);
      expect(bloc.state.isDark, true);

      await bloc.close();
    });

    test('AppTheme definitions comply with Apple HIG specifications', () {
      final lightTheme = AppTheme.lightTheme;
      expect(lightTheme.brightness, Brightness.light);
      expect(lightTheme.scaffoldBackgroundColor, AppColors.scaffoldBackground);
      expect(lightTheme.colorScheme.primary, AppColors.primaryBlue);

      final darkTheme = AppTheme.darkTheme;
      expect(darkTheme.brightness, Brightness.dark);
      expect(darkTheme.scaffoldBackgroundColor, AppColors.darkScaffoldBackground);
      expect(darkTheme.colorScheme.surface, AppColors.darkSurfaceCard);
      expect(darkTheme.cardTheme.color, AppColors.darkSurfaceCard);
    });

    testWidgets('ThemeSelectorCard renders all 3 options and dispatches change events', (tester) async {
      final themeBloc = ThemeBloc();

      await tester.pumpWidget(
        BlocProvider<ThemeBloc>.value(
          value: themeBloc,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            home: const Scaffold(
              body: SingleChildScrollView(
                child: ThemeSelectorCard(),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // التحقق من ظهور الترويسة والخيارات الثلاثة
      expect(find.text('المظهر والسمة'), findsOneWidget);
      expect(find.text('تلقائي (حسب النظام)'), findsOneWidget);
      expect(find.text('فاتح'), findsOneWidget);
      expect(find.text('داكن'), findsOneWidget);

      // النقر على خيار "داكن"
      await tester.tap(find.text('داكن'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(themeBloc.state.themeMode, ThemeMode.dark);
      expect(find.text('مظهر ليلي عميق بتقنية OLED وموفر للطاقة'), findsOneWidget);

      // النقر على خيار "فاتح"
      await tester.tap(find.text('فاتح'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(themeBloc.state.themeMode, ThemeMode.light);
      expect(find.text('مظهر نهاري ناصع ومريح للعين'), findsOneWidget);
    });
  });
}
