import 'package:flutter/material.dart';
import '../../localization/localization.dart';
import '../../theme/app_colors.dart';
import 'app_buttons.dart';

/// هيكل ورقة سفلية موحدة بتصميم آبل (Apple Style Modal Bottom Sheet)
class AppModalSheet extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const AppModalSheet({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final defaultTextColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final defaultSubtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final defaultDivider = isDark ? AppColors.darkBorderDivider : AppColors.borderDivider;

    return Container(
      padding: padding ??
          EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
      decoration: BoxDecoration(
        color: defaultBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // مقبض سحب iOS
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: defaultDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: defaultTextColor,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 11,
                            color: defaultSubtextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            Divider(height: 20, color: defaultDivider),
          ] else
            const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// صندوق حوار تأكيد أنيق بأسلوب آبل (Apple Confirmation Dialog)
class AppConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? confirmLabel;
  final String? cancelLabel;
  final VoidCallback onConfirm;
  final bool isDestructive;

  const AppConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel,
    this.cancelLabel,
    required this.onConfirm,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite;
    final defaultTextColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final defaultSubtextColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final defaultPrimary = isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    final defaultDanger = isDark ? AppColors.darkStatusDanger : AppColors.statusDanger;

    final resolvedConfirm = confirmLabel ?? 'common_confirm'.i18n();
    final resolvedCancel = cancelLabel ?? 'common_cancel'.i18n();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: defaultBg,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDestructive ? defaultDanger : defaultPrimary)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDestructive ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                  color: isDestructive ? defaultDanger : defaultPrimary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: defaultTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: defaultSubtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    label: resolvedCancel,
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppPrimaryButton(
                    label: resolvedConfirm,
                    backgroundColor: isDestructive ? AppColors.statusDanger : AppColors.primaryBlue,
                    onPressed: () {
                      Navigator.pop(context, true);
                      onConfirm();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// دالة مساعدة لفتح ورقة سفلية موحدة بتصميم آبل
Future<T?> showAppModalSheet<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  String? subtitle,
  Widget? trailing,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AppModalSheet(
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      child: child,
    ),
  );
}

/// دالة مساعدة لفتح صندوق حوار تأكيد موحد
Future<bool?> showAppConfirmationDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool isDestructive = false,
  VoidCallback? onConfirm,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AppConfirmationDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      isDestructive: isDestructive,
      onConfirm: () {
        onConfirm?.call();
      },
    ),
  );
}
