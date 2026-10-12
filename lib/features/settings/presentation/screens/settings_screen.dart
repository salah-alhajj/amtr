import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../backup/presentation/screens/backup_restore_screen.dart';
import '../../../onboarding/presentation/screens/onboarding_screen.dart';
import '../widgets/database_backup_tile.dart';
import '../widgets/demo_data_card.dart';
import '../widgets/exchange_rates_card.dart';
import '../widgets/language_selector_card.dart';
import '../widgets/theme_selector_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CurrencyService _currencyService = CurrencyService.instance;
  late final TextEditingController _sarController;
  late final TextEditingController _usdController;

  @override
  void initState() {
    super.initState();
    _sarController = TextEditingController(text: _currencyService.sarToYer.toString());
    _usdController = TextEditingController(text: _currencyService.usdToYer.toString());
  }

  @override
  void dispose() {
    _sarController.dispose();
    _usdController.dispose();
    super.dispose();
  }

  Future<void> _saveRates() async {
    final sar = double.tryParse(_sarController.text);
    final usd = double.tryParse(_usdController.text);

    if (sar == null || sar <= 0 || usd == null || usd <= 0) {
      AppToast.showError(context, 'common_error'.i18n());
      return;
    }

    await _currencyService.updateRates(newSarToYer: sar, newUsdToYer: usd);

    if (mounted) {
      AppToast.showSuccess(context, 'common_success'.i18n());
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('settings_title'.i18n()),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // نمط مظهر التطبيق (تلقائي / فاتح / داكن)
          const ThemeSelectorCard(),

          const SizedBox(height: 16),

          // اختيار لغة التطبيق
          const LanguageSelectorCard(),

          const SizedBox(height: 16),

          // بطاقة العملة القاعدة وأسعار الصرف
          ExchangeRatesCard(
            sarController: _sarController,
            usdController: _usdController,
            onSave: _saveRates,
          ),

          const SizedBox(height: 16),

          // جولة في ميزات التطبيق
          AppleCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(isFromSettings: true),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.primaryBlue,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'onboarding_tour_title'.i18n(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'onboarding_tour_desc'.i18n(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const ForwardChevron(size: 13),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // خيارات قاعدة البيانات
          DatabaseBackupTile(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
              );
            },
          ),

          const SizedBox(height: 16),

          // قسم الداتا التجريبية والتدريبية
          const DemoDataCard(),

          const SizedBox(height: 16),

          // معلومات التطبيق
          AppleCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('about_app'.i18n(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'app_tagline'.i18n(),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 8),
                Text('settings_app_version'.i18n(), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

