import 'package:flutter/material.dart';
import '../localization/localization.dart';
import '../theme/app_colors.dart';
import 'components/app_buttons.dart';

/// تنويعات مظهر حالة الخطأ
enum ErrorStateVariant {
  page, // صفحة كاملة متمركزة (شاشة رئيسية أو صفحة تفاصيل)
  section, // قسم مدمج داخل بطاقة أو ورقة سفلية (Card / Bottom Sheet)
  compact, // شريط مصغر مضغوط للأخطاء السريعة
}

/// ويدجت حالة الخطأ الموحد بتصميم آبل والهوية البصرية لـ AMTR
/// يدعم أنيميشن ناعم وسلس (Soft Gentle Pulse Entrance)، مع خيارات تخصيص غير محدودة
class AppErrorStateView extends StatefulWidget {
  final String? title;
  final String? message;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData retryIcon;
  final Widget? secondaryAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryActionPressed;
  final ErrorStateVariant variant;
  final EdgeInsetsGeometry? padding;
  final Widget? customContent;

  const AppErrorStateView({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
    this.iconBackgroundColor,
    this.onRetry,
    this.retryLabel,
    this.retryIcon = Icons.refresh_rounded,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.variant = ErrorStateVariant.page,
    this.padding,
    this.customContent,
  });

  /// باني قسم مدمج (Section Error)
  const AppErrorStateView.section({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.error_outline_rounded,
    this.iconColor,
    this.iconBackgroundColor,
    this.onRetry,
    this.retryLabel,
    this.retryIcon = Icons.refresh_rounded,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
    this.customContent,
  }) : variant = ErrorStateVariant.section;

  /// باني شريط مصغر (Compact Banner Error)
  const AppErrorStateView.compact({
    super.key,
    this.title,
    this.message,
    this.icon = Icons.warning_amber_rounded,
    this.iconColor,
    this.iconBackgroundColor,
    this.onRetry,
    this.retryLabel,
    this.retryIcon = Icons.refresh_rounded,
    this.secondaryAction,
    this.secondaryActionLabel,
    this.onSecondaryActionPressed,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    this.customContent,
  }) : variant = ErrorStateVariant.compact;

  @override
  State<AppErrorStateView> createState() => _AppErrorStateViewState();
}

class _AppErrorStateViewState extends State<AppErrorStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const ElasticOutCurve(0.85),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dangerColor = isDark ? AppColors.darkStatusDanger : AppColors.statusDanger;

    final effectiveIconColor = widget.iconColor ?? dangerColor;
    final effectiveIconBg = widget.iconBackgroundColor ??
        dangerColor.withValues(alpha: isDark ? 0.16 : 0.08);

    if (widget.variant == ErrorStateVariant.compact) {
      return _buildCompact(context, isDark, effectiveIconColor, effectiveIconBg);
    }

    final isSection = widget.variant == ErrorStateVariant.section;
    final badgeSize = isSection ? 54.0 : 72.0;
    final iconSize = isSection ? 28.0 : 36.0;

    return Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: widget.padding ??
              EdgeInsets.symmetric(
                horizontal: isSection ? 16 : 28,
                vertical: isSection ? 20 : 36,
              ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: badgeSize,
                  height: badgeSize,
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: effectiveIconColor.withValues(alpha: 0.18),
                      width: 1.5,
                    ),
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
                widget.title ?? 'حدث خطأ أثناء تحميل البيانات',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isSection ? 15 : 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              if (widget.message != null && widget.message!.isNotEmpty) ...[
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    widget.message!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSection ? 12 : 13,
                      height: 1.45,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
              if (widget.customContent != null) ...[
                const SizedBox(height: 16),
                widget.customContent!,
              ],
              if (widget.onRetry != null ||
                  widget.secondaryAction != null ||
                  widget.secondaryActionLabel != null) ...[
                SizedBox(height: isSection ? 16 : 24),
                _buildActionButtons(context, isSection),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isSection) {
    final resolvedRetryLabel = widget.retryLabel ?? 'common_retry'.i18n();

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        if (widget.onRetry != null)
          AppPrimaryButton(
            label: resolvedRetryLabel,
            icon: widget.retryIcon,
            onPressed: widget.onRetry,
            height: isSection ? 42 : 46,
            width: isSection ? 150 : 180,
            borderRadius: 12,
          ),
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
    final resolvedRetryLabel = widget.retryLabel ?? 'common_retry'.i18n();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.25),
          width: 0.9,
        ),
      ),
      child: Row(
        children: [
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
            child: Text(
              widget.message ?? widget.title ?? 'common_error'.i18n(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(widget.retryIcon, size: 20, color: AppColors.primaryBlue),
              tooltip: resolvedRetryLabel,
              onPressed: widget.onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
    );
  }
}
