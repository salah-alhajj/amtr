import 'package:flutter/material.dart';
import '../../../core/localization/localization.dart';
import '../../../core/theme/app_colors.dart';

enum CustomerLoyaltyTier { vip, regular, newCustomer }

/// مساعد حساب شارات ولاء العملاء بناءً على عدد الطلبات وإجمالي المبيعات بالريال اليمني
class CustomerLoyaltyHelper {
  static CustomerLoyaltyTier computeTier({
    required int ordersCount,
    required double totalSalesYer,
  }) {
    if (ordersCount >= 5 || totalSalesYer >= 100000) {
      return CustomerLoyaltyTier.vip;
    }
    if (ordersCount >= 2) {
      return CustomerLoyaltyTier.regular;
    }
    return CustomerLoyaltyTier.newCustomer;
  }

  static String label(CustomerLoyaltyTier tier) {
    switch (tier) {
      case CustomerLoyaltyTier.vip:
        return 'customer_tier_vip'.i18n();
      case CustomerLoyaltyTier.regular:
        return 'customer_tier_regular'.i18n();
      case CustomerLoyaltyTier.newCustomer:
        return 'customer_tier_new'.i18n();
    }
  }

  static Color color(CustomerLoyaltyTier tier) {
    switch (tier) {
      case CustomerLoyaltyTier.vip:
        return AppColors.statusWarning;
      case CustomerLoyaltyTier.regular:
        return AppColors.primaryBlue;
      case CustomerLoyaltyTier.newCustomer:
        return AppColors.primaryGreen;
    }
  }

  static IconData icon(CustomerLoyaltyTier tier) {
    switch (tier) {
      case CustomerLoyaltyTier.vip:
        return Icons.workspace_premium_rounded;
      case CustomerLoyaltyTier.regular:
        return Icons.verified_outlined;
      case CustomerLoyaltyTier.newCustomer:
        return Icons.person_outline_rounded;
    }
  }
}
