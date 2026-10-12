import 'dart:convert';
import 'dart:io';
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

    test('Root i18n files integrity and 1:1 key parity test', () {
      final arFile = File('i18n/ar.json');
      final enFile = File('i18n/en.json');

      expect(arFile.existsSync(), true, reason: 'i18n/ar.json must exist in root');
      expect(enFile.existsSync(), true, reason: 'i18n/en.json must exist in root');

      final Map<String, dynamic> arJson = json.decode(arFile.readAsStringSync());
      final Map<String, dynamic> enJson = json.decode(enFile.readAsStringSync());

      expect(arJson.isNotEmpty, true);
      expect(enJson.isNotEmpty, true);

      final arKeys = arJson.keys.toSet();
      final enKeys = enJson.keys.toSet();

      final missingInEn = arKeys.difference(enKeys);
      final missingInAr = enKeys.difference(arKeys);

      expect(missingInEn, isEmpty, reason: 'Keys present in ar.json but missing in en.json: $missingInEn');
      expect(missingInAr, isEmpty, reason: 'Keys present in en.json but missing in ar.json: $missingInAr');

      // Verify no obsolete folders exist
      expect(Directory('assets/i18n').existsSync(), false, reason: 'assets/i18n must not exist');
      expect(Directory('lib/i18n').existsSync(), false, reason: 'lib/i18n must not exist');
    });
  });
}
