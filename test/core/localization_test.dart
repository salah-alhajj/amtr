import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosaed/core/localization/localization.dart';
import 'package:mosaed/core/widgets/country_flag_svg.dart';

void main() {
  group('Localization & i18n Suite Tests', () {
    setUp(() {
      LocalizationHelper.setStrings({
        'app_name': 'مساعد',
        'dashboard_title': 'لوحة التحكم',
        'order_number': 'طلب #{id}',
        'items_count': '{count} أصناف',
      }, 'ar');
    });

    test('LocalizationHelper translates keys properly with Arabic', () {
      expect(LocalizationHelper.translate('app_name'), 'مساعد');
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

    test('CountryFlagSvg maps Arabic strictly to Yemen flag, and others correctly', () {
      expect(CountryFlagSvg.fromLanguageCode('ar').flagCode, 'ye');
      expect(CountryFlagSvg.fromLanguageCode('en').flagCode, 'us');
      expect(CountryFlagSvg.fromLanguageCode('tr').flagCode, 'tr');
      expect(CountryFlagSvg.fromLanguageCode('fr').flagCode, 'fr');
      expect(CountryFlagSvg.fromLanguageCode('es').flagCode, 'es');
    });

    test('AppLanguage supports all 5 languages with valid metadata', () {
      expect(AppLanguage.supported.length, 5);
      final codes = AppLanguage.supported.map((l) => l.code).toList();
      expect(codes, containsAll(['ar', 'en', 'tr', 'fr', 'es']));

      final ar = AppLanguage.fromCode('ar');
      expect(ar.nativeName, 'العربية');

      final tr = AppLanguage.fromCode('tr');
      expect(tr.nativeName, 'Türkçe');

      final fr = AppLanguage.fromCode('fr');
      expect(fr.nativeName, 'Français');

      final es = AppLanguage.fromCode('es');
      expect(es.nativeName, 'Español');
    });

    test('Root i18n files integrity and 1:1 key parity test across all 5 languages', () {
      final languages = ['ar', 'en', 'tr', 'fr', 'es'];
      final Map<String, Set<String>> keysByLang = {};

      for (final lang in languages) {
        final file = File('i18n/$lang.json');
        expect(file.existsSync(), true, reason: 'i18n/$lang.json must exist in root');

        final Map<String, dynamic> jsonMap = json.decode(file.readAsStringSync());
        expect(jsonMap.isNotEmpty, true, reason: 'i18n/$lang.json must not be empty');
        keysByLang[lang] = jsonMap.keys.toSet();
      }

      final baseKeys = keysByLang['ar']!;
      for (final lang in languages.where((l) => l != 'ar')) {
        final currentKeys = keysByLang[lang]!;
        final missingInLang = baseKeys.difference(currentKeys);
        final extraInLang = currentKeys.difference(baseKeys);

        expect(missingInLang, isEmpty,
            reason: 'Keys present in ar.json but missing in $lang.json: $missingInLang');
        expect(extraInLang, isEmpty,
            reason: 'Keys present in $lang.json but missing in ar.json: $extraInLang');
      }

      // Verify no obsolete folders exist
      expect(Directory('assets/i18n').existsSync(), false, reason: 'assets/i18n must not exist');
      expect(Directory('lib/i18n').existsSync(), false, reason: 'lib/i18n must not exist');

      // Verify full 100% key parity (0 missing, 0 extra) across all 4 regional Yemeni dialect files
      for (final dialect in ArabicDialect.supported) {
        if (dialect.assetPath == null) continue;
        final dFile = File(dialect.assetPath!);
        expect(dFile.existsSync(), true, reason: '${dialect.assetPath} must exist');
        final Map<String, dynamic> dMap = json.decode(dFile.readAsStringSync());
        final dKeys = dMap.keys.toSet();
        expect(
          baseKeys.difference(dKeys),
          isEmpty,
          reason: '${dialect.assetPath} is missing keys compared to ar.json',
        );
        expect(
          dKeys.difference(baseKeys),
          isEmpty,
          reason: '${dialect.assetPath} has extra keys compared to ar.json',
        );
      }
    });

    test('English i18n file contains zero Arabic characters', () {
      final enFile = File('i18n/en.json');
      final Map<String, dynamic> enJson = json.decode(enFile.readAsStringSync());
      final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');

      final keysWithArabic = <String, String>{};
      for (final entry in enJson.entries) {
        if (entry.value is String && arabicRegex.hasMatch(entry.value as String)) {
          keysWithArabic[entry.key] = entry.value as String;
        }
      }

      expect(keysWithArabic, isEmpty,
          reason: 'en.json must not contain any Arabic text. Found: $keysWithArabic');
    });
  });
}
