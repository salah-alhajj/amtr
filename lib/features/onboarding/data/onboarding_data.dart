import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../models/onboarding_item.dart';

/// قائمة عناصر جولة التعريف بالتطبيق (8 سلايدات: من 0 إلى 7)
/// تدعم التوطين الكامل والتحديث الفوري للغات (عربي / إنجليزي)
class OnboardingData {
  static List<OnboardingItem> get items => [
    // السلايد 0: الترحيب واللوجو
    OnboardingItem(
      index: 0,
      badge: 'onboarding_slide0_badge'.i18n(),
      badgeColor: AppColors.primaryBlue,
      title: 'onboarding_slide0_title'.i18n(),
      subtitle: 'onboarding_slide0_subtitle'.i18n(),
      description: 'onboarding_slide0_description'.i18n(),
      bulletPoints: [
        'onboarding_slide0_point1'.i18n(),
        'onboarding_slide0_point2'.i18n(),
        'onboarding_slide0_point3'.i18n(),
      ],
      isLogoSlide: true,
      primaryColor: AppColors.primaryBlue,
      secondaryColor: AppColors.primaryGreen,
    ),

    // السلايد 1: إدارة الطلبات
    OnboardingItem(
      index: 1,
      badge: 'onboarding_slide1_badge'.i18n(),
      badgeColor: const Color(0xFF007AFF),
      imagePath: 'assets/images/onboarding/onboarding_1_orders.png',
      title: 'onboarding_slide1_title'.i18n(),
      subtitle: 'onboarding_slide1_subtitle'.i18n(),
      description: 'onboarding_slide1_description'.i18n(),
      bulletPoints: [
        'onboarding_slide1_point1'.i18n(),
        'onboarding_slide1_point2'.i18n(),
        'onboarding_slide1_point3'.i18n(),
      ],
      primaryColor: const Color(0xFF007AFF),
      secondaryColor: const Color(0xFF06B6D4),
    ),

    // السلايد 2: تجميع الحمولات والشحنات
    OnboardingItem(
      index: 2,
      badge: 'onboarding_slide2_badge'.i18n(),
      badgeColor: const Color(0xFF059669),
      imagePath: 'assets/images/onboarding/onboarding_2_consolidation.png',
      title: 'onboarding_slide2_title'.i18n(),
      subtitle: 'onboarding_slide2_subtitle'.i18n(),
      description: 'onboarding_slide2_description'.i18n(),
      bulletPoints: [
        'onboarding_slide2_point1'.i18n(),
        'onboarding_slide2_point2'.i18n(),
        'onboarding_slide2_point3'.i18n(),
      ],
      primaryColor: const Color(0xFF059669),
      secondaryColor: const Color(0xFF10B981),
    ),

    // السلايد 3: لوجستيات الشحن والحاويات
    OnboardingItem(
      index: 3,
      badge: 'onboarding_slide3_badge'.i18n(),
      badgeColor: const Color(0xFF0284C7),
      imagePath: 'assets/images/onboarding/onboarding_3_shipments.png',
      title: 'onboarding_slide3_title'.i18n(),
      subtitle: 'onboarding_slide3_subtitle'.i18n(),
      description: 'onboarding_slide3_description'.i18n(),
      bulletPoints: [
        'onboarding_slide3_point1'.i18n(),
        'onboarding_slide3_point2'.i18n(),
        'onboarding_slide3_point3'.i18n(),
      ],
      primaryColor: const Color(0xFF0284C7),
      secondaryColor: const Color(0xFF38BDF8),
    ),

    // السلايد 4: دليل العملاء والحسابات
    OnboardingItem(
      index: 4,
      badge: 'onboarding_slide4_badge'.i18n(),
      badgeColor: const Color(0xFFD97706),
      imagePath: 'assets/images/onboarding/onboarding_4_customers.png',
      title: 'onboarding_slide4_title'.i18n(),
      subtitle: 'onboarding_slide4_subtitle'.i18n(),
      description: 'onboarding_slide4_description'.i18n(),
      bulletPoints: [
        'onboarding_slide4_point1'.i18n(),
        'onboarding_slide4_point2'.i18n(),
        'onboarding_slide4_point3'.i18n(),
      ],
      primaryColor: const Color(0xFFD97706),
      secondaryColor: const Color(0xFFF59E0B),
    ),

    // السلايد 5: التسعير والعملات المتعددة
    OnboardingItem(
      index: 5,
      badge: 'onboarding_slide5_badge'.i18n(),
      badgeColor: const Color(0xFF7C3AED),
      imagePath: 'assets/images/onboarding/onboarding_5_currency.png',
      title: 'onboarding_slide5_title'.i18n(),
      subtitle: 'onboarding_slide5_subtitle'.i18n(),
      description: 'onboarding_slide5_description'.i18n(),
      bulletPoints: [
        'onboarding_slide5_point1'.i18n(),
        'onboarding_slide5_point2'.i18n(),
        'onboarding_slide5_point3'.i18n(),
      ],
      primaryColor: const Color(0xFF7C3AED),
      secondaryColor: const Color(0xFFA855F7),
    ),

    // السلايد 6: الخصوصية والعمل دون إنترنت
    OnboardingItem(
      index: 6,
      badge: 'onboarding_slide6_badge'.i18n(),
      badgeColor: const Color(0xFF0F766E),
      imagePath: 'assets/images/onboarding/onboarding_6_offline_security.png',
      title: 'onboarding_slide6_title'.i18n(),
      subtitle: 'onboarding_slide6_subtitle'.i18n(),
      description: 'onboarding_slide6_description'.i18n(),
      bulletPoints: [
        'onboarding_slide6_point1'.i18n(),
        'onboarding_slide6_point2'.i18n(),
        'onboarding_slide6_point3'.i18n(),
      ],
      primaryColor: const Color(0xFF0F766E),
      secondaryColor: const Color(0xFF14B8A6),
    ),

    // السلايد 7: السلايد الختامي والانطلاق
    OnboardingItem(
      index: 7,
      badge: 'onboarding_slide7_badge'.i18n(),
      badgeColor: const Color(0xFF10B981),
      imagePath: 'assets/images/onboarding/onboarding_7_launch.png',
      title: 'onboarding_slide7_title'.i18n(),
      subtitle: 'onboarding_slide7_subtitle'.i18n(),
      description: 'onboarding_slide7_description'.i18n(),
      bulletPoints: [
        'onboarding_slide7_point1'.i18n(),
        'onboarding_slide7_point2'.i18n(),
        'onboarding_slide7_point3'.i18n(),
      ],
      isClosingSlide: true,
      primaryColor: const Color(0xFF10B981),
      secondaryColor: const Color(0xFF007AFF),
    ),
  ];
}
