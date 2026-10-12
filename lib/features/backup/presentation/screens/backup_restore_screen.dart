import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../widgets/backup_action_tile.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService.instance;
  bool _isLoading = false;

  void _runAction(String title, Future<dynamic> Function() action) async {
    setState(() => _isLoading = true);
    try {
      final res = await action();
      if (!mounted) return;

      if (res != false) {
        AppToast.showSuccess(
          context,
          'backup_action_success'.trParams({'title': title}),
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(
        context,
        'backup_action_error'.trParams({'title': title, 'error': e.toString()}),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmRestore(String formatName, Future<dynamic> Function() action) {
    showAppConfirmationDialog(
      context: context,
      title: 'backup_restore_confirm_title'.i18n(),
      message: 'backup_restore_confirm_msg'.trParams({'format': formatName}),
      confirmLabel: 'backup_restore_confirm_btn'.i18n(),
      cancelLabel: 'common_cancel'.i18n(),
      isDestructive: true,
      onConfirm: () => _runAction('backup_import_restore_action'.i18n(), action),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('backup_screen_title'.i18n()),
        leading: const BackButton(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // بطاقة توضيحية
                AppCard(
                  gradient: context.isDarkMode
                      ? const LinearGradient(
                          colors: [AppColors.darkSurfaceCard, AppColors.darkSurfaceMuted],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFE0F2FE), Color(0xFFEFF6FF)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.storage_rounded, color: AppColors.primaryBlue, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'backup_offline_banner_title'.i18n(),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: context.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'backup_offline_banner_desc'.i18n(),
                              style: TextStyle(fontSize: 11, color: context.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                AppSectionHeader(
                  title: 'backup_export_section'.i18n(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                BackupActionTile(
                  onTap: () => _runAction('backup_export_json_action'.i18n(), () => _backupService.exportBackupJson()),
                  icon: Icons.share_outlined,
                  iconColor: AppColors.primaryBlue,
                  avatarBgColor: const Color(0xFFE0F2FE),
                  title: 'backup_export_json_tile'.i18n(),
                  subtitle: 'backup_export_json_desc'.i18n(),
                ),

                BackupActionTile(
                  onTap: () => _runAction('backup_export_raw_action'.i18n(), () => _backupService.exportRawDatabase()),
                  icon: Icons.file_download_outlined,
                  iconColor: AppColors.primaryGreen,
                  avatarBgColor: const Color(0xFFD1FAE5),
                  title: 'backup_export_raw_tile'.i18n(),
                  subtitle: 'backup_export_raw_desc'.i18n(),
                ),

                const SizedBox(height: 24),

                AppSectionHeader(
                  title: 'backup_import_section'.i18n(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                BackupActionTile(
                  onTap: () => _confirmRestore('backup_format_json'.i18n(), () => _backupService.importBackupJson()),
                  icon: Icons.file_upload_outlined,
                  iconColor: AppColors.statusWarning,
                  avatarBgColor: const Color(0xFFFEF3C7),
                  title: 'backup_import_json_tile'.i18n(),
                  subtitle: 'backup_import_json_desc'.i18n(),
                ),

                BackupActionTile(
                  onTap: () => _confirmRestore('backup_format_db'.i18n(), () => _backupService.importRawDatabase()),
                  icon: Icons.settings_backup_restore_rounded,
                  iconColor: AppColors.statusDanger,
                  avatarBgColor: const Color(0xFFFEE2E2),
                  title: 'backup_import_db_tile'.i18n(),
                  subtitle: 'backup_import_db_desc'.i18n(),
                ),
              ],
            ),
    );
  }
}

