import 'package:flutter/material.dart';
import '../localization/localization.dart';
import '../theme/app_colors.dart';
import 'components/app_buttons.dart';

/// تنويعات مظهر الحالة الفارغة
enum EmptyStateVariant {
  page, // ملء الصفحة أو الشاشة
  section, // قسم مدمج داخل بطاقة أو ورقة منبثقة
  compact, // شريط مصغر مضغوط
}

/// ويدجت الحالة الفارغة العام بتصميم آبل الهادئ مع أنيميشن سلس وخيارات تخصيص شاملة
/// يدعم الحالات بدون إجراء (Without Action) أو بإجراء (With Action) أو بإجراءين
class EmptyStateView extends StatefulWidget {
  final IconData? icon;
  final Widget? illustration;
  final String title;
  final String? subtitle;
  final Widget? action;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final IconData? actionIcon;
  final Widget? secondaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryActionPressed;
  final EmptyStateVariant variant;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final EdgeInsetsGeometry? padding;
  final bool enableAnimation;

  const EmptyStateView({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.variant = EmptyStateVariant.page,
    this.iconColor,
    this.iconBackgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.padding,
    this.enableAnimation = true,
  }) : assert(
          icon != null || illustration != null,
          'يجب تمرير icon أو illustration على الأقل',
        );

  /// باني قسم مدمج (Section Empty State)
  const EmptyStateView.section({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.iconColor,
    this.iconBackgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    this.enableAnimation = true,
  })  : variant = EmptyStateVariant.section,
        assert(
          icon != null || illustration != null,
          'يجب تمرير icon أو illustration على الأقل',
        );

  /// باني شريط مصغر مضغوط (Compact Empty State)
  const EmptyStateView.compact({
    super.key,
    this.icon,
    this.illustration,
    required this.title,
    this.subtitle,
    this.action,
    this.actionLabel,
    this.onActionPressed,
    this.actionIcon,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.iconColor,
    this.iconBackgroundColor,
    this.titleStyle,
    this.subtitleStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.enableAnimation = false,
  })  : variant = EmptyStateVariant.compact,
        assert(
          icon != null || illustration != null,
          'يجب تمرير icon أو illustration على الأقل',
        );

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );

    _floatAnimation = Tween<double>(begin: 0.0, end: -6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.enableAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant EmptyStateView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableAnimation != oldWidget.enableAnimation) {
      if (widget.enableAnimation) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultIconBg = isDark
        ? AppColors.darkSurfaceMuted
        : AppColors.surfaceMuted;
    final defaultIconColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.textTertiary;

    final effectiveIconBg = widget.iconBackgroundColor ?? defaultIconBg;
    final effectiveIconColor = widget.iconColor ?? defaultIconColor;

    if (widget.variant == EmptyStateVariant.compact) {
      return _buildCompact(context, isDark, effectiveIconColor, effectiveIconBg);
    }

    final isSection = widget.variant == EmptyStateVariant.section;
    final badgeSize = isSection ? 58.0 : 78.0;
    final iconSize = isSection ? 30.0 : 40.0;

    return Center(
      child: Padding(
        padding: widget.padding ??
            EdgeInsets.symmetric(
              horizontal: isSection ? 16 : 28,
              vertical: isSection ? 22 : 36,
            ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, widget.enableAnimation ? _floatAnimation.value : 0),
                  child: child,
                );
              },
              child: widget.illustration ??
                  Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: effectiveIconBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.borderSubtle,
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: iconSize,
                        color: effectiveIconColor,
                      ),
                    ),
                  ),
            ),
            SizedBox(height: isSection ? 14 : 20),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: widget.titleStyle ??
                  TextStyle(
                    fontSize: isSection ? 15 : 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
            ),
            if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  widget.subtitle!,
                  textAlign: TextAlign.center,
                  style: widget.subtitleStyle ??
                      TextStyle(
                        fontSize: isSection ? 12 : 13,
                        height: 1.45,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textTertiary,
                      ),
                ),
              ),
            ],
            if (_hasAnyAction) ...[
              SizedBox(height: isSection ? 16 : 22),
              _buildActions(context, isSection),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasAnyAction =>
      widget.action != null ||
      widget.onActionPressed != null ||
      widget.secondaryAction != null ||
      widget.onSecondaryActionPressed != null;

  Widget _buildActions(BuildContext context, bool isSection) {
    if (widget.action != null &&
        widget.onActionPressed == null &&
        widget.secondaryAction == null &&
        widget.secondaryActionLabel == null) {
      return widget.action!;
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        if (widget.onActionPressed != null)
          AppPrimaryButton(
            label: widget.actionLabel ?? (context.isArabic ? 'متابعة' : 'Continue'),
            icon: widget.actionIcon,
            onPressed: widget.onActionPressed,
            height: isSection ? 42 : 46,
            borderRadius: 12,
          )
        else if (widget.action != null)
          widget.action!,
        if (widget.secondaryAction != null)
          widget.secondaryAction!
        else if (widget.secondaryActionLabel != null &&
            widget.onSecondaryActionPressed != null)
          AppSecondaryButton(
            label: widget.secondaryActionLabel!,
            onPressed: widget.onSecondaryActionPressed,
            height: isSection ? 42 : 46,
            borderRadius: 12,
          ),
      ],
    );
  }

  Widget _buildCompact(
    BuildContext context,
    bool isDark,
    Color iconColor,
    Color iconBg,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          if (widget.icon != null)
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: 18, color: iconColor),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (widget.onActionPressed != null)
            AppSecondaryButton(
              onPressed: widget.onActionPressed,
              label: widget.actionLabel ?? (context.isArabic ? 'إجراء' : 'Action'),
              height: 36,
            )
          else if (widget.action != null)
            widget.action!,
        ],
      ),
    );
  }
}

