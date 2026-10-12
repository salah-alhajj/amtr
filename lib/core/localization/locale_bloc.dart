import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/preferences_service.dart';
import 'app_localizations.dart';
import 'localization_helper.dart';

abstract class LocaleEvent {
  const LocaleEvent();
}

class LoadPersistedLocale extends LocaleEvent {
  const LoadPersistedLocale();
}

class ChangeLocale extends LocaleEvent {
  final Locale locale;
  const ChangeLocale(this.locale);
}

class ToggleLocale extends LocaleEvent {
  const ToggleLocale();
}

class LocaleState {
  final Locale locale;
  final TextDirection textDirection;

  const LocaleState({
    required this.locale,
    required this.textDirection,
  });

  bool get isArabic => locale.languageCode == 'ar';
}

/// BLoC نقي لإدارة لغة التطبيق والاتجاه (RTL/LTR)
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  static String _activeLocaleCode = 'ar';

  LocaleBloc()
      : super(const LocaleState(
          locale: Locale('ar'),
          textDirection: TextDirection.rtl,
        )) {
    on<LoadPersistedLocale>(_onLoadPersistedLocale);
    on<ChangeLocale>(_onChangeLocale);
    on<ToggleLocale>(_onToggleLocale);
  }

  Future<void> _onLoadPersistedLocale(
    LoadPersistedLocale event,
    Emitter<LocaleState> emit,
  ) async {
    try {
      await PreferencesService.instance.init();
      _activeLocaleCode = PreferencesService.instance.getLocaleCode();
    } catch (_) {
      // Fallback in test environments or without native plugin channel
    }
    final locale = Locale(_activeLocaleCode);
    await _syncLocalization(locale);
    emit(LocaleState(
      locale: locale,
      textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    ));
  }

  Future<void> _onChangeLocale(
    ChangeLocale event,
    Emitter<LocaleState> emit,
  ) async {
    if (state.locale == event.locale) return;

    _activeLocaleCode = event.locale.languageCode;
    try {
      await PreferencesService.instance.setLocaleCode(event.locale.languageCode);
    } catch (_) {
      // Fallback
    }
    await _syncLocalization(event.locale);

    emit(LocaleState(
      locale: event.locale,
      textDirection: event.locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
    ));
  }

  Future<void> _onToggleLocale(
    ToggleLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final nextCode = state.locale.languageCode == 'ar' ? 'en' : 'ar';
    add(ChangeLocale(Locale(nextCode)));
  }

  Future<void> _syncLocalization(Locale locale) async {
    // إذا كانت الترجمات محددة مسبقاً لهذه اللغة (مثلاً في بيئة الاختبارات)، نعتمدها مباشرة
    if (LocalizationHelper.localizedStrings != null &&
        LocalizationHelper.localizedStrings!.isNotEmpty &&
        LocalizationHelper.currentLanguage == locale.languageCode) {
      return;
    }

    final appLoc = AppLocalizations(locale);
    final success = await appLoc.load();
    if (success && appLoc.localizedStrings.isNotEmpty) {
      LocalizationHelper.setStrings(appLoc.localizedStrings, locale.languageCode);
    } else {
      await LocalizationHelper.load(locale.languageCode);
    }
  }
}
