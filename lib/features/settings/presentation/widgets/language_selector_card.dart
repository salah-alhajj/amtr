import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// بطاقة اختيار لغة التطبيق بتصميم نمط أبل كقائمة منسدلة (Dropdown) مع أعلام الدول بصيغة SVG فائقة النقاء
class LanguageSelectorCard extends StatelessWidget {
  const LanguageSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, localeState) {
        final currentCode = localeState.locale.languageCode;

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: CountryFlagSvg.fromLanguageCode(
                      currentCode,
                      width: 24,
                      height: 18,
                      borderRadius: 3.5,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'language'.i18n(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'change_language'.i18n(),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceCard : context.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.borderDivider,
                    width: 1.0,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: AppLanguage.supported.any((l) => l.code == currentCode) ? currentCode : 'ar',
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.textSecondary,
                    ),
                    dropdownColor: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(14),
                    elevation: 4,
                    items: AppLanguage.supported.map((lang) {
                      final isSelected = lang.code == currentCode;
                      return DropdownMenuItem<String>(
                        value: lang.code,
                        child: Row(
                          children: [
                            CountryFlagSvg.fromLanguageCode(
                              lang.code,
                              width: 24,
                              height: 18,
                              borderRadius: 3.5,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              lang.nativeName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? AppColors.primaryBlue : context.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${lang.translationKey.i18n()})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected
                                    ? AppColors.primaryBlue.withValues(alpha: 0.8)
                                    : context.textSecondary,
                              ),
                            ),
                            const Spacer(),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (newCode) {
                      if (newCode != null && newCode != currentCode) {
                        context.read<LocaleBloc>().add(
                              ChangeLocale(Locale(newCode)),
                            );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
