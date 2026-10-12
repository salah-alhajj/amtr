import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';

/// ترويسة بطابع آبل الأنيق تعرض هوية التطبيق، شعاره، وإحصائيات ميزاته الأساسية
class AppHeroHeader extends StatelessWidget {
  const AppHeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : AppColors.primaryBlue.withValues(alpha: 0.06),
            offset: const Offset(0, 8),
            blurRadius: 24,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // أيقونة التطبيق الرسمية وفق إرشادات آبل
          const AppLogo(
            size: 80,
            borderRadius: 22,
          ),
          const SizedBox(height: 16),

          // اسم التطبيق
          Text(
            'app_name'.i18n(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),

          // الشعار العام
          Text(
            'app_tagline'.i18n(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),

          // شارة الإصدار والعمل المحلي بدون إنترنت
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppPulsingDot(
                      color: AppColors.primaryGreen,
                      size: 6,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'about_app_badge'.i18n(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorderDivider : AppColors.borderDivider,
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'drawer_version_offline'.i18n(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ركائز التطبيق الأربع السريعة للمستخدم العادي
          Row(
            children: [
              _buildPillarChip(
                context,
                icon: Icons.inventory_2_rounded,
                label: 'about_app_stats_orders'.i18n(),
                color: AppColors.primaryBlue,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildPillarChip(
                context,
                icon: Icons.local_shipping_rounded,
                label: 'about_app_stats_shipments'.i18n(),
                color: AppColors.primaryGreen,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildPillarChip(
                context,
                icon: Icons.people_alt_rounded,
                label: 'about_app_stats_customers'.i18n(),
                color: AppColors.vibrantTeal,
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildPillarChip(
                context,
                icon: Icons.wifi_off_rounded,
                label: 'about_app_stats_offline'.i18n(),
                color: const Color(0xFF8B5CF6),
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillarChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
