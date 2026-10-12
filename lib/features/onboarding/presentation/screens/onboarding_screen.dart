import 'package:amtr/core/widgets/design_system.dart';
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
            child: AppSecondaryButton(
              onPressed: isLastSlide ? null : _completeOnboarding,
              label: 'common_skip'.i18n(),
              height: 32,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 4,
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
                  child: AppSecondaryButton(
                    onPressed: isFirstSlide ? null : _goToPrevious,
                    label: 'common_previous'.i18n(),
                    customIcon: const BackChevron(size: 14),
                    height: 40,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
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
                AppPrimaryButton(
                  onPressed: _goToNext,
                  label: 'common_next'.i18n(),
                  customIcon: const ForwardChevron(size: 14, color: Colors.white),
                  gradient: AppColors.appleGradient,
                  height: 42,
                  borderRadius: 14,
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
        AppPrimaryButton(
          onPressed: _completeOnboarding,
          label: 'onboarding_get_started'.i18n(),
          icon: Icons.rocket_launch_rounded,
          gradient: const LinearGradient(
            colors: [AppColors.primaryBlue, AppColors.primaryGreen],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
          ),
          height: 52,
          borderRadius: 16,
        ),
      ],
    );
  }
}
