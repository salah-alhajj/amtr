import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../widgets/app_hero_header.dart';
import '../widgets/developer_profile_card.dart';
import '../widgets/feature_highlight_card.dart';

/// شاشة التعريف الشاملة بالتطبيق ومميزاته ومطوره
/// صُممت بمحتوى مبسط وواضح موجه للمستخدم العادي والتجار
class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // مراقبة تغيير اللغة للتحديث الفوري للواجهة
    context.watch<LocaleBloc>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkScaffoldBackground : AppColors.scaffoldBackground,
      appBar: AppBar(
        title: Text('about_app_title'.i18n()),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ترويسة التطبيق والهوية البصرية
            const AppHeroHeader(),

            const SizedBox(height: 20),

            // بطاقة نبذة عن التطبيق والهدف منه (للمستخدم العادي)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.02),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primaryBlue,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'about_app_overview_title'.i18n(),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'about_app_overview_desc'.i18n(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // عنوان قسم مميزات التطبيق
            _buildSectionHeader(
              title: 'about_app_features_section_title'.i18n(),
              subtitle: 'about_app_features_section_subtitle'.i18n(),
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // قائمة ميزات التطبيق الموجهة للمستخدم العادي (7 ميزات عملية)
            FeatureHighlightCard(
              icon: Icons.inventory_2_rounded,
              title: 'feat_orders_title'.i18n(),
              description: 'feat_orders_desc'.i18n(),
              accentColor: const Color(0xFF007AFF),
            ),
            FeatureHighlightCard(
              icon: Icons.local_shipping_rounded,
              title: 'feat_shipments_title'.i18n(),
              description: 'feat_shipments_desc'.i18n(),
              accentColor: const Color(0xFF059669),
            ),
            FeatureHighlightCard(
              icon: Icons.people_alt_rounded,
              title: 'feat_customers_title'.i18n(),
              description: 'feat_customers_desc'.i18n(),
              accentColor: const Color(0xFFD97706),
            ),
            FeatureHighlightCard(
              icon: Icons.currency_exchange_rounded,
              title: 'feat_currencies_title'.i18n(),
              description: 'feat_currencies_desc'.i18n(),
              accentColor: const Color(0xFF7C3AED),
            ),
            FeatureHighlightCard(
              icon: Icons.picture_as_pdf_rounded,
              title: 'feat_pdf_title'.i18n(),
              description: 'feat_pdf_desc'.i18n(),
              accentColor: const Color(0xFFE11D48),
            ),
            FeatureHighlightCard(
              icon: Icons.shield_rounded,
              title: 'feat_offline_title'.i18n(),
              description: 'feat_offline_desc'.i18n(),
              accentColor: const Color(0xFF0F766E),
            ),
            FeatureHighlightCard(
              icon: Icons.cloud_sync_rounded,
              title: 'feat_backup_title'.i18n(),
              description: 'feat_backup_desc'.i18n(),
              accentColor: const Color(0xFF2563EB),
            ),

            const SizedBox(height: 20),

            // عنوان قسم المطور
            _buildSectionHeader(
              title: 'about_dev_section_title'.i18n(),
              subtitle: 'Salah aldain alhajj - App Creator',
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // بطاقة المطور صلاح الدين الحاج
            const DeveloperProfileCard(),

            const SizedBox(height: 28),

            // تذييل الصفحة وحقوق الملكية
            Center(
              child: Column(
                children: [
                  Text(
                    'about_app_copyright'.trParams({
                      'year': DateTime.now().year.toString(),
                    }),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'drawer_sqlite_offline'.i18n(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
