import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/supplier.dart';
import '../../data/repositories/supplier_repository_impl.dart';
import '../bloc/suppliers_bloc.dart';
import '../widgets/add_edit_supplier_sheet.dart';
import 'supplier_details_screen.dart';

class SuppliersListScreen extends StatefulWidget {
  const SuppliersListScreen({super.key});

  @override
  State<SuppliersListScreen> createState() => _SuppliersListScreenState();
}

class _SuppliersListScreenState extends State<SuppliersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final SuppliersBloc _bloc;
  bool _ownsBloc = false;

  @override
  void initState() {
    super.initState();
    try {
      _bloc = context.read<SuppliersBloc>();
      if (_bloc.state is SuppliersInitial) {
        _bloc.add(const LoadSuppliers());
      }
    } catch (_) {
      _ownsBloc = true;
      _bloc = SuppliersBloc(repository: SupplierRepositoryImpl())
        ..add(const LoadSuppliers());
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

  void _openAddEditSheet([Supplier? supplier]) {
    AddEditSupplierSheet.show(
      context,
      supplierToEdit: supplier,
      onSave: (saved) {
        if (supplier == null) {
          _bloc.add(CreateSupplierEvent(saved));
          AppToast.showSuccess(context, 'supplier_added_success'.i18n());
        } else {
          _bloc.add(UpdateSupplierEvent(saved));
          AppToast.showSuccess(context, 'supplier_updated_success'.i18n());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();

    return BlocProvider<SuppliersBloc>.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: Text('suppliers_title'.i18n()),
        ),
        body: BlocBuilder<SuppliersBloc, SuppliersState>(
          builder: (context, state) {
            final selectedCategory =
                state is SuppliersLoaded ? state.selectedCategory : 'all';
            final totalPayablesYer =
                state is SuppliersLoaded ? state.totalPayablesYer : 0.0;

            return Column(
              children: [
                if (totalPayablesYer > 0)
                  _buildPayablesSummaryBanner(context, totalPayablesYer),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'supplier_search_hint'.i18n(),
                    onChanged: (val) => _bloc.add(SearchSuppliers(val)),
                    onClear: () => _bloc.add(const SearchSuppliers('')),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _buildCategoryChip(
                          'status_all'.i18n(), 'all', selectedCategory),
                      ...AppConstants.supplierCategories.map(
                        (cat) => _buildCategoryChip(
                            cat.i18n(), cat, selectedCategory),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          heroTag: 'suppliers_fab',
          onPressed: () => _openAddEditSheet(),
          backgroundColor: AppColors.primaryBlue,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            'supplier_add_title'.i18n(),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildPayablesSummaryBanner(
    BuildContext context,
    double totalPayablesYer,
  ) {
    final cs = CurrencyService.instance;
    final activeCurrency = cs.activeDisplayCurrency;
    final formatted = cs.formatAmount(
      cs.fromBaseYer(totalPayablesYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    const warmAmber = Color(0xFFD97706);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: warmAmber.withValues(alpha: context.isDarkMode ? 0.16 : 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: warmAmber.withValues(alpha: 0.30),
            width: 0.9,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: warmAmber.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                size: 18,
                color: warmAmber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'supplier_total_payables_banner'.trParams({
                  'amount': formatted,
                }),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: warmAmber,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value, String current) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: AppFilterChip(
        label: label,
        isSelected: value == current,
        activeColor: AppColors.primaryBlue,
        onSelected: (_) => _bloc.add(FilterSuppliersByCategory(value)),
      ),
    );
  }

  Widget _buildBody(BuildContext context, SuppliersState state) {
    if (state is SuppliersLoading || state is SuppliersInitial) {
      return AppShimmer.list(itemCount: 4);
    }
    if (state is SuppliersError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => _bloc.add(const LoadSuppliers()),
      );
    }
    if (state is SuppliersLoaded) {
      if (state.displayedSuppliers.isEmpty) {
        return EmptyStateView(
          icon: Icons.local_shipping_outlined,
          title: 'suppliers_empty_title'.i18n(),
          subtitle: 'suppliers_empty_subtitle'.i18n(),
          actionLabel: 'supplier_add_title'.i18n(),
          actionIcon: Icons.add,
          onActionPressed: () => _openAddEditSheet(),
        );
      }

      final cs = CurrencyService.instance;
      final activeCurrency = cs.activeDisplayCurrency;

      return RefreshIndicator(
        onRefresh: () async => _bloc.add(const LoadSuppliers()),
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
          itemCount: state.displayedSuppliers.length,
          itemBuilder: (context, idx) {
            final s = state.displayedSuppliers[idx];
            final linkedCount = state.linkedProductCounts[s.id] ?? 0;
            final balanceYer = state.supplierBalancesYer[s.id] ?? 0.0;
            return AppCard(
              margin: const EdgeInsets.only(bottom: 10),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BlocProvider<SuppliersBloc>.value(
                      value: _bloc,
                      child: SupplierDetailsScreen(supplier: s),
                    ),
                  ),
                );
                if (mounted) {
                  _bloc.add(const LoadSuppliers());
                }
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        AppColors.primaryBlue.withValues(alpha: 0.12),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            AppBadge(
                              label: s.category.i18n(),
                              color: AppColors.primaryBlue,
                              fontSize: 10,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (s.phone != null && s.phone!.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 13,
                                    color: context.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    s.phone!,
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            AppBadge(
                              label: 'supplier_products_count'.trParams({
                                'count': linkedCount.toString(),
                              }),
                              color: AppColors.primaryGreen,
                              fontSize: 10,
                            ),
                            if (balanceYer > 0)
                              AppBadge(
                                label: 'supplier_owed_badge'.trParams({
                                  'amount': cs.formatAmount(
                                    cs.fromBaseYer(balanceYer, activeCurrency),
                                    currencyCode: activeCurrency,
                                  ),
                                }),
                                color: const Color(0xFFD97706),
                                fontSize: 10,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 19,
                      color: AppColors.primaryBlue,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openAddEditSheet(s),
                    tooltip: 'common_edit'.i18n(),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
