import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../domain/customer_financial_helper.dart';
import '../bloc/customers_bloc.dart';
import 'customer_details_screen.dart';
import '../widgets/add_edit_customer_sheet.dart';
import '../widgets/customer_card.dart';

class CustomersListScreen extends StatefulWidget {
  const CustomersListScreen({super.key});

  @override
  State<CustomersListScreen> createState() => _CustomersListScreenState();
}

class _CustomersListScreenState extends State<CustomersListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddCustomerDialog([Customer? customerToEdit]) {
    AddEditCustomerSheet.show(
      context,
      customerToEdit: customerToEdit,
      onSave: (customer) {
        if (customerToEdit != null) {
          context.read<CustomersBloc>().add(UpdateCustomerEvent(customer));
        } else {
          context.read<CustomersBloc>().add(CreateCustomerEvent(customer));
        }
      },
    );
  }

  Future<void> _openCustomerDetails(Customer customer) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailsScreen(initialCustomer: customer),
      ),
    );
    if (mounted) {
      context.read<CustomersBloc>().add(const LoadCustomers());
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    return Scaffold(
      appBar: AppBar(
        title: Text('customers_title'.i18n()),
      ),
      body: BlocBuilder<CustomersBloc, CustomersState>(
        builder: (context, state) {
          return Column(
            children: [
              AppSearchBar(
                controller: _searchController,
                hintText: 'search_customers_hint'.i18n(),
                onChanged: (val) {
                  context.read<CustomersBloc>().add(SearchCustomers(val));
                },
                onClear: () {
                  context.read<CustomersBloc>().add(const SearchCustomers(''));
                },
              ),
              if (state is CustomersLoaded) _buildFiltersBar(context, state),
              Expanded(
                child: _buildCustomersList(context, state),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers_fab',
        onPressed: () => _showAddCustomerDialog(),
        backgroundColor: AppColors.primaryBlue,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: Text('new_customer'.i18n(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// شريط الفلاتر المنزلق تماماً بدون أي اختناق أو تجاوز بالمساحات
  Widget _buildFiltersBar(BuildContext context, CustomersLoaded state) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: CustomerListFilter.values.map((filter) {
          final isSelected = state.activeFilter == filter;
          final count = state.filterCounts[filter] ?? 0;
          final title = filter.label(context);

          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: AppFilterChip(
              label: title,
              count: count,
              icon: filter.icon,
              customIcon: filter == CustomerListFilter.hasWhatsApp
                  ? WhatsAppIcon(size: 15, color: isSelected ? Colors.white : null)
                  : null,
              isSelected: isSelected,
              activeColor: filter.activeColor,
              showColoredUnselected: true,
              onSelected: (_) {
                context.read<CustomersBloc>().add(FilterCustomersEvent(filter));
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomersList(BuildContext context, CustomersState state) {
    if (state is CustomersLoading || state is CustomersInitial) {
      return AppShimmer.list(itemCount: 6);
    }

    if (state is CustomersError) {
      return AppErrorStateView(
        message: state.message,
        onRetry: () => context.read<CustomersBloc>().add(const LoadCustomers()),
      );
    }

    if (state is CustomersLoaded) {
      if (state.customers.isEmpty) {
        if (state.allCustomers.isEmpty) {
          return EmptyStateView(
            icon: Icons.people_outline,
            title: 'customers_empty_title'.i18n(),
            subtitle: 'customers_empty_subtitle'.i18n(),
            actionLabel: 'new_customer'.i18n(),
            actionIcon: Icons.person_add_alt_1,
            onActionPressed: () => _showAddCustomerDialog(),
          );
        }

        return EmptyStateView(
          icon: Icons.filter_alt_off_outlined,
          title: 'customers_empty_filter_title'.i18n(),
          subtitle: 'customers_empty_filter_subtitle'.i18n(),
          actionLabel: 'customers_clear_filter'.i18n(),
          actionIcon: Icons.refresh_rounded,
          onActionPressed: () {
            _searchController.clear();
            context.read<CustomersBloc>().add(const SearchCustomers(''));
            context.read<CustomersBloc>().add(const FilterCustomersEvent(CustomerListFilter.all));
          },
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          context.read<CustomersBloc>().add(const LoadCustomers());
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.customers.length,
          itemBuilder: (context, index) {
            final customer = state.customers[index];
            final summary = state.summaries[customer.id];
            return CustomerCard(
              customer: customer,
              summary: summary,
              onTap: () => _openCustomerDetails(customer),
              onEdit: () => _showAddCustomerDialog(customer),
            );
          },
        ),
      );
    }

    return const SizedBox.shrink();
  }
}


