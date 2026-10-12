import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// بطاقة بتصميم آبل الأنيق (Apple Surface Card) مع حواف دائرية وظل ناعم
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final Gradient? gradient;
  final double borderRadius;
  final List<BoxShadow>? boxShadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.gradient,
    this.borderRadius = 16,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard;
    final defaultBorder = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final defaultShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.02);

    final cardContent = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? defaultBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border ?? Border.all(color: defaultBorder, width: 0.8),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: defaultShadowColor,
                offset: const Offset(0, 2),
                blurRadius: 8,
              ),
            ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// بطاقة تفاعلية تنضغط بنعومة فائقة عند اللمس (Tactile Spring Scale Card)
class AppAnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Border? border;
  final Gradient? gradient;
  final double borderRadius;

  const AppAnimatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.border,
    this.gradient,
    this.borderRadius = 16,
  });

  @override
  State<AppAnimatedCard> createState() => _AppAnimatedCardState();
}

class _AppAnimatedCardState extends State<AppAnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null || widget.onLongPress != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: AppCard(
          padding: widget.padding,
          margin: widget.margin,
          backgroundColor: widget.backgroundColor,
          border: widget.border,
          gradient: widget.gradient,
          borderRadius: widget.borderRadius,
          onTap: widget.onTap,
          child: widget.child,
        ),
      ),
    );
  }
}

/// بطاقة بارزة فاخرة بتدرج آبل المشبع وظلال ملونة ناعمة (Apple Hero Card)
class AppHeroCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  const AppHeroCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding,
    this.margin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeGradient = gradient ?? AppColors.heroGradient;

    final content = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: activeGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007AFF).withValues(alpha: 0.25),
            offset: const Offset(0, 8),
            blurRadius: 20,
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// بطاقة تجمع عناصر متعددة مع فواصل أنيقة بأسلوب قائمة الإعدادات في iOS (Apple Grouped List Card)
class AppGroupedListCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const AppGroupedListCard({
    super.key,
    required this.children,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final defaultBorder = isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle;
    final defaultDivider = isDark ? AppColors.darkBorderDivider : AppColors.borderDivider;
    final defaultShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.02);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: defaultBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: defaultShadowColor,
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              Divider(
                height: 1,
                thickness: 0.8,
                indent: 16,
                endIndent: 16,
                color: defaultDivider,
              ),
          ],
        ],
      ),
    );
  }
}
