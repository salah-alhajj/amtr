import 'package:flutter/material.dart';

abstract class ThemeEvent {
  const ThemeEvent();
}

/// حدث قراءة وتحميل نمط المظهر المحفوظ من التفضيلات المحلية
class LoadPersistedTheme extends ThemeEvent {
  const LoadPersistedTheme();
}

/// حدث تغيير نمط المظهر وتطبيقه وحفظه
class ChangeThemeMode extends ThemeEvent {
  final ThemeMode themeMode;
  const ChangeThemeMode(this.themeMode);
}
