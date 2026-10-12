import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:amtr/core/localization/localization.dart';

void main() {
  group('Localization & i18n Suite Tests', () {
    setUp(() {
      LocalizationHelper.setStrings({
        'app_name': 'مساعد التجارة والشحن',
        'dashboard_title': 'لوحة التحكم',
        'order_number': 'طلب #{id}',
        'items_count': '{count} أصناف',
      }, 'ar');
    });

    test('LocalizationHelper translates keys properly with Arabic', () {
      expect(LocalizationHelper.translate('app_name'), 'مساعد التجارة والشحن');
      expect(LocalizationHelper.translate('dashboard_title'), 'لوحة التحكم');
    });

    test('LocalizationHelper handles parameters replacement', () {
      final translated = LocalizationHelper.translate(
        'order_number',
        params: {'id': '994'},
      );
      expect(translated, 'طلب #994');

      final itemsTranslated = LocalizationHelper.translate(
        'items_count',
        params: {'count': '12'},
      );
      expect(itemsTranslated, '12 أصناف');
    });

    test('String extension .trParams replaces parameters properly', () {
      final res = 'order_number'.trParams({'id': '505'});
      expect(res, 'طلب #505');
    });

    test('LocaleBloc state updates and reflects RTL for Arabic and LTR for English', () async {
      final bloc = LocaleBloc();

      expect(bloc.state.locale.languageCode, 'ar');
      expect(bloc.state.textDirection, TextDirection.rtl);
      expect(bloc.state.isArabic, true);

      bloc.add(const ChangeLocale(Locale('en')));
      await pumpEventQueue();

      expect(bloc.state.locale.languageCode, 'en');
      expect(bloc.state.textDirection, TextDirection.ltr);
      expect(bloc.state.isArabic, false);

      bloc.add(const ToggleLocale());
      await pumpEventQueue();

      expect(bloc.state.locale.languageCode, 'ar');
      expect(bloc.state.textDirection, TextDirection.rtl);

      await bloc.close();
    });

    test('AppLocalizations fallback prevents crash when key is missing', () {
      final appLoc = AppLocalizations(const Locale('ar'));
      final fallbackResult = appLoc.translate('missing_unknown_key');
      expect(fallbackResult, 'missing_unknown_key');
    });
  });
}
