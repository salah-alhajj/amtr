import 'package:flutter/material.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/product.dart';
import '../../data/repositories/product_repository_impl.dart';

/// نافذة اختيار منتج أو أكثر من الكتالوج لإضافتها سريعاً للطلب
class ProductPickerSheet extends StatefulWidget {
  const ProductPickerSheet({super.key});

  static Future<List<Product>?> show(BuildContext context) {
    return showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const ProductPickerSheet(),
    );
  }

  @override
  State<ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<ProductPickerSheet> {
  final _repo = ProductRepositoryImpl();
  final _searchController = TextEditingController();
  List<Product> _allProducts = [];
  List<Product> _filtered = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await _repo.getActiveProducts();
    if (!mounted) return;
    setState(() {
      _allProducts = list;
      _filtered = list;
      _isLoading = false;
    });
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allProducts;
      } else {
        _filtered = _allProducts
            .where((p) => p.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = CurrencyService.instance;
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderDivider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'product_pick_from_catalog'.i18n(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_selectedIds.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () {
                        final selected = _allProducts
                            .where((p) => _selectedIds.contains(p.id))
                            .toList();
                        Navigator.pop(context, selected);
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: Text('${'common_add'.i18n()} (${_selectedIds.length})'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppSearchBar(
                controller: _searchController,
                hintText: 'product_search_hint'.i18n(),
                onChanged: _filter,
                onClear: () => _filter(''),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? AppShimmer.list(itemCount: 4)
                  : _filtered.isEmpty
                  ? EmptyStateView(
                      icon: Icons.storefront_outlined,
                      title: 'products_empty_title'.i18n(),
                      subtitle: 'products_empty_subtitle'.i18n(),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (context, idx) {
                        final p = _filtered[idx];
                        final selected = _selectedIds.contains(p.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedIds.add(p.id);
                              } else {
                                _selectedIds.remove(p.id);
                              }
                            });
                          },
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${p.unit} • ${cs.formatAmount(p.sellPrice, currencyCode: p.currency)}'
                            '${p.trackStock ? ' • ${'product_stock_label'.i18n()}: ${p.stockQuantity}' : ' • ${'product_made_to_order'.i18n()}'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: p.isOutOfStock
                                  ? AppColors.statusDanger
                                  : context.textSecondary,
                            ),
                          ),
                          secondary: AppBadge(
                            label: p.category.i18n(),
                            color: AppColors.primaryBlue,
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
