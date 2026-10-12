import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'components/app_cards.dart';
import 'components/app_badges.dart';

/// سهم التقدم للأمام في بيئة الـ RTL (يشير حتماً لليسار طبقاً لتدفق اللغة العربية)
class ForwardChevron extends StatelessWidget {
  final Color? color;
  final double size;

  const ForwardChevron({super.key, this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // في واجهات RTL، الانتقال للأمام والاستمرار يكون دوماً لليسار (←)
    // وفي واجهات LTR يكون لليمين (→)
    // استخدام arrow_forward_ios_rounded مع matchTextDirection: true يحقق هذا السلوك تلقائياً
    return Icon(
      Icons.arrow_forward_ios_rounded,
      size: size,
      color:
          color ??
          (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
    );
  }
}

class BackChevron extends StatelessWidget {
  final Color? color;
  final double size;

  const BackChevron({super.key, this.color, this.size = 14});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // في واجهات RTL، الانتقال للأمام والاستمرار يكون دوماً لليسار (←)
    // وفي واجهات LTR يكون لليمين (→)
    // استخدام arrow_back_rounded مع matchTextDirection: true يحقق هذا السلوك تلقائياً
    return Icon(
      Icons.arrow_back_ios_rounded,
      size: size,
      color:
          color ??
          (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
    );
  }
}

/// توافقية موروثة للهوية البصرية - توجيه مباشر نحو المكونات الموحدة
typedef AppleCard = AppCard;
typedef AnimatedAppleCard = AppAnimatedCard;
typedef AppleBadge = AppBadge;
typedef PulsingStatusDot = AppPulsingDot;

