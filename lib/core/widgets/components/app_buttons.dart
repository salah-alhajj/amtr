import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// زر أساسي بتصميم آبل وتأثير النبض الفيزيائي الناعم (Spring Micro-interaction)
class AppPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? customIcon;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? textColor;
  final Gradient? gradient;
  final double? width;
  final double height;
  final double borderRadius;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.customIcon,
    this.isLoading = false,
    this.backgroundColor,
    this.textColor,
    this.gradient,
    this.width,
    this.height = 50,
    this.borderRadius = 14,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final defaultBg = widget.backgroundColor ?? AppColors.primaryBlue;
    final defaultText = widget.textColor ?? Colors.white;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.gradient == null
                ? (isEnabled ? defaultBg : defaultBg.withValues(alpha: 0.4))
                : null,
            gradient: isEnabled ? widget.gradient : null,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: (widget.backgroundColor ?? AppColors.primaryBlue)
                          .withValues(alpha: 0.25),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? widget.onPressed : null,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator.adaptive(
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                          strokeWidth: 2.2,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.customIcon != null) ...[
                            widget.customIcon!,
                            const SizedBox(width: 8),
                          ] else if (widget.icon != null) ...[
                            Icon(widget.icon, color: defaultText, size: 18),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: defaultText,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// زر ثانوي ناعم بتدرج خفيف (Apple Tinted Button)
class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? customIcon;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;

  const AppSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.customIcon,
    this.color,
    this.width,
    this.height = 46,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? AppColors.primaryBlue;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (customIcon != null) ...[
                  customIcon!,
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  Icon(icon, color: baseColor, size: 17),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر محدد بحد رفيع ناعم (Apple Outlined Button)
class AppOutlinedButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? customIcon;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;

  const AppOutlinedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.customIcon,
    this.color,
    this.width,
    this.height = 46,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? context.textPrimary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: (color ?? context.borderSubtle).withValues(alpha: 0.8),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (customIcon != null) ...[
                  customIcon!,
                  const SizedBox(width: 6),
                ] else if (icon != null) ...[
                  Icon(icon, color: baseColor, size: 16),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// زر أيقونة دائري أو بيضاوي ناعم مع لمس فيزيائي (Apple Icon Button)
class AppIconButton extends StatelessWidget {
  final IconData? icon;
  final Widget? customIcon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final String? tooltip;

  const AppIconButton({
    super.key,
    this.icon,
    this.customIcon,
    required this.onPressed,
    this.color,
    this.backgroundColor,
    this.size = 40,
    this.iconSize = 18,
    this.tooltip,
  }) : assert(icon != null || customIcon != null, 'Either icon or customIcon must be provided');

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? context.textPrimary;
    final bg = backgroundColor ?? context.surfaceMuted;

    final btn = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Center(
            child: customIcon ?? Icon(icon, color: iconColor, size: iconSize),
          ),
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: btn);
    }
    return btn;
  }
}

/// خيارات أنماط الأزرار الموحدة
enum AppButtonVariant { primary, secondary, ghost, danger }

/// أحجام الأزرار الموحدة
enum AppButtonSize { small, medium, large }

/// زر عام موحد يدعم الأنماط والأحجام المختلفة بتصميم آبل
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final double height = switch (size) {
      AppButtonSize.small => 36,
      AppButtonSize.large => 54,
      AppButtonSize.medium => 46,
    };

    switch (variant) {
      case AppButtonVariant.secondary:
        return AppSecondaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          height: height,
        );
      case AppButtonVariant.ghost:
        return AppOutlinedButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          height: height,
        );
      case AppButtonVariant.danger:
        return AppPrimaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          backgroundColor: AppColors.statusDanger,
          height: height,
        );
      case AppButtonVariant.primary:
        return AppPrimaryButton(
          label: label,
          onPressed: onPressed,
          icon: icon,
          isLoading: isLoading,
          height: height,
        );
    }
  }
}
