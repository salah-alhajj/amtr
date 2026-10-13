import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// ويدجت موحدة لعرض شعار تطبيق مساعد (Mosaed)
/// تدعم الحجم المخصص، الشفافية، والشكل الجمالي وفق إرشادات آبل وجوجل
class AppLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool isTransparent;
  final bool showShadow;
  final VoidCallback? onTap;

  const AppLogo({
    super.key,
    this.size = 48,
    this.borderRadius,
    this.isTransparent = true,
    this.showShadow = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? (size * 0.22);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget imageWidget = Image.asset(
      'assets/icons/amtr_audit_icon.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: size,
          height: size,
          color: AppColors.primaryBlue,
          alignment: Alignment.center,
          child: Text(
            'Mosaed',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.24,
            ),
          ),
        );
      },
    );

    Widget content = effectiveRadius > 0
        ? ClipRRect(
            borderRadius: BorderRadius.circular(effectiveRadius),
            child: imageWidget,
          )
        : imageWidget;

    if (!isTransparent) {
      content = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceCard : Colors.white,
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
            width: 0.8,
          ),
          boxShadow: showShadow
              ? [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : AppColors.primaryBlue.withValues(alpha: 0.12),
                    offset: Offset(0, size * 0.08),
                    blurRadius: size * 0.25,
                    spreadRadius: -1,
                  ),
                ]
              : null,
        ),
        child: content,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
