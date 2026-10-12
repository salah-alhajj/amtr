import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/bloc/theme_bloc.dart';
import '../../../../core/widgets/design_system.dart';

/// بطاقة اختيار نمط المظهر بتصميم آبل (Apple Theme Selector Card)
/// تتيح للمستخدم التبديل السلس بين:
/// 1. تلقائي حسب إعدادات النظام (System)
/// 2. النمط الفاتح (Light)
/// 3. النمط الداكن (Dark)
/// مع حفظ دائم للتفضيلات وتأكيد بصري تفاعلي.
class ThemeSelectorCard extends StatelessWidget {
  const ThemeSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ThemeBloc, ThemeState>(
      builder: (context, themeState) {
        final activeMode = themeState.themeMode;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ترويسة بطاقة المظهر
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _t('theme_settings'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _t('theme_mode'),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // خيارات الأنماط الثلاثة بتصميم مجزء (Segmented Apple Selector)
              Row(
                children: [
                  Expanded(
                    child: _ThemeOptionTile(
                      title: _t('theme_system'),
                      icon: Icons.smartphone_rounded,
                      isSelected: activeMode == ThemeMode.system,
                      isDarkTheme: isDark,
                      onTap: () {
                        context
                            .read<ThemeBloc>()
                            .add(const ChangeThemeMode(ThemeMode.system));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeOptionTile(
                      title: _t('theme_light'),
                      icon: Icons.light_mode_rounded,
                      isSelected: activeMode == ThemeMode.light,
                      isDarkTheme: isDark,
                      onTap: () {
                        context
                            .read<ThemeBloc>()
                            .add(const ChangeThemeMode(ThemeMode.light));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ThemeOptionTile(
                      title: _t('theme_dark'),
                      icon: Icons.dark_mode_rounded,
                      isSelected: activeMode == ThemeMode.dark,
                      isDarkTheme: isDark,
                      onTap: () {
                        context
                            .read<ThemeBloc>()
                            .add(const ChangeThemeMode(ThemeMode.dark));
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // صندوق توضيحي لسلوك النمط المختار
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted)
                      .withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderSubtle : AppColors.borderDivider,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getDescriptionForMode(activeMode),
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _t(String key) {
    final tr = key.i18n();
    return (tr == key) ? LocalizationHelper.translate(key) : tr;
  }

  String _getDescriptionForMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return _t('theme_system_desc');
      case ThemeMode.light:
        return _t('theme_light_desc');
      case ThemeMode.dark:
        return _t('theme_dark_desc');
    }
  }
}

class _ThemeOptionTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final bool isDarkTheme;
  final VoidCallback onTap;

  const _ThemeOptionTile({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.isDarkTheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDarkTheme ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final unselectedBg = isDarkTheme ? AppColors.darkSurfaceMuted : AppColors.surfaceWhite;
    final unselectedBorder = isDarkTheme ? AppColors.darkBorderSubtle : AppColors.borderDivider;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.12) : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? activeColor : unselectedBorder,
            width: isSelected ? 1.6 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.18),
                    offset: const Offset(0, 2),
                    blurRadius: 6,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected
                      ? activeColor
                      : (isDarkTheme ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
                if (isSelected)
                  Positioned(
                    top: -2,
                    right: -6,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? activeColor
                    : (isDarkTheme ? AppColors.darkTextPrimary : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
