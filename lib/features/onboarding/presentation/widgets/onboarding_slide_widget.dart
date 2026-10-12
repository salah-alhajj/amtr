import 'package:amtr/features/onboarding/models/onboarding_item.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/apple_widgets.dart';

/// ويدجت شريحة الأونبوردينج الفاخرة مع دعم كامل للتأثيرات والانتقالات
class OnboardingSlideWidget extends StatefulWidget {
  final OnboardingItem item;
  final bool isActive;

  const OnboardingSlideWidget({
    super.key,
    required this.item,
    required this.isActive,
  });

  @override
  State<OnboardingSlideWidget> createState() => _OnboardingSlideWidgetState();
}

class _OnboardingSlideWidgetState extends State<OnboardingSlideWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );

    _floatAnimation = Tween<double>(begin: -4, end: 4).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);
    final imageHeight = (size.height * 0.30).clamp(200.0, 310.0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. العنصر البصري الرئيسي (اللوجو أو الرسم التوضيحي المفرغ)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              );
            },
            child: widget.item.isLogoSlide
                ? _buildLogoHero(isDark, imageHeight)
                : _buildIllustrationHero(isDark, imageHeight),
          ),

          const SizedBox(height: 18),

          // 2. الشارة الفئوية
          AppleBadge(
            label: widget.item.badge,
            color: widget.item.badgeColor,
            icon: widget.item.isLogoSlide
                ? Icons.star_rounded
                : (widget.item.isClosingSlide
                      ? Icons.rocket_launch_rounded
                      : Icons.check_circle_outline_rounded),
          ),

          const SizedBox(height: 12),

          // 3. العنوان الرئيسي
          Text(
            widget.item.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              letterSpacing: -0.4,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 6),

          // 4. العنوان الفرعي
          Text(
            widget.item.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.item.primaryColor,
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 10),

          // 5. الوصف التوضيحي
          Text(
            widget.item.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
              height: 1.55,
            ),
          ),

          const SizedBox(height: 16),

          // 6. قائمة النقاط والمزايا السريعة في بطاقة أنيقة
          _buildBulletPointsCard(isDark),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  /// بناء واجهة الشعار للسلايد رقم 0
  Widget _buildLogoHero(bool isDark, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // الهالة الضوئية الخارجية
          Container(
            width: size * 0.88,
            height: size * 0.88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: isDark ? 0.35 : 0.20),
                  AppColors.primaryGreen.withValues(
                    alpha: isDark ? 0.20 : 0.10,
                  ),
                  Colors.transparent,
                ],
                stops: const [0.2, 0.65, 1.0],
              ),
            ),
          ),

          // الحاوية الدائرية الفاخرة للوجو
          Container(
            width: size * 0.70,
            height: size * 0.70,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorderSubtle
                    : AppColors.primaryBlue.withValues(alpha: 0.2),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/amtr_logo_symbol.jpg',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryBlue,
                    alignment: Alignment.center,
                    child: const Text(
                      'AMTR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بناء واجهة الرسم التوضيحي المفرغ للسلايدات من 1 إلى 7
  Widget _buildIllustrationHero(bool isDark, double height) {
    return Container(
      height: height,
      alignment: Alignment.center,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // وهج لوني خلف الرسم التوضيحي يبرز التفرغ والجمالية
          Container(
            width: height * 0.85,
            height: height * 0.85,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  widget.item.primaryColor.withValues(
                    alpha: isDark ? 0.28 : 0.16,
                  ),
                  widget.item.secondaryColor.withValues(
                    alpha: isDark ? 0.15 : 0.08,
                  ),
                  Colors.transparent,
                ],
                stops: const [0.15, 0.65, 1.0],
              ),
            ),
          ),

          // الصورة التوضيحية المفرغة
          if (widget.item.imagePath != null)
            Image.asset(
              widget.item.imagePath!,
              height: height,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.image_not_supported_outlined,
                  size: 64,
                  color: widget.item.primaryColor,
                );
              },
            ),
        ],
      ),
    );
  }

  /// بطاقة النقاط والميزات السريعة
  Widget _buildBulletPointsCard(bool isDark) {
    return AppleCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      backgroundColor: isDark
          ? AppColors.darkSurfaceCard.withValues(alpha: 0.65)
          : AppColors.surfaceCard.withValues(alpha: 0.85),
      child: Column(
        children: widget.item.bulletPoints.map((point) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: widget.item.primaryColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 13,
                    color: widget.item.primaryColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    point,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
