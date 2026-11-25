import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../../../settings/presentation/screens/feature_settings_screen.dart';

class _GuideSectionData {
  final String id;
  final IconData icon;
  final Color color;
  final String titleKey;
  final String summaryKey;
  final List<String> stepKeys;
  final String tipKey;
  final List<String> roles; // فارغ = مناسب لجميع الأدوار

  const _GuideSectionData({
    required this.id,
    required this.icon,
    required this.color,
    required this.titleKey,
    required this.summaryKey,
    required this.stepKeys,
    required this.tipKey,
    this.roles = const [],
  });
}

class _GuideFaqData {
  final String qKey;
  final String aKey;

  const _GuideFaqData({required this.qKey, required this.aKey});
}

/// دليل استخدام شامل وتفاعلي لكافة وحدات التطبيق مع فلترة حسب الدور وبحث فوري
class AppUserGuideScreen extends StatefulWidget {
  const AppUserGuideScreen({super.key});

  @override
  State<AppUserGuideScreen> createState() => _AppUserGuideScreenState();
}

class _AppUserGuideScreenState extends State<AppUserGuideScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedRoleFilter = 'all';

  static const List<_GuideSectionData> _chapters = [
    _GuideSectionData(
      id: 'roles',
      icon: Icons.tune_rounded,
      color: AppColors.primaryBlue,
      titleKey: 'guide_ch1_title',
      summaryKey: 'guide_ch1_summary',
      stepKeys: ['guide_ch1_s1', 'guide_ch1_s2', 'guide_ch1_s3'],
      tipKey: 'guide_ch1_tip',
    ),
    _GuideSectionData(
      id: 'orders',
      icon: Icons.inventory_2_rounded,
      color: AppColors.primaryGreen,
      titleKey: 'guide_ch2_title',
      summaryKey: 'guide_ch2_summary',
      stepKeys: ['guide_ch2_s1', 'guide_ch2_s2', 'guide_ch2_s3'],
      tipKey: 'guide_ch2_tip',
    ),
    _GuideSectionData(
      id: 'catalog',
      icon: Icons.storefront_rounded,
      color: AppColors.vibrantTeal,
      titleKey: 'guide_ch3_title',
      summaryKey: 'guide_ch3_summary',
      stepKeys: ['guide_ch3_s1', 'guide_ch3_s2', 'guide_ch3_s3'],
      tipKey: 'guide_ch3_tip',
      roles: [
        AppConstants.businessModeSimpleSeller,
        AppConstants.businessModeProductiveFamily,
        AppConstants.businessModeArtisanCraft,
        AppConstants.businessModeRetailShop,
      ],
    ),
    _GuideSectionData(
      id: 'manufacturing',
      icon: Icons.auto_awesome_mosaic_outlined,
      color: Color(0xFF7C3AED),
      titleKey: 'guide_ch4_title',
      summaryKey: 'guide_ch4_summary',
      stepKeys: ['guide_ch4_s1', 'guide_ch4_s2', 'guide_ch4_s3'],
      tipKey: 'guide_ch4_tip',
      roles: [
        AppConstants.businessModeProductiveFamily,
        AppConstants.businessModeArtisanCraft,
      ],
    ),
    _GuideSectionData(
      id: 'cashbox',
      icon: Icons.account_balance_wallet_rounded,
      color: Color(0xFF0F766E),
      titleKey: 'guide_ch5_title',
      summaryKey: 'guide_ch5_summary',
      stepKeys: ['guide_ch5_s1', 'guide_ch5_s2', 'guide_ch5_s3'],
      tipKey: 'guide_ch5_tip',
    ),
    _GuideSectionData(
      id: 'customers',
      icon: Icons.people_alt_rounded,
      color: Color(0xFFD97706),
      titleKey: 'guide_ch6_title',
      summaryKey: 'guide_ch6_summary',
      stepKeys: ['guide_ch6_s1', 'guide_ch6_s2', 'guide_ch6_s3'],
      tipKey: 'guide_ch6_tip',
    ),
    _GuideSectionData(
      id: 'logistics',
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF2563EB),
      titleKey: 'guide_ch7_title',
      summaryKey: 'guide_ch7_summary',
      stepKeys: ['guide_ch7_s1', 'guide_ch7_s2', 'guide_ch7_s3'],
      tipKey: 'guide_ch7_tip',
      roles: [
        AppConstants.businessModeProductiveFamily,
        AppConstants.businessModeArtisanCraft,
        AppConstants.businessModeRetailShop,
        AppConstants.businessModeTradeLogistics,
      ],
    ),
    _GuideSectionData(
      id: 'reports',
      icon: Icons.bar_chart_rounded,
      color: Color(0xFFE11D48),
      titleKey: 'guide_ch8_title',
      summaryKey: 'guide_ch8_summary',
      stepKeys: ['guide_ch8_s1', 'guide_ch8_s2', 'guide_ch8_s3'],
      tipKey: 'guide_ch8_tip',
    ),
  ];

  static const List<_GuideFaqData> _faqs = [
    _GuideFaqData(qKey: 'guide_faq1_q', aKey: 'guide_faq1_a'),
    _GuideFaqData(qKey: 'guide_faq2_q', aKey: 'guide_faq2_a'),
    _GuideFaqData(qKey: 'guide_faq3_q', aKey: 'guide_faq3_a'),
    _GuideFaqData(qKey: 'guide_faq4_q', aKey: 'guide_faq4_a'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_GuideSectionData> get _filteredChapters {
    final q = _query.trim().toLowerCase();
    return _chapters.where((ch) {
      final matchesRole = _selectedRoleFilter == 'all' ||
          ch.roles.isEmpty ||
          ch.roles.contains(_selectedRoleFilter);
      if (!matchesRole) return false;
      if (q.isEmpty) return true;
      final textPool = [
        ch.titleKey.i18n(),
        ch.summaryKey.i18n(),
        ch.tipKey.i18n(),
        ...ch.stepKeys.map((k) => k.i18n()),
      ].join(' ').toLowerCase();
      return textPool.contains(q);
    }).toList();
  }

  List<_GuideFaqData> get _filteredFaqs {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _faqs;
    return _faqs
        .where(
          (f) =>
              f.qKey.i18n().toLowerCase().contains(q) ||
              f.aKey.i18n().toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final chapters = _filteredChapters;
    final faqs = _filteredFaqs;

    return Scaffold(
      appBar: AppBar(
        title: Text('guide_screen_title'.i18n()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ترويسة الدليل
          AppHeroCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'guide_hero_title'.i18n(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'guide_hero_subtitle'.i18n(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppSecondaryButton(
                      label: 'guide_open_features_btn'.i18n(),
                      icon: Icons.tune_rounded,
                      color: Colors.white,
                      height: 38,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FeatureSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    AppSecondaryButton(
                      label: 'onboarding_tour_title'.i18n(),
                      icon: Icons.auto_stories_rounded,
                      color: Colors.white,
                      height: 38,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const OnboardingScreen(isFromSettings: true),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // شريط البحث الفوري
          AppTextField(
            controller: _searchController,
            hint: 'guide_search_hint'.i18n(),
            prefixIcon: Icons.search_rounded,
            suffix: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            onChanged: (val) => setState(() => _query = val),
          ),

          const SizedBox(height: 12),

          // فلترة الفصول حسب الدور
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleChip('all', 'guide_role_all'.i18n()),
                ...AppConstants.allBusinessModes.map(
                  (m) => _buildRoleChip(m, AppConstants.getBusinessModeLabel(m)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          if (chapters.isEmpty && faqs.isEmpty)
            AppCard(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'guide_no_results'.i18n(),
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
            ),

          ...chapters.asMap().entries.map((entry) {
            final idx = entry.key;
            final ch = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: EdgeInsets.zero,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.transparent,
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: idx == 0 && _query.isEmpty,
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ch.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(ch.icon, color: ch.color, size: 20),
                    ),
                    title: Text(
                      ch.titleKey.i18n(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      ch.summaryKey.i18n(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textSecondary,
                      ),
                    ),
                    children: [
                      const Divider(height: 12),
                      ...ch.stepKeys.asMap().entries.map((stepEntry) {
                        final sIdx = stepEntry.key + 1;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: ch.color.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$sIdx',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: ch.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  stepEntry.value.i18n(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.45,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ch.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: ch.color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 16,
                              color: ch.color,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ch.tipKey.i18n(),
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          if (faqs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'guide_faq_section_title'.i18n(),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...faqs.map(
              (faq) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 2,
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      leading: const Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.primaryBlue,
                        size: 20,
                      ),
                      title: Text(
                        faq.qKey.i18n(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            faq.aKey.i18n(),
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.45,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role, String label) {
    final selected = _selectedRoleFilter == role;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => setState(() => _selectedRoleFilter = role),
      ),
    );
  }
}
