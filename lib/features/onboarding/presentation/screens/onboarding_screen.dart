import 'package:amtr/core/widgets/apple_widgets.dart';
import 'package:amtr/features/onboarding/data/onboarding_data.dart';
import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/navigation/main_navigation_shell.dart';
import '../widgets/onboarding_page_indicator.dart';
import '../widgets/onboarding_slide_widget.dart';

/// شاشة الأونبوردينج الرئيسية التفاعلية مع دعم السحب والانتقالات السلسة
class OnboardingScreen extends StatefulWidget {
  final bool isFromSettings;
  final VoidCallback? onFinish;

  const OnboardingScreen({
    super.key,
    this.isFromSettings = false,
    this.onFinish,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final PageController _pageController;
  int _currentPage = 0;
  final int _totalPages = OnboardingData.items.length; // 8 سلايدات (من 0 إلى 7)

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// إتمام جولة التعريف والانتقال للنظام
  Future<void> _completeOnboarding() async {
    await PreferencesService.instance.setOnboardingCompleted(true);

    if (!mounted) return;

    if (widget.onFinish != null) {
      widget.onFinish!();
      return;
    }

    if (widget.isFromSettings && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, anim, secAnim) => const MainNavigationShell(),
          transitionsBuilder: (context, animation, secAnim, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              ),
              child: child,
            );
          },
        ),
      );
    }
  }

  /// الانتقال إلى السلايد التالي
  void _goToNext() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _completeOnboarding();
    }
  }

  /// الرجوع إلى السلايد السابق
  void _goToPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentItem = OnboardingData.items[_currentPage];

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkScaffoldBackground
          : AppColors.scaffoldBackground,
      body: SafeArea(
        child: Column(
          children: [
            // الشريط العلوي (العلامة التجارية وزر التخطي والعداد)
            _buildTopBar(isDark),

            // منطقة السلايدات التفاعلية مع دعم السحب
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _totalPages,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final item = OnboardingData.items[index];
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 250),
                    opacity: _currentPage == index ? 1.0 : 0.65,
                    child: OnboardingSlideWidget(
                      item: item,
                      isActive: _currentPage == index,
                    ),
                  );
                },
              ),
            ),

            // الشريط السفلي (المؤشرات وأزرار التقدم والتراجع)
            _buildBottomBar(isDark, currentItem),
          ],
        ),
      ),
    );
  }

  /// الشريط العلوي
  Widget _buildTopBar(bool isDark) {
    final isLastSlide = _currentPage == _totalPages - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // عداد السلايد الحالي
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentPage + 1} / $_totalPages',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ),

          // زر التخطي (يختفي في السلايد الأخير)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: isLastSlide ? 0.0 : 1.0,
            child: TextButton(
              onPressed: isLastSlide ? null : _completeOnboarding,
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: Text(
                'common_skip'.i18n(),
                style: const TextStyle(fontFamily: 'IBMPlexSansArabic'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// الشريط السفلي مع مراعاة قواعد RTL في الأسهم
  Widget _buildBottomBar(bool isDark, item) {
    final isLastSlide = _currentPage == _totalPages - 1;
    final isFirstSlide = _currentPage == 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkScaffoldBackground
            : AppColors.scaffoldBackground,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.darkBorderSubtle.withValues(alpha: 0.5)
                : AppColors.borderSubtle.withValues(alpha: 0.5),
            width: 0.8,
          ),
        ),
      ),
      child: isLastSlide
          ? _buildLaunchButton(isDark)
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // زر السابق: في لغة RTL الرجوع للخلف يشير لليمين (→)
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isFirstSlide ? 0.0 : 1.0,
                  child: TextButton.icon(
                    onPressed: isFirstSlide ? null : _goToPrevious,
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                    ),
                    // السهم يشير لليمين في العربية دلالة على الرجوع للخلف
                    icon: const BackChevron(size: 14),
                    label: Text(
                      'common_previous'.i18n(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                // مؤشر الصفحات الكبسولي
                OnboardingPageIndicator(
                  count: _totalPages,
                  activeIndex: _currentPage,
                  onDotTapped: (index) {
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                    );
                  },
                ),

                // زر التالي: في لغة RTL التقدم للأمام يشير لليسار (←)
                Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.appleGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _goToNext,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 11,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'common_next'.i18n(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // السهم يشير لليسار في RTL دلالة على التقدم للأمام
                            const ForwardChevron(size: 14, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// زر الانطلاق الختامي في السلايد رقم 7
  Widget _buildLaunchButton(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // مؤشر الصفحات في المنتصف
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: OnboardingPageIndicator(
            count: _totalPages,
            activeIndex: _currentPage,
            onDotTapped: (index) {
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 400),
                curve: Curves.fastOutSlowIn,
              );
            },
          ),
        ),

        // الزر الرئيسي العريض مع تدرج آبل الفاخر
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryBlue, AppColors.primaryGreen],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGreen.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _completeOnboarding,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'onboarding_get_started'.i18n(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // السهم يشير لليسار في RTL للانطلاق للأمام
                    const ForwardChevron(color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
