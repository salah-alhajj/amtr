import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../core/widgets/country_flag_svg.dart';

/// بطاقة اختيار لغة التطبيق بتصميم نمط أبل مع أعلام الدول بصيغة SVG فائقة النقاء
class LanguageSelectorCard extends StatelessWidget {
  const LanguageSelectorCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LocaleBloc, LocaleState>(
      builder: (context, localeState) {
        final isArabic = localeState.isArabic;

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
                    child: isArabic
                        ? const CountryFlagSvg.sa(width: 24, height: 18, borderRadius: 3.5)
                        : const CountryFlagSvg.us(width: 24, height: 18, borderRadius: 3.5),
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
              Row(
                children: [
                  Expanded(
                    child: _LanguageOptionButton(
                      title: 'language_arabic_rtl'.i18n(),
                      flag: const DualArabFlagSvg(size: 16),
                      isSelected: isArabic,
                      onTap: () {
                        context.read<LocaleBloc>().add(
                              const ChangeLocale(Locale('ar')),
                            );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LanguageOptionButton(
                      title: 'language_english_ltr'.i18n(),
                      flag: const CountryFlagSvg.us(width: 22, height: 16, borderRadius: 3.5),
                      isSelected: !isArabic,
                      onTap: () {
                        context.read<LocaleBloc>().add(
                              const ChangeLocale(Locale('en')),
                            );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageOptionButton extends StatelessWidget {
  final String title;
  final Widget flag;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageOptionButton({
    required this.title,
    required this.flag,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : context.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : context.borderDivider,
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            flag,
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.primaryBlue : context.textPrimary,
                ),
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: AppColors.primaryBlue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
