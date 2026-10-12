import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';

/// بطاقة تعريفية مصقولة بمطور التطبيق: المهندس صلاح الدين الحاج (Salah aldain alhajj)
class DeveloperProfileCard extends StatelessWidget {
  const DeveloperProfileCard({super.key});

  Future<void> _shareApp(BuildContext context) async {
    final text = 'about_dev_share_text'.i18n();
    try {
      final box = context.findRenderObject() as RenderBox?;
      final origin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      await SharePlus.instance.share(
        ShareParams(
          text: text,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        AppToast.showInfo(context, text);
      }
    }
  }

  Future<void> _contactViaWhatsApp(BuildContext context) async {
    // رابط رسالة واتساب مباشرة للتواصل مع المطور
    const whatsappUrl = 'https://wa.me/?text=%D9%85%D8%B1%D8%AD%D8%A8%D8%A7%D9%8B%20%D9%85%D9%87%D9%86%D8%AF%D8%B3%20%D8%B5%D9%84%D8%A7%D8%AD%20%D8%A7%D9%84%D8%AF%D9%8A%D9%86%D8%8C%20%D8%A3%D8%AA%D9%88%D8%A7%D8%B5%D9%84%20%D9%85%D8%B9%D9%83%20%D8%A8%D8%AE%D8%B5%D9%88%D8%B5%20%D8%AA%D8%B7%D8%A8%D9%8A%D9%82%20%D9%85%D8%B3%D8%A7%D8%B9%D8%AF%20%D8%A7%D9%84%D8%AA%D8%AC%D8%A7%D8%B1%D8%A9%20%D9%88%D8%A7%D9%84%D8%B4%D8%AD%D9%86';
    final uri = Uri.parse(whatsappUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          AppToast.showInfo(context, 'about_dev_name'.i18n());
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.showInfo(context, 'about_dev_name'.i18n());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
                ? Colors.black.withValues(alpha: 0.35)
                : AppColors.primaryBlue.withValues(alpha: 0.05),
            offset: const Offset(0, 6),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس بطاقة المطور مع الصورة الرمزية والاسم
          Row(
            children: [
              // الصورة الرمزية للمطور مع إطار متدرج
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF007AFF), Color(0xFF0A2540)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                      offset: const Offset(0, 4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'S',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // الاسم والمسمى
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'about_dev_name'.i18n(),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.primaryBlue,
                          size: 18,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'about_dev_role'.i18n(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Salah aldain alhajj',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // نبذة عن المطور
          Text(
            'about_dev_bio'.i18n(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.normal,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // اقتباس ورؤية المطور
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceMuted : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: isDark ? 0.3 : 0.2),
                width: 0.8,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.format_quote_rounded,
                  color: AppColors.primaryGreen,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'about_dev_quote'.i18n(),
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextPrimary : const Color(0xFF166534),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // كلمة المطور للمستخدم
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceMuted : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? AppColors.darkBorderDivider : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'about_dev_message_title'.i18n(),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'about_dev_message'.i18n(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // أزرار التفاعل والإجراءات
          Column(
            children: [
              // زر تواصل عبر واتساب
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _contactViaWhatsApp(context),
                  icon: const WhatsAppIcon(size: 18),
                  label: Text('about_dev_whatsapp_btn'.i18n()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  // زر مشاركة التطبيق
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _shareApp(context),
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: Text('about_dev_share_btn'.i18n()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                        side: BorderSide(
                          color: isDark ? AppColors.darkPrimaryBlue : AppColors.primaryBlue,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // زر جولة الميزات
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const OnboardingScreen(isFromSettings: true),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_stories_rounded, size: 16),
                      label: Text('about_dev_tour_btn'.i18n()),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkPrimaryGreen : AppColors.primaryGreen,
                        side: BorderSide(
                          color: isDark ? AppColors.darkPrimaryGreen : AppColors.primaryGreen,
                          width: 0.8,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
