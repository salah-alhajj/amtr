import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// سهم التقدم للأمام في بيئة الـ RTL (يشير حتماً لليسار طبقاً لتدفق اللغة العربية)
class ForwardChevron extends StatelessWidget {
  final Color? color;
  final double size;

  const ForwardChevron({super.key, this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // في واجهات RTL، الانتقال للأمام والاستمرار يكون دوماً لليسار (←)
    // وفي واجهات LTR يكون لليمين (→)
    // استخدام arrow_forward_ios_rounded مع matchTextDirection: true يحقق هذا السلوك تلقائياً
    return Icon(
      Icons.arrow_forward_ios_rounded,
      size: size,
      color:
          color ??
          (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
    );
  }
}

class BackChevron extends StatelessWidget {
  final Color? color;
  final double size;

  const BackChevron({super.key, this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // في واجهات RTL، الانتقال للأمام والاستمرار يكون دوماً لليسار (←)
    // وفي واجهات LTR يكون لليمين (→)
    // استخدام arrow_back_rounded مع matchTextDirection: true يحقق هذا السلوك تلقائياً
    return Icon(
      Icons.arrow_back_ios_rounded,
      size: size,
      color:
          color ??
          (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
    );
  }
}

/// بطاقة بتصميم آبل الأنيق (Apple Surface Card) مع حواف دائرية وظل ناعم
class AppleCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Border? border;
  final Gradient? gradient;

  const AppleCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.border,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.surfaceCard;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.02);

    final cardContent = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: gradient == null ? (backgroundColor ?? defaultBg) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: border ?? Border.all(color: defaultBorder, width: 0.8),
        boxShadow: [
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
          borderRadius: BorderRadius.circular(16),
          child: cardContent,
        ),
      );
    }

    return cardContent;
  }
}

/// شارة أنيقة على طراز iOS Pills
class AppleBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppleBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// نقطة نبض متحركة تدل على الحيوية والنشاط المباشر
class PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingStatusDot({
    super.key,
    this.color = AppColors.primaryGreen,
    this.size = 8,
  });

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 2.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(
                      alpha: _opacityAnimation.value,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة آبل تفاعلية مع أنيميشن عند اللمس والدخول
class AnimatedAppleCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final Gradient? gradient;
  final Border? border;

  const AnimatedAppleCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.gradient,
    this.border,
  });

  @override
  State<AnimatedAppleCard> createState() => _AnimatedAppleCardState();
}

class _AnimatedAppleCardState extends State<AnimatedAppleCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark
        ? AppColors.darkSurfaceCard
        : AppColors.surfaceCard;
    final defaultBorder = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.borderSubtle;
    final defaultShadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.03);

    final card = Container(
      margin: widget.margin,
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.gradient == null
            ? (widget.backgroundColor ?? defaultBg)
            : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(16),
        border: widget.border ?? Border.all(color: defaultBorder, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: defaultShadowColor,
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) => _pressController.reverse(),
      onTapCancel: () => _pressController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: card);
        },
      ),
    );
  }
}
