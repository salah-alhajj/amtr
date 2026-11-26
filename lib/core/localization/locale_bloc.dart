import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../services/preferences_service.dart';
import 'app_language.dart';
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

  int _requestSeq = 0;

  static String _normalizeLocaleCode(String? code) {
    final trimmed = code?.trim() ?? '';
    if (AppLanguage.supported.any((l) => l.code == trimmed)) {
      return trimmed;
    }
    return 'ar';
  }

  static LocaleState _resolveInitialState() {
    try {
      final code = _normalizeLocaleCode(
        PreferencesService.instance.getLocaleCode(),
      );
      final dialect = PreferencesService.instance.getArabicDialect();
      _activeLocaleCode = code;
      _activeArabicDialect = dialect;
      return LocaleState(
        locale: Locale(code),
        textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        arabicDialect: dialect,
      );
    } catch (_) {
      return const LocaleState(
        locale: Locale('ar'),
        textDirection: TextDirection.rtl,
        arabicDialect: ArabicDialect.standardId,
      );
    }
  }

  LocaleBloc() : super(_resolveInitialState()) {
    on<LoadPersistedLocale>(_onLoadPersistedLocale);
    on<ChangeLocale>(_onChangeLocale);
    on<ToggleLocale>(_onToggleLocale);
    on<ChangeArabicDialect>(_onChangeArabicDialect);
  }

  Future<void> _onLoadPersistedLocale(
    LoadPersistedLocale event,
    Emitter<LocaleState> emit,
  ) async {
    final seq = ++_requestSeq;
    try {
      await PreferencesService.instance.init();
      if (seq != _requestSeq) return;
      _activeLocaleCode = _normalizeLocaleCode(
        PreferencesService.instance.getLocaleCode(),
      );
      _activeArabicDialect = PreferencesService.instance.getArabicDialect();
    } catch (_) {
      // Fallback in test environments or without native plugin channel
    }
    if (seq != _requestSeq) return;

    final locale = Locale(_activeLocaleCode);
    final effectiveDialect = locale.languageCode == 'ar'
        ? ArabicDialect.fromId(_activeArabicDialect).id
        : ArabicDialect.standardId;

    LocalizationHelper.setTarget(
      locale.languageCode,
      arabicDialect: effectiveDialect,
    );
    await _syncLocalization(locale, effectiveDialect);
    if (seq != _requestSeq) return;

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
    final normalizedCode = _normalizeLocaleCode(event.locale.languageCode);
    final targetLocale = Locale(normalizedCode);
    final effectiveDialect = normalizedCode == 'ar'
        ? ArabicDialect.fromId(state.arabicDialect).id
        : ArabicDialect.standardId;

    if (state.locale == targetLocale &&
        LocalizationHelper.currentLanguage == normalizedCode &&
        (normalizedCode != 'ar' ||
            LocalizationHelper.currentArabicDialect == effectiveDialect) &&
        LocalizationHelper.localizedStrings != null &&
        LocalizationHelper.localizedStrings!.isNotEmpty) {
      return;
    }

    final seq = ++_requestSeq;
    _activeLocaleCode = normalizedCode;
    LocalizationHelper.setTarget(
      normalizedCode,
      arabicDialect: effectiveDialect,
    );
    try {
      await PreferencesService.instance.setLocaleCode(normalizedCode);
    } catch (_) {
      // Fallback
    }
    if (seq != _requestSeq) return;

    await _syncLocalization(targetLocale, state.arabicDialect);
    if (seq != _requestSeq) return;

    emit(LocaleState(
      locale: targetLocale,
      textDirection:
          normalizedCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
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
    final seq = ++_requestSeq;
    final normalized = ArabicDialect.fromId(event.dialectId).id;
    _activeArabicDialect = normalized;
    LocalizationHelper.setTarget(
      state.locale.languageCode,
      arabicDialect: normalized,
    );
    try {
      await PreferencesService.instance.setArabicDialect(normalized);
    } catch (_) {
      // Fallback
    }
    if (seq != _requestSeq) return;

    await _syncLocalization(state.locale, normalized, forceReload: true);
    if (seq != _requestSeq) return;

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
      LocalizationHelper.ensureServiceSynced();
      return;
    }

    final appLoc = AppLocalizations(
      locale,
      arabicDialect: effectiveDialect,
    );
    final success = await appLoc.load(
      syncGlobal: true,
      forceReload: forceReload,
    );
    if (!success || appLoc.localizedStrings.isEmpty) {
      await LocalizationHelper.load(
        locale.languageCode,
        arabicDialect: effectiveDialect,
        forceReload: forceReload,
      );
    }
  }
}
