import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/preferences_service.dart';
import 'app_localizations.dart';
import 'arabic_dialect.dart';
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

class ChangeArabicDialect extends LocaleEvent {
  final String dialectId;
  const ChangeArabicDialect(this.dialectId);
}

class LocaleState {
  final Locale locale;
  final TextDirection textDirection;
  final String arabicDialect;

  const LocaleState({
    required this.locale,
    required this.textDirection,
    this.arabicDialect = ArabicDialect.standardId,
  });

  bool get isArabic => locale.languageCode == 'ar';
}

/// BLoC نقي لإدارة لغة التطبيق واللهجة الإقليمية والاتجاه (RTL/LTR)
class LocaleBloc extends Bloc<LocaleEvent, LocaleState> {
  static String _activeLocaleCode = 'ar';
  static String _activeArabicDialect = ArabicDialect.standardId;

  LocaleBloc()
      : super(const LocaleState(
          locale: Locale('ar'),
          textDirection: TextDirection.rtl,
          arabicDialect: ArabicDialect.standardId,
        )) {
    on<LoadPersistedLocale>(_onLoadPersistedLocale);
    on<ChangeLocale>(_onChangeLocale);
    on<ToggleLocale>(_onToggleLocale);
    on<ChangeArabicDialect>(_onChangeArabicDialect);
  }

  Future<void> _onLoadPersistedLocale(
    LoadPersistedLocale event,
    Emitter<LocaleState> emit,
  ) async {
    try {
      await PreferencesService.instance.init();
      _activeLocaleCode = PreferencesService.instance.getLocaleCode();
      _activeArabicDialect = PreferencesService.instance.getArabicDialect();
    } catch (_) {
      // Fallback in test environments or without native plugin channel
    }
    final locale = Locale(_activeLocaleCode);
    await _syncLocalization(locale, _activeArabicDialect);
    emit(LocaleState(
      locale: locale,
      textDirection:
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      arabicDialect: _activeArabicDialect,
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
    await _syncLocalization(event.locale, state.arabicDialect);

    emit(LocaleState(
      locale: event.locale,
      textDirection: event.locale.languageCode == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      arabicDialect: state.arabicDialect,
    ));
  }

  Future<void> _onToggleLocale(
    ToggleLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final nextCode = state.locale.languageCode == 'ar' ? 'en' : 'ar';
    add(ChangeLocale(Locale(nextCode)));
  }

  Future<void> _onChangeArabicDialect(
    ChangeArabicDialect event,
    Emitter<LocaleState> emit,
  ) async {
    final normalized = ArabicDialect.fromId(event.dialectId).id;
    _activeArabicDialect = normalized;
    try {
      await PreferencesService.instance.setArabicDialect(normalized);
    } catch (_) {
      // Fallback
    }
    await _syncLocalization(state.locale, normalized, forceReload: true);
    emit(LocaleState(
      locale: state.locale,
      textDirection: state.textDirection,
      arabicDialect: normalized,
    ));
  }

  Future<void> _syncLocalization(
    Locale locale,
    String arabicDialect, {
    bool forceReload = false,
  }) async {
    final effectiveDialect = locale.languageCode == 'ar'
        ? ArabicDialect.fromId(arabicDialect).id
        : ArabicDialect.standardId;

    if (!forceReload &&
        LocalizationHelper.localizedStrings != null &&
        LocalizationHelper.localizedStrings!.isNotEmpty &&
        LocalizationHelper.currentLanguage == locale.languageCode &&
        (locale.languageCode != 'ar' ||
            LocalizationHelper.currentArabicDialect == effectiveDialect)) {
      return;
    }

    final appLoc = AppLocalizations(
      locale,
      arabicDialect: effectiveDialect,
    );
    final success = await appLoc.load();
    if (success && appLoc.localizedStrings.isNotEmpty) {
      LocalizationHelper.setStrings(
        appLoc.localizedStrings,
        locale.languageCode,
        arabicDialect: effectiveDialect,
      );
    } else {
      await LocalizationHelper.load(
        locale.languageCode,
        arabicDialect: effectiveDialect,
      );
    }
  }
}
