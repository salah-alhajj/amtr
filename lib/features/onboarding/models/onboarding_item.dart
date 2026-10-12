import 'package:flutter/material.dart';

/// نموذج بيانات عنصر جولة التعريف بالخصائص (Onboarding Item)
class OnboardingItem {
  final int index;
  final String badge;
  final Color badgeColor;
  final String title;
  final String subtitle;
  final String description;
  final List<String> bulletPoints;
  final String? imagePath;
  final bool isLogoSlide;
  final bool isClosingSlide;
  final Color primaryColor;
  final Color secondaryColor;

  const OnboardingItem({
    required this.index,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.bulletPoints,
    this.imagePath,
    this.isLogoSlide = false,
    this.isClosingSlide = false,
    required this.primaryColor,
    required this.secondaryColor,
  });
}
