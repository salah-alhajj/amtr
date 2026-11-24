import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/courier.dart';
import '../../data/repositories/courier_repository_impl.dart';
import '../bloc/couriers_bloc.dart';
import '../widgets/add_edit_courier_sheet.dart';
import 'courier_details_screen.dart';

/// شاشة قائمة مندوبي التوصيل وملخص عهدة التحصيل النقدي (COD) لكل مندوب
class CouriersListScreen extends StatefulWidget {
  const CouriersListScreen({super.key});

  @override
  State<CouriersListScreen> createState() => _CouriersListScreenState();
}

class _CouriersListScreenState extends State<CouriersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final CouriersBloc _bloc;
  bool _ownsBloc = false;

  @override
  void initState() {
    super.initState();
    try {
      _bloc = context.read<CouriersBloc>();
      if (_bloc.state is CouriersInitial) {
        _bloc.add(const LoadCouriers());
      } else {
        _bloc.add(const LoadCouriers(silent: true));
      }
    } catch (_) {
      _ownsBloc = true;
      _bloc = CouriersBloc(repository: CourierRepositoryImpl())
        ..add(const LoadCouriers());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    if (_ownsBloc) {
      _bloc.close();
    }
    super.dispose();
  }

  void _openAddEditSheet([Courier? courier]) {
    AddEditCourierSheet.show(
      context,
      courierToEdit: courier,
      onSave: (saved) {
        _bloc.add(SaveCourierEvent(saved));
        AppToast.showSuccess(
          context,
          courier == null
              ? 'courier_added_success'.i18n()
              : 'courier_updated_success'.i18n(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();

    return BlocProvider<CouriersBloc>.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('couriers_title'.i18n()),
        ),
        body: BlocBuilder<CouriersBloc, CouriersState>(
          builder: (context, state) {
            final totalNetDue = state is CouriersLoaded
                ? state.allSummaries.fold<double>(
                    0.0,
                    (sum, s) => sum + s.netDueFromCourierYer,
                  )
                : 0.0;
            final totalActive = state is CouriersLoaded
                ? state.allSummaries.fold<int>(
                    0,
                    (sum, s) => sum + s.activeOrdersCount,
                  )
                : 0;
            final totalDeliveredUnsettled = state is CouriersLoaded
                ? state.allSummaries.fold<int>(
                    0,
                    (sum, s) => sum + s.deliveredUnsettledCount,
                  )
                : 0;

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'courier_search_hint'.i18n(),
                    onChanged: (val) => _bloc.add(SearchCouriers(val)),
                    onClear: () => _bloc.add(const SearchCouriers('')),
                  ),
                ),
                if (state is CouriersLoaded && totalNetDue > 0.0001)
                  _buildTotalNetDueStrip(
                    context,
                    totalNetDueYer: totalNetDue,
                    activeCount: totalActive,
                    deliveredUnsettledCount: totalDeliveredUnsettled,
                  ),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'couriers_fab',
          onPressed: () => _openAddEditSheet(),
          backgroundColor: AppColors.primaryBlue,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'courier_add_title'.i18n(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalNetDueStrip(
    BuildContext context, {
    required double totalNetDueYer,
    required int activeCount,
    required int deliveredUnsettledCount,
  }) {
    final cs = CurrencyService.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'couriers_total_net_due'.i18n(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.white.withValues(alpha: 0.88),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cs.formatAmount(
                      totalNetDueYer,
                      currencyCode: AppConstants.currencyYer,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (activeCount > 0 || deliveredUnsettledCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'couriers_active_summary'.trParams({
                        'active': activeCount.toString(),
                        'delivered': deliveredUnsettledCount.toString(),
                      }),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, CouriersState state) {
    if (state is CouriersLoading || state is CouriersInitial) {
      return AppShimmer.list(itemCount: 4);
    }
    if (state is CouriersError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => _bloc.add(const LoadCouriers()),
      );
    }
    if (state is CouriersLoaded) {
      if (state.displayedSummaries.isEmpty) {
        return EmptyStateView(
          icon: Icons.delivery_dining_outlined,
          title: 'couriers_empty_title'.i18n(),
          subtitle: 'couriers_empty_subtitle'.i18n(),
          actionLabel: 'courier_add_title'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () => _openAddEditSheet(),
        );
      }

      return RefreshIndicator(
        onRefresh: () async => _bloc.add(const LoadCouriers()),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: state.displayedSummaries.length,
          itemBuilder: (context, idx) {
            final summary = state.displayedSummaries[idx];
            return _CourierSummaryCard(
              summary: summary,
              onEdit: () => _openAddEditSheet(summary.courier),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider<CouriersBloc>.value(
                      value: _bloc,
                      child: CourierDetailsScreen(courier: summary.courier),
                    ),
                  ),
                );
                if (mounted) {
                  _bloc.add(const LoadCouriers(silent: true));
                }
              },
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _CourierSummaryCard extends StatelessWidget {
  final CourierCustodySummary summary;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _CourierSummaryCard({
    required this.summary,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = CurrencyService.instance;
    final c = summary.courier;
    final hasCollected = summary.collectedCashYer > 0.0001;
    final firstMetricLabel = hasCollected
        ? 'courier_metric_with_courier'.i18n()
        : 'courier_metric_expected_collect'.i18n();
    final firstMetricValue =
        hasCollected ? summary.collectedCashYer : summary.expectedCollectYer;

    final isNegativeNet = summary.netDueFromCourierYer < -0.0001;
    final netColor = isNegativeNet
        ? AppColors.statusWarning
        : (summary.netDueFromCourierYer > 0.0001
            ? AppColors.primaryGreen
            : context.textSecondary);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.12),
                child: const Icon(
                  Icons.delivery_dining_rounded,
                  color: AppColors.primaryBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (c.phone != null && c.phone!.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 12,
                                color: context.textSecondary,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                c.phone!,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        if (summary.activeOrdersCount > 0)
                          AppBadge(
                            label:
                                '${'courier_status_assigned'.i18n()}: ${summary.activeOrdersCount}',
                            color: AppColors.primaryBlue,
                            fontSize: 10,
                          ),
                        if (summary.deliveredUnsettledCount > 0)
                          AppBadge(
                            label:
                                '${'courier_status_delivered'.i18n()}: ${summary.deliveredUnsettledCount}',
                            color: AppColors.primaryGreen,
                            fontSize: 10,
                          ),
                        if (summary.returnedUnsettledCount > 0)
                          AppBadge(
                            label:
                                '${'courier_status_returned'.i18n()}: ${summary.returnedUnsettledCount}',
                            color: AppColors.statusDanger,
                            fontSize: 10,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 19,
                  color: AppColors.primaryBlue,
                ),
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
                tooltip: 'common_edit'.i18n(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 3 أرقام واضحة: المتوقع تحصيله / مع المندوب | أجور التوصيل له | الصافي المطلوب منه لك
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: context.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _MetricCell(
                    label: firstMetricLabel,
                    value: cs.formatAmount(
                      firstMetricValue,
                      currencyCode: AppConstants.currencyYer,
                    ),
                    valueColor: AppColors.primaryBlue,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: context.borderDivider,
                ),
                Expanded(
                  child: _MetricCell(
                    label: 'courier_metric_delivery_fees'.i18n(),
                    value: cs.formatAmount(
                      summary.totalFeesYer,
                      currencyCode: AppConstants.currencyYer,
                    ),
                    valueColor: AppColors.statusWarning,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: context.borderDivider,
                ),
                Expanded(
                  child: _MetricCell(
                    label: isNegativeNet
                        ? 'courier_metric_owed_to_courier'.i18n()
                        : 'courier_metric_net_due_card'.i18n(),
                    value: cs.formatAmount(
                      summary.netDueFromCourierYer.abs(),
                      currencyCode: AppConstants.currencyYer,
                    ),
                    valueColor: netColor,
                  ),
                ),
              ],
            ),
          ),
          if (hasCollected && summary.expectedCollectYer > 0.0001) ...[
            const SizedBox(height: 6),
            Text(
              'courier_in_transit_banner'.trParams({
                'count': summary.activeOrdersCount.toString(),
                'amount': cs.formatAmount(
                  summary.expectedCollectYer,
                  currencyCode: AppConstants.currencyYer,
                ),
              }),
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetricCell({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            color: context.textSecondary,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
