import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../apple_widgets.dart';

/// ترويسة قسم موحدة تتبع إرشادات آبل للتصميم مع دعم كامل لاتجاه RTL
class AppSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionTitle;
  final VoidCallback? onActionTap;
  final IconData? actionIcon;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionTitle,
    this.onActionTap,
    this.actionIcon,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (actionTitle != null && onActionTap != null)
            GestureDetector(
              onTap: onActionTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionTitle!,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 4),
                    actionIcon != null
                        ? Icon(actionIcon, size: 13, color: AppColors.primaryBlue)
                        : const ForwardChevron(size: 13, color: AppColors.primaryBlue),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ترويسة صفحة رئيسية بنمط Large Title من آبل مع أزرار الإجراءات وحالات الدعم
class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: context.textPrimary,
                  ),
                ),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// شريط تنبيه وإشعار مصقول (Banner) بتصميم آبل المندمج
class AppStatusBanner extends StatelessWidget {
  final String message;
  final String? title;
  final IconData icon;
  final Color tintColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const AppStatusBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.tintColor = AppColors.primaryBlue,
    this.onTap,
    this.trailing,
  });

  const AppStatusBanner.warning({
    super.key,
    required this.message,
    this.title,
    this.onTap,
    this.trailing,
  })  : icon = Icons.warning_amber_rounded,
        tintColor = AppColors.statusWarning;

  const AppStatusBanner.success({
    super.key,
    required this.message,
    this.title,
    this.onTap,
    this.trailing,
  })  : icon = Icons.check_circle_outline_rounded,
        tintColor = AppColors.statusSuccess;

  const AppStatusBanner.error({
    super.key,
    required this.message,
    this.title,
    this.onTap,
    this.trailing,
  })  : icon = Icons.error_outline_rounded,
        tintColor = AppColors.statusDanger;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: tintColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: tintColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: tintColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null) ...[
                        Text(
                          title!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: tintColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
