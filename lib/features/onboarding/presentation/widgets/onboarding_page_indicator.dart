import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// مؤشر صفحات أبل الانسيابي (Apple Morphing Page Indicator)
/// يتحول المؤشر النشط بسلاسة إلى شكل كبسولة (Pill) متدرجة الألوان
class OnboardingPageIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int>? onDotTapped;

  const OnboardingPageIndicator({
    super.key,
    required this.count,
    required this.activeIndex,
    this.onDotTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == activeIndex;

        return GestureDetector(
          onTap: () => onDotTapped?.call(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.fastOutSlowIn,
            margin: const EdgeInsets.symmetric(horizontal: 3.5),
            height: 7,
            width: isActive ? 24 : 7,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: isActive ? AppColors.appleGradient : null,
              color: isActive
                  ? null
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.12)),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
          ),
        );
      }),
    );
  }
}
