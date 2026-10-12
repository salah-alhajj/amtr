import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../services/preferences_service.dart';
import 'theme_event.dart';
import 'theme_state.dart';

export 'theme_event.dart';
export 'theme_state.dart';

/// BLoC نقي لإدارة نمط مظهر التطبيق (تلقائي مع النظام / فاتح / داكن)
/// مع حفظ دائم لتفضيلات المستخدم عبر PreferencesService
class ThemeBloc extends Bloc<ThemeEvent, ThemeState> {
  final PreferencesService _preferencesService;

  ThemeBloc({PreferencesService? preferencesService})
      : _preferencesService = preferencesService ?? PreferencesService.instance,
        super(const ThemeState(themeMode: ThemeMode.system)) {
    on<LoadPersistedTheme>(_onLoadPersistedTheme);
    on<ChangeThemeMode>(_onChangeThemeMode);
  }

  Future<void> _onLoadPersistedTheme(
    LoadPersistedTheme event,
    Emitter<ThemeState> emit,
  ) async {
    await _preferencesService.init();
    final savedMode = _preferencesService.getThemeMode();
    emit(state.copyWith(themeMode: savedMode));
  }

  Future<void> _onChangeThemeMode(
    ChangeThemeMode event,
    Emitter<ThemeState> emit,
  ) async {
    if (state.themeMode == event.themeMode) return;
    await _preferencesService.setThemeMode(event.themeMode);
    emit(state.copyWith(themeMode: event.themeMode));
  }
}
