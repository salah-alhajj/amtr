import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// شارة حالة بيضاوية بتصميم آبل (Apple Status Badge) مع لون نص غني وخلفية ناعمة
class AppBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const AppBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.6,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// رقاقة تصفية تفاعلية بأسلوب آبل (Apple Filter Chip)
class AppFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final Color? activeColor;
  final int? count;
  final bool showColoredUnselected;
  final Widget? customIcon;

  const AppFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onSelected,
    this.icon,
    this.customIcon,
    Color? activeColor,
    Color? color,
    this.count,
    this.showColoredUnselected = true,
  }) : activeColor = activeColor ?? color;

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.primaryBlue;

    // تحديد ألوان البطاقة بناء على الحالة والتخصيص
    final Color bgColor;
    final Color borderColor;
    final Color iconColor;
    final Color textColor;

    if (isSelected) {
      bgColor = color;
      borderColor = color;
      iconColor = Colors.white;
      textColor = Colors.white;
    } else if (showColoredUnselected && activeColor != null) {
      bgColor = color.withValues(alpha: 0.08);
      borderColor = color.withValues(alpha: 0.35);
      iconColor = color;
      textColor = context.textPrimary;
    } else {
      bgColor = context.surfaceCard;
      borderColor = context.borderSubtle;
      iconColor = context.textSecondary;
      textColor = context.textPrimary;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelected != null ? () => onSelected!(!isSelected) : null,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          alignment: Alignment.center,
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.2 : 0.9,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (customIcon != null) ...[
                customIcon!,
                const SizedBox(width: 5),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 15,
                  color: iconColor,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// نقطة نابضة متوهجة تعبر عن حالة التشغيل والاتصال (Pulsing Status Indicator)
class AppPulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const AppPulsingDot({
    super.key,
    this.color = AppColors.primaryGreen,
    this.size = 8,
  });

  @override
  State<AppPulsingDot> createState() => _AppPulsingDotState();
}

class _AppPulsingDotState extends State<AppPulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _opacityAnimation = Tween<double>(begin: 0.7, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.4,
      height: widget.size * 2.4,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: _opacityAnimation.value),
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
