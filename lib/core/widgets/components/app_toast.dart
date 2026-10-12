import 'dart:async';
import 'package:flutter/material.dart';
import '../../localization/localization.dart';
import '../../theme/app_colors.dart';

/// أنواع التوست الأساسية المتاحة في النظام الموحد
enum AppToastType {
  success,
  error,
  warning,
  info,
}

/// موضع ظهور التوست على الشاشة
enum AppToastPosition {
  top,
  bottom,
}

/// نظام التوست والإشعارات المنبثقة الموحد (AMTR Unified Toast & In-App Notification System)
/// مصمم وفق إرشادات آبل للتصميم (Apple HIG) مع تأثيرات زجاجية ناعمة، حدود دقيقة،
/// وانسيابية كاملة، مع دعم تام لاتجاه النصوص العربية RTL والوضع الداكن والفاتح.
class AppToast {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  /// إظهار توست نجاح (Success Toast)
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'toast_title_success'.i18n(),
      type: AppToastType.success,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// إظهار توست خطأ (Error Toast)
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 4000),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'toast_title_error'.i18n(),
      type: AppToastType.error,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// اختصار مباشر لـ showError
  static void error(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 4000),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) => showError(
    context,
    message,
    title: title,
    duration: duration,
    position: position,
    onTap: onTap,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// اختصار مباشر لـ showSuccess
  static void success(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 2500),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) => showSuccess(
    context,
    message,
    title: title,
    duration: duration,
    position: position,
    onTap: onTap,
    actionLabel: actionLabel,
    onAction: onAction,
  );

  /// إظهار توست تنبيه (Warning Toast)
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'toast_title_warning'.i18n(),
      type: AppToastType.warning,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// إظهار توست معلومات (Info Toast)
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    show(
      context,
      message: message,
      title: title ?? 'toast_title_info'.i18n(),
      type: AppToastType.info,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  /// إظهار توست مخصص متكامل مع كافة خيارات التخصيص
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    AppToastType type = AppToastType.info,
    IconData? customIcon,
    Duration duration = const Duration(milliseconds: 3200),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    dismiss();

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (ctx) => _AppToastWidget(
        title: title,
        message: message,
        type: type,
        customIcon: customIcon,
        position: position,
        duration: duration,
        onTap: onTap,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissed: dismiss,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);

    _dismissTimer = Timer(duration, () {
      dismiss();
    });
  }

  /// إغلاق وإزالة التوست النشط حالياً
  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

/// ودجت التوست المنبثق مع الأنيميشن والمؤثرات البصرية الفاخرة
class _AppToastWidget extends StatefulWidget {
  final String? title;
  final String message;
  final AppToastType type;
  final IconData? customIcon;
  final AppToastPosition position;
  final Duration duration;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onDismissed;

  const _AppToastWidget({
    required this.title,
    required this.message,
    required this.type,
    this.customIcon,
    required this.position,
    required this.duration,
    this.onTap,
    this.actionLabel,
    this.onAction,
    required this.onDismissed,
  });

  @override
  State<_AppToastWidget> createState() => _AppToastWidgetState();
}

class _AppToastWidgetState extends State<_AppToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final beginOffset = widget.position == AppToastPosition.top
        ? const Offset(0, -0.6)
        : const Offset(0, 0.6);

    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    ));

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  Future<void> _handleDismiss() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismissed();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Color _getTypeColor(bool isDark) {
    switch (widget.type) {
      case AppToastType.success:
        return AppColors.primaryGreen;
      case AppToastType.error:
        return isDark ? AppColors.darkStatusDanger : AppColors.statusDanger;
      case AppToastType.warning:
        return isDark ? AppColors.darkStatusWarning : AppColors.statusWarning;
      case AppToastType.info:
        return isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue;
    }
  }

  IconData _getTypeIcon() {
    if (widget.customIcon != null) return widget.customIcon!;
    switch (widget.type) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.error:
        return Icons.error_outline_rounded;
      case AppToastType.warning:
        return Icons.warning_amber_rounded;
      case AppToastType.info:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(isDark);
    final iconData = _getTypeIcon();

    final safePadding = widget.position == AppToastPosition.top
        ? mediaQuery.padding.top + 12
        : mediaQuery.padding.bottom + 20;

    return Positioned(
      top: widget.position == AppToastPosition.top ? safePadding : null,
      bottom: widget.position == AppToastPosition.bottom ? safePadding : null,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dismissible(
              key: UniqueKey(),
              direction: widget.position == AppToastPosition.top
                  ? DismissDirection.up
                  : DismissDirection.down,
              onDismissed: (_) => widget.onDismissed(),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xF01C1C1E)
                        : Colors.white.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: typeColor.withValues(alpha: isDark ? 0.35 : 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: typeColor.withValues(alpha: isDark ? 0.22 : 0.12),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: widget.onTap != null
                          ? () {
                              _handleDismiss();
                              widget.onTap!();
                            }
                          : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // أيقونة النوع في كبسولة أنيقة
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: isDark ? 0.20 : 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                iconData,
                                color: typeColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // النصوص (العنوان والرسالة)
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.title != null && widget.title!.isNotEmpty) ...[
                                    Text(
                                      widget.title!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? AppColors.darkTextPrimary
                                            : AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                  ],
                                  Text(
                                    widget.message,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                      height: 1.35,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // زر الإجراء السريع (إن وجد)
                            if (widget.actionLabel != null && widget.onAction != null) ...[
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  _handleDismiss();
                                  widget.onAction!();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  backgroundColor: typeColor.withValues(alpha: 0.12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  widget.actionLabel!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                              ),
                            ],

                            // زر الإغلاق الناعم
                            const SizedBox(width: 6),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.textTertiary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 16,
                              onPressed: _handleDismiss,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ملحق على BuildContext لسرعة وسهولة إظهار التوست
extension AppToastContextExtension on BuildContext {
  void showSuccessToast(
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.showSuccess(
      this,
      message,
      title: title,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void showErrorToast(
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 4000),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.showError(
      this,
      message,
      title: title,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void showWarningToast(
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3500),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.showWarning(
      this,
      message,
      title: title,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }

  void showInfoToast(
    String message, {
    String? title,
    Duration duration = const Duration(milliseconds: 3200),
    AppToastPosition position = AppToastPosition.top,
    VoidCallback? onTap,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    AppToast.showInfo(
      this,
      message,
      title: title,
      duration: duration,
      position: position,
      onTap: onTap,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
