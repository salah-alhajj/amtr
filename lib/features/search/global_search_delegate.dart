import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/localization/localization.dart';
import '../../core/services/currency_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/yemen_phone_helper.dart';
import '../../core/widgets/design_system.dart';
import '../../models/consolidated_shipment.dart';
import '../../models/customer.dart';
import '../../models/expense.dart';
import '../../models/individual_order.dart';
import '../../models/manufacturing_template.dart';
import '../../models/product.dart';
import '../../models/raw_material.dart';
import '../../models/supplier.dart';
import '../customers/domain/repositories/customer_repository.dart';
import '../customers/presentation/screens/customer_details_screen.dart';
import '../expenses/data/repositories/expense_repository_impl.dart';
import '../expenses/domain/repositories/expense_repository.dart';
import '../expenses/presentation/screens/expenses_list_screen.dart';
import '../manufacturing/data/repositories/manufacturing_template_repository.dart';
import '../manufacturing/data/repositories/raw_material_repository.dart';
import '../manufacturing/presentation/screens/materials_and_templates_screen.dart';
import '../orders/domain/repositories/order_repository.dart';
import '../orders/presentation/screens/order_details_screen.dart';
import '../products/data/repositories/product_repository_impl.dart';
import '../products/domain/repositories/product_repository.dart';
import '../products/presentation/screens/products_list_screen.dart';
import '../shipments/domain/repositories/shipment_repository.dart';
import '../shipments/presentation/screens/shipment_details_screen.dart';
import '../suppliers/data/repositories/supplier_repository_impl.dart';
import '../suppliers/domain/repositories/supplier_repository.dart';
import '../suppliers/presentation/screens/supplier_details_screen.dart';

class GlobalSearchDelegate extends SearchDelegate {
  final OrderRepository orderRepo;
  final ShipmentRepository shipmentRepo;
  final CustomerRepository customerRepo;
  final ProductRepository productRepo;
  final SupplierRepository supplierRepo;
  final ExpenseRepository expenseRepo;
  final RawMaterialRepository rawMaterialRepo;
  final ManufacturingTemplateRepository templateRepo;

  GlobalSearchDelegate({
    required this.orderRepo,
    required this.shipmentRepo,
    required this.customerRepo,
    ProductRepository? productRepo,
    SupplierRepository? supplierRepo,
    ExpenseRepository? expenseRepo,
    RawMaterialRepository? rawMaterialRepo,
    ManufacturingTemplateRepository? templateRepo,
  })  : productRepo = productRepo ?? ProductRepositoryImpl(),
        supplierRepo = supplierRepo ?? SupplierRepositoryImpl(),
        expenseRepo = expenseRepo ?? ExpenseRepositoryImpl(),
        rawMaterialRepo = rawMaterialRepo ?? RawMaterialRepository(),
        templateRepo = templateRepo ?? ManufacturingTemplateRepository(),
        super(
          searchFieldLabel: 'search_global_hint'.i18n(),
          searchFieldStyle: const TextStyle(
            fontFamily: 'IBMPlexSansArabic',
            fontFamilyFallback: AppTheme.fontFamilyFallback,
            fontSize: 14,
          ),
        );

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      appBarTheme: theme.appBarTheme.copyWith(
        backgroundColor: context.surfaceCard,
        iconTheme: IconThemeData(color: context.primaryBlue),
        elevation: 0,
      ),
      textTheme: theme.textTheme.copyWith(
        titleLarge: TextStyle(
          color: context.textPrimary,
          fontSize: 15,
          fontFamily: 'IBMPlexSansArabic',
          fontFamilyFallback: AppTheme.fontFamilyFallback,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(
          color: context.textTertiary,
          fontSize: 14,
          fontFamily: 'IBMPlexSansArabic',
          fontFamilyFallback: AppTheme.fontFamilyFallback,
        ),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: Icon(Icons.clear_rounded, color: context.textSecondary),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    // في واجهة RTL العودة للخلف تكون عبر الأيقونة المعاكسة
    return IconButton(
      icon: BackChevron(size: 18, color: context.primaryBlue),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.trim().isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.search_rounded,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 12),
              Text(
                'search_initial_instruction'.i18n(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return _buildSearchResults();
  }

  Future<List<Product>> _searchProducts(String q) async {
    try {
      final all = await productRepo.getAllProducts();
      final lower = q.toLowerCase();
      return all.where((p) {
        return p.name.toLowerCase().contains(lower) ||
            p.unit.toLowerCase().contains(lower) ||
            p.category.i18n().toLowerCase().contains(lower) ||
            (p.notes ?? '').toLowerCase().contains(lower);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Supplier>> _searchSuppliers(String q) async {
    try {
      final all = await supplierRepo.getAllSuppliers();
      final lower = q.toLowerCase();
      return all.where((s) {
        return s.name.toLowerCase().contains(lower) ||
            (s.phone ?? '').toLowerCase().contains(lower) ||
            (s.whatsapp ?? '').toLowerCase().contains(lower) ||
            (s.address ?? '').toLowerCase().contains(lower) ||
            s.category.i18n().toLowerCase().contains(lower) ||
            (s.notes ?? '').toLowerCase().contains(lower);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<Expense>> _searchExpenses(String q) async {
    try {
      final all = await expenseRepo.getAllExpenses();
      final lower = q.toLowerCase();
      return all.where((e) {
        return e.title.toLowerCase().contains(lower) ||
            e.category.i18n().toLowerCase().contains(lower) ||
            (e.notes ?? '').toLowerCase().contains(lower);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<RawMaterial>> _searchMaterials(String q) async {
    try {
      final all = await rawMaterialRepo.getAll();
      final lower = q.toLowerCase();
      return all.where((m) {
        return m.name.toLowerCase().contains(lower) ||
            m.unit.toLowerCase().contains(lower) ||
            (m.notes ?? '').toLowerCase().contains(lower);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<ManufacturingTemplate>> _searchTemplates(String q) async {
    try {
      final all = await templateRepo.getAllTemplates();
      final lower = q.toLowerCase();
      return all.where((t) {
        return t.name.toLowerCase().contains(lower) ||
            (t.description ?? '').toLowerCase().contains(lower) ||
            t.items.any((i) => i.name.toLowerCase().contains(lower));
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Widget _buildSearchResults() {
    final cleanQuery = query.trim();
    final currencyService = CurrencyService.instance;

    return FutureBuilder(
      future: Future.wait([
        customerRepo.searchCustomers(cleanQuery).catchError((_) => <Customer>[]),
        orderRepo.searchOrders(cleanQuery).catchError((_) => <IndividualOrder>[]),
        shipmentRepo
            .searchShipments(cleanQuery)
            .catchError((_) => <ConsolidatedShipment>[]),
        _searchProducts(cleanQuery),
        _searchSuppliers(cleanQuery),
        _searchExpenses(cleanQuery),
        _searchMaterials(cleanQuery),
        _searchTemplates(cleanQuery),
      ]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final customers = (snapshot.data?[0] as List<Customer>?) ?? [];
        final orders = (snapshot.data?[1] as List<IndividualOrder>?) ?? [];
        final shipments =
            (snapshot.data?[2] as List<ConsolidatedShipment>?) ?? [];
        final products = (snapshot.data?[3] as List<Product>?) ?? [];
        final suppliers = (snapshot.data?[4] as List<Supplier>?) ?? [];
        final expenses = (snapshot.data?[5] as List<Expense>?) ?? [];
        final materials = (snapshot.data?[6] as List<RawMaterial>?) ?? [];
        final templates =
            (snapshot.data?[7] as List<ManufacturingTemplate>?) ?? [];

        if (customers.isEmpty &&
            orders.isEmpty &&
            shipments.isEmpty &&
            products.isEmpty &&
            suppliers.isEmpty &&
            expenses.isEmpty &&
            materials.isEmpty &&
            templates.isEmpty) {
          return Center(
            child: Text(
              'search_no_results'.i18n(),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (customers.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_customers_header'.trParams({
                  'count': '${customers.length}',
                }),
              ),
              ...customers.map(
                (c) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CustomerDetailsScreen(initialCustomer: c),
                      ),
                    );
                  },
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withValues(
                        alpha: 0.1,
                      ),
                      child: Text(
                        c.name.isNotEmpty
                            ? c.name[0].toUpperCase()
                            : (context.isArabic ? 'ع' : 'C'),
                        style: const TextStyle(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      c.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      c.phone != null
                          ? (YemenPhoneHelper.formatForDisplay(
                                c.phone,
                                context: context,
                              ) ??
                              c.phone!)
                          : (c.whatsapp != null && c.whatsapp!.isNotEmpty
                              ? (YemenPhoneHelper.formatForDisplay(
                                    c.whatsapp,
                                    context: context,
                                  ) ??
                                  c.whatsapp!)
                              : 'customer_no_phone'.i18n()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: (c.phone != null ||
                              (c.whatsapp != null && c.whatsapp!.isNotEmpty))
                          ? TextDirection.ltr
                          : null,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const ForwardChevron(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (orders.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_orders_header'.trParams({'count': '${orders.length}'}),
              ),
              ...orders.map(
                (o) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetailsScreen(orderId: o.id),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${o.orderNumber} - ${o.customerName ?? 'customer_quick_default'.i18n()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'order_items_and_status_fmt'.trParams({
                                'count': '${o.items.length}',
                                'status': AppConstants.getPaymentStatusLabel(
                                  o.paymentStatus,
                                ),
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currencyService.formatAmount(
                              o.totalSellPrice,
                              currencyCode: o.currency,
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const ForwardChevron(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (products.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_products_header'.trParams({
                  'count': '${products.length}',
                }),
              ),
              ...products.map((p) {
                final typeColor = AppConstants.getProductTypeColor(
                  p.productType,
                );
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductsListScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          p.isManufactured
                              ? Icons.precision_manufacturing_rounded
                              : Icons.storefront_rounded,
                          size: 18,
                          color: typeColor,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${AppConstants.getProductTypeLabel(p.productType)} • ${p.unit}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyService.formatAmount(
                          p.sellPrice,
                          currencyCode: p.currency,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ForwardChevron(),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            if (suppliers.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_suppliers_header'.trParams({
                  'count': '${suppliers.length}',
                }),
              ),
              ...suppliers.map(
                (sup) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SupplierDetailsScreen(supplier: sup),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.vibrantTeal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: AppColors.vibrantTeal,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sup.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              sup.category.i18n(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (expenses.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_expenses_header'.trParams({
                  'count': '${expenses.length}',
                }),
              ),
              ...expenses.map(
                (e) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ExpensesListScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusDanger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppColors.statusDanger,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${e.category.i18n()} • ${AppConstants.getExpenseRecurrenceLabel(e.recurrence)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyService.formatAmount(
                          e.amount,
                          currencyCode: e.currency,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: AppColors.statusDanger,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (materials.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_materials_header'.trParams({
                  'count': '${materials.length}',
                }),
              ),
              ...materials.map(
                (m) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaterialsAndTemplatesScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.statusWarning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2_outlined,
                          size: 18,
                          color: AppColors.statusWarning,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${m.unit}${m.stockQuantity > 0 ? ' • ${m.stockQuantity.toStringAsFixed(m.stockQuantity.truncateToDouble() == m.stockQuantity ? 0 : 1)}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: m.isLowStock
                                    ? AppColors.statusDanger
                                    : context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyService.formatAmount(
                          m.unitCost,
                          currencyCode: m.currency,
                        ),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (templates.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_templates_header'.trParams({
                  'count': '${templates.length}',
                }),
              ),
              ...templates.map(
                (t) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const MaterialsAndTemplatesScreen(),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.layers_outlined,
                          size: 18,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'mfg_recipe_summary_fmt'.trParams({
                                'items': '${t.items.length}',
                                'yield': '${t.yieldCount}',
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        currencyService.formatAmount(
                          t.unitCost,
                          currencyCode: t.currency,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Color(0xFF7C3AED),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (shipments.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'search_shipments_header'.trParams({
                  'count': '${shipments.length}',
                }),
              ),
              ...shipments.map(
                (s) => AppCard(
                  margin: const EdgeInsets.only(bottom: 8),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ShipmentDetailsScreen(shipmentId: s.id),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '#${s.shipmentNumber} - ${s.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: context.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'shipment_orders_and_status_fmt'.trParams({
                                'count': '${s.orders.length}',
                                'status': AppConstants.getShipmentStatusLabel(
                                  s.status,
                                ),
                              }),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const ForwardChevron(),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: context.textSecondary,
        ),
      ),
    );
  }
}
