import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/services/reminder_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../cashbox/presentation/cubit/cashbox_cubit.dart';
import '../../../couriers/presentation/bloc/couriers_bloc.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../expenses/presentation/bloc/expenses_bloc.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../products/presentation/bloc/products_bloc.dart';
import '../../../shipments/presentation/bloc/shipments_bloc.dart';
import '../../../suppliers/presentation/bloc/suppliers_bloc.dart';
import '../widgets/backup_action_tile.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final BackupService _backupService = BackupService.instance;
  bool _isLoading = false;
  DateTime? _lastBackupAt;
  bool _weeklyReminderEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadBackupPreferences();
  }

  void _loadBackupPreferences() {
    _lastBackupAt = PreferencesService.instance.getLastBackupAt();
    _weeklyReminderEnabled =
        PreferencesService.instance.isWeeklyBackupReminderEnabled();
  }

  Future<void> _reloadAllBlocsAfterRestore() async {
    try {
      await CurrencyService.instance.init();
    } catch (_) {}
    if (!mounted) return;

    void safeRun(VoidCallback fn) {
      try {
        fn();
      } catch (_) {}
    }

    safeRun(() => context.read<DashboardBloc>().add(const LoadDashboardData()));
    safeRun(() => context.read<OrdersBloc>().add(const LoadOrders()));
    safeRun(() => context.read<CustomersBloc>().add(const LoadCustomers()));
    safeRun(() => context.read<ShipmentsBloc>().add(const LoadShipments()));
    safeRun(() => context.read<ProductsBloc>().add(const LoadProducts()));
    safeRun(() => context.read<ExpensesBloc>().add(const LoadExpenses()));
    safeRun(() => context.read<SuppliersBloc>().add(const LoadSuppliers()));
    safeRun(() => context.read<CouriersBloc>().add(const LoadCouriers()));
    safeRun(() {
      final cashBoxCubit = context.read<CashBoxCubit>();
      cashBoxCubit.loadDate(cashBoxCubit.selectedDate);
    });
  }

  void _runAction(
    String title,
    Future<dynamic> Function() action, {
    bool isExport = false,
  }) async {
    setState(() => _isLoading = true);
    try {
      final res = await action();
      if (!mounted) return;

      if (res != false) {
        if (title == 'backup_import_restore_action'.i18n()) {
          await _reloadAllBlocsAfterRestore();
        } else if (isExport) {
          final now = DateTime.now();
          await PreferencesService.instance.setLastBackupAt(now);
          if (mounted) {
            setState(() => _lastBackupAt = now);
          }
        }

        if (!mounted) return;
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

  Future<void> _onWeeklyReminderChanged(bool val) async {
    setState(() => _weeklyReminderEnabled = val);
    await PreferencesService.instance.setWeeklyBackupReminderEnabled(val);

    if (val) {
      await ReminderService.instance.scheduleWeeklyBackupReminder();
      if (!mounted) return;
      AppToast.showSuccess(context, 'backup_reminder_enabled_toast'.i18n());
    } else {
      await ReminderService.instance.cancelWeeklyBackupReminder();
      if (!mounted) return;
      AppToast.showInfo(context, 'backup_reminder_disabled_toast'.i18n());
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
    final lastBackupLabel = _lastBackupAt != null
        ? 'backup_last_saved_label'.trParams({
            'date': DateFormat('yyyy-MM-dd HH:mm').format(_lastBackupAt!),
          })
        : 'backup_never_saved'.i18n();

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

                const SizedBox(height: 16),

                // بطاقة بارزة للحفظ الفوري في واتساب وتاريخ آخر نسخة
                AppCard(
                  gradient: context.isDarkMode
                      ? const LinearGradient(
                          colors: [AppColors.darkSurfaceCard, AppColors.darkSurfaceMuted],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFECFDF5), Color(0xFFD1FAE5)],
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.chat_outlined, color: AppColors.primaryGreen, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'backup_quick_whatsapp_title'.i18n(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'backup_quick_whatsapp_desc'.i18n(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            _lastBackupAt != null ? Icons.check_circle_outline : Icons.info_outline,
                            size: 16,
                            color: _lastBackupAt != null ? AppColors.primaryGreen : AppColors.statusWarning,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              lastBackupLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          label: 'backup_export_json_action'.i18n(),
                          icon: Icons.share_outlined,
                          onPressed: () => _runAction(
                            'backup_export_json_action'.i18n(),
                            () => _backupService.exportBackupJson(),
                            isExport: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                AppSwitchTile(
                  title: 'backup_weekly_reminder_title'.i18n(),
                  subtitle: 'backup_weekly_reminder_desc'.i18n(),
                  icon: Icons.notifications_active_outlined,
                  value: _weeklyReminderEnabled,
                  onChanged: _onWeeklyReminderChanged,
                ),

                const SizedBox(height: 20),

                AppSectionHeader(
                  title: 'backup_export_section'.i18n(),
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),

                BackupActionTile(
                  onTap: () => _runAction(
                    'backup_export_json_action'.i18n(),
                    () => _backupService.exportBackupJson(),
                    isExport: true,
                  ),
                  icon: Icons.share_outlined,
                  iconColor: AppColors.primaryBlue,
                  avatarBgColor: const Color(0xFFE0F2FE),
                  title: 'backup_export_json_tile'.i18n(),
                  subtitle: 'backup_export_json_desc'.i18n(),
                ),

                BackupActionTile(
                  onTap: () => _runAction(
                    'backup_export_raw_action'.i18n(),
                    () => _backupService.exportRawDatabase(),
                    isExport: true,
                  ),
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

