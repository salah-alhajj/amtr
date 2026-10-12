import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/demo_data_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../customers/presentation/bloc/customers_bloc.dart';
import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../orders/presentation/bloc/orders_bloc.dart';
import '../../../shipments/presentation/bloc/shipments_bloc.dart';

/// بطاقة إدارة وتوليد وإزالة البيانات التجريبية والتدريبية للنظام
/// تدعم توليد مئات البيانات الواقعية المترابطة وحذفها بزر مجاور لزر التوليد
class DemoDataCard extends StatefulWidget {
  const DemoDataCard({super.key});

  @override
  State<DemoDataCard> createState() => _DemoDataCardState();
}

class _DemoDataCardState extends State<DemoDataCard> {
  final DemoDataService _demoDataService = DemoDataService.instance;

  bool _isLoading = false;
  String _loadingMessage = '';
  DemoDataStats _stats = const DemoDataStats();

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _demoDataService.getDemoDataStats();
      if (mounted) {
        setState(() => _stats = stats);
      }
    } catch (_) {}
  }

  void _refreshAllBlocs() {
    if (!mounted) return;
    context.read<OrdersBloc>().add(const LoadOrders());
    context.read<ShipmentsBloc>().add(const LoadShipments());
    context.read<CustomersBloc>().add(const LoadCustomers());
    context.read<DashboardBloc>().add(const LoadDashboardData());
  }

  Future<void> _handleGenerate() async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'demo_data_confirm_gen_title'.i18n(),
      message: 'demo_data_confirm_gen_msg'.i18n(),
      confirmLabel: 'demo_data_confirm_gen_btn'.i18n(),
      cancelLabel: 'common_cancel'.i18n(),
      isDestructive: false,
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'demo_data_loading_gen'.i18n();
    });

    try {
      final stats = await _demoDataService.generateDemoData();
      if (!mounted) return;

      _refreshAllBlocs();
      setState(() => _stats = stats);

      AppToast.showSuccess(
        context,
        'demo_data_gen_success'.trParams({
          'total': stats.totalRecords.toString(),
        }),
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'common_error'.i18n());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRemove() async {
    if (!_stats.hasDemoData) return;

    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'demo_data_confirm_remove_title'.i18n(),
      message: 'demo_data_confirm_remove_msg'.i18n(),
      confirmLabel: 'demo_data_confirm_remove_btn'.i18n(),
      cancelLabel: 'common_cancel'.i18n(),
      isDestructive: true,
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _loadingMessage = 'demo_data_loading_remove'.i18n();
    });

    try {
      final deletedCount = await _demoDataService.removeDemoData();
      if (!mounted) return;

      _refreshAllBlocs();
      await _loadStats();

      if (!mounted) return;
      AppToast.showSuccess(
        context,
        'demo_data_remove_success'.trParams({
          'count': deletedCount.toString(),
        }),
      );
    } catch (e) {
      if (mounted) {
        AppToast.showError(context, 'common_error'.i18n());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentPurple = Color(0xFF8B5CF6);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // رأس القسم والتعريف
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentPurple.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.dataset_outlined,
                  color: accentPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'demo_data_title'.i18n(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'demo_data_desc'.i18n(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // حالة البيانات الحالية في النظام
          if (_stats.hasDemoData) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? AppColors.darkSurfaceMuted
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: context.borderDivider,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'demo_data_active_badge'.trParams({
                      'total': _stats.totalRecords.toString(),
                    }),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      AppBadge(
                        label: 'demo_data_orders_count'.trParams({
                          'count': _stats.ordersCount.toString(),
                        }),
                        color: AppColors.primaryBlue,
                        icon: Icons.receipt_long_rounded,
                      ),
                      AppBadge(
                        label: 'demo_data_shipments_count'.trParams({
                          'count': _stats.shipmentsCount.toString(),
                        }),
                        color: AppColors.statusWarning,
                        icon: Icons.local_shipping_rounded,
                      ),
                      AppBadge(
                        label: 'demo_data_customers_count'.trParams({
                          'count': _stats.customersCount.toString(),
                        }),
                        color: AppColors.primaryGreen,
                        icon: Icons.people_alt_rounded,
                      ),
                      AppBadge(
                        label: 'demo_data_items_count'.trParams({
                          'count': _stats.itemsCount.toString(),
                        }),
                        color: accentPurple,
                        icon: Icons.category_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: context.isDarkMode
                    ? AppColors.darkSurfaceMuted
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'demo_data_none_badge'.i18n(),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // حالة التحميل أثناء العملية
          if (_isLoading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _loadingMessage,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // زران متجاوران: زر التوليد وزر الإزالة
            Row(
              children: [
                // زر توليد البيانات
                Expanded(
                  flex: 5,
                  child: AppButton(
                    label: 'demo_data_generate_btn'.i18n(),
                    icon: Icons.auto_awesome_rounded,
                    variant: AppButtonVariant.primary,
                    size: AppButtonSize.medium,
                    onPressed: _isLoading ? null : _handleGenerate,
                  ),
                ),
                const SizedBox(width: 10),
                // زر إزالة البيانات (مجاور لزر التوليد)
                Expanded(
                  flex: 5,
                  child: AppButton(
                    label: 'demo_data_remove_btn'.i18n(),
                    icon: Icons.delete_sweep_rounded,
                    variant: AppButtonVariant.danger,
                    size: AppButtonSize.medium,
                    onPressed:
                        (_stats.hasDemoData && !_isLoading)
                            ? _handleRemove
                            : null,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
