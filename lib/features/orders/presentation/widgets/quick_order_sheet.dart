import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/preferences_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../../models/order_item.dart';
import '../../../../models/product.dart';
import '../../../../models/product_variant.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../domain/services/order_business_service.dart';
import '../../domain/whatsapp_order_parser.dart';
import '../screens/add_edit_order_screen.dart';

class _QuickVariantLine {
  final Product product;
  final ProductVariant variant;
  int quantity;

  _QuickVariantLine({
    required this.product,
    required this.variant,
    this.quantity = 1,
  });
}

class _QuickCustomItem {
  final String id;
  final String name;
  final double sellPrice;
  final double costPrice;
  int quantity = 1;

  _QuickCustomItem({
    required this.id,
    required this.name,
    required this.sellPrice,
    this.costPrice = 0.0,
  });
}

/// ورقة البيع السريع في 10 ثوانٍ لوضع الأسر المنتجة والبزنس الصغير
class QuickOrderSheet extends StatefulWidget {
  final bool initialInstantCash;

  const QuickOrderSheet({
    super.key,
    this.initialInstantCash = false,
  });

  static Future<bool?> show(
    BuildContext context, {
    bool initialInstantCash = false,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => QuickOrderSheet(
        initialInstantCash: initialInstantCash,
      ),
    );
  }

  @override
  State<QuickOrderSheet> createState() => _QuickOrderSheetState();
}

class _QuickOrderSheetState extends State<QuickOrderSheet> {
  final OrderBusinessService _orderService = AppServices.instance.orderService;

  final _customNameCtrl = TextEditingController();
  final _customSellCtrl = TextEditingController();
  final _customCostCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _depositRequiredCtrl = TextEditingController();
  final _deliveryAddressCtrl = TextEditingController();
  final _deliveryFeeCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Product> _products = [];
  Map<String, List<ProductVariant>> _variantsByProduct = {};
  List<Customer> _customers = [];
  List<IndividualOrder> _existingOrders = [];
  bool _isLoadingData = true;
  bool _isSaving = false;
  bool _showCustomItemForm = false;
  bool _requiresDeposit = false;
  late bool _isInstantCashSale;

  /// كمية كل منتج مختار من الكتالوج (productId -> qty)
  final Map<String, int> _selectedProductQty = {};
  /// بنود المنتجات ذات المتغيرات المختارة (variantId -> line)
  final Map<String, _QuickVariantLine> _selectedVariantLines = {};
  final List<_QuickCustomItem> _customItems = [];

  bool _isWalkIn = true;
  String? _selectedCustomerId;

  String _paymentStatus = AppConstants.paymentPrepaid;
  String _deliveryDateOption = 'today'; // today, tomorrow, custom
  DateTime _expectedDeliveryDate = DateTime.now();

  String _deliveryType = AppConstants.deliveryPickup;
  late final String _currency;

  @override
  void initState() {
    super.initState();
    _isInstantCashSale = widget.initialInstantCash;
    _currency = PreferencesService.instance.getDefaultCurrency();
    _loadInitialData();
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _customSellCtrl.dispose();
    _customCostCtrl.dispose();
    _customerNameCtrl.dispose();
    _depositCtrl.dispose();
    _depositRequiredCtrl.dispose();
    _deliveryAddressCtrl.dispose();
    _deliveryFeeCtrl.dispose();
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final data = await _orderService.loadQuickOrderData();
      if (!mounted) return;
      setState(() {
        _products = data.products;
        _customers = data.customers;
        _variantsByProduct = data.activeVariantsByProduct;
        _existingOrders = data.existingOrders;
        _isLoadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  double _amountInOrderCurrency(double amount, String fromCurrency) {
    if (fromCurrency == _currency) return amount;
    return CurrencyService.instance.convert(
      amount: amount,
      fromCurrency: fromCurrency,
      toCurrency: _currency,
    );
  }

  double _productSellInOrderCurrency(Product product) {
    return _amountInOrderCurrency(product.sellPrice, product.currency);
  }

  double _productCostInOrderCurrency(Product product) {
    return _amountInOrderCurrency(product.costPrice, product.currency);
  }

  double _calculateItemsTotal() {
    double total = 0.0;
    for (final entry in _selectedProductQty.entries) {
      if (entry.value <= 0) continue;
      final product = _products.firstWhere(
        (p) => p.id == entry.key,
        orElse: () => Product(id: '', name: '', sellPrice: 0),
      );
      if (product.id.isEmpty) continue;
      total += _productSellInOrderCurrency(product) * entry.value;
    }
    for (final line in _selectedVariantLines.values) {
      final sell = line.variant.sellPrice ?? line.product.sellPrice;
      total +=
          _amountInOrderCurrency(sell, line.product.currency) * line.quantity;
    }
    for (final custom in _customItems) {
      total += custom.sellPrice * custom.quantity;
    }
    return total;
  }

  double _calculateTotalSell() {
    final itemsTotal = _calculateItemsTotal();
    final deliveryFee = _deliveryType == AppConstants.deliveryDelivery
        ? (double.tryParse(_deliveryFeeCtrl.text.trim()) ?? 0.0)
        : 0.0;
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    return OrderBusinessService.calculateNetTotal(
      itemsTotal: itemsTotal,
      deliveryFee: deliveryFee,
      discount: discount,
    );
  }

  int _totalItemCount() {
    int count = 0;
    for (final q in _selectedProductQty.values) {
      count += q;
    }
    for (final line in _selectedVariantLines.values) {
      count += line.quantity;
    }
    for (final c in _customItems) {
      count += c.quantity;
    }
    return count;
  }

  int _totalQtyForProduct(String productId) {
    int total = _selectedProductQty[productId] ?? 0;
    for (final line in _selectedVariantLines.values) {
      if (line.product.id == productId) {
        total += line.quantity;
      }
    }
    return total;
  }

  Future<void> _pickVariantForProduct(Product product) async {
    final variants = _variantsByProduct[product.id] ?? const [];
    if (variants.isEmpty) {
      _adjustProductQty(product.id, 1);
      return;
    }
    final picked = await showAppModalSheet<ProductVariant>(
      context: context,
      title: product.name,
      subtitle: 'quick_order_pick_variant_subtitle'.i18n(),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: variants.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (ctx, idx) {
          final v = variants[idx];
          final outOfStock = v.stockQuantity <= 0;
          final effectiveSell = _amountInOrderCurrency(
            v.sellPrice ?? product.sellPrice,
            product.currency,
          );
          return ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: !outOfStock,
            title: Text(
              v.variantName,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: outOfStock ? context.textSecondary : context.textPrimary,
              ),
            ),
            subtitle: Text(
              outOfStock
                  ? 'product_variant_out_of_stock'.i18n()
                  : 'product_variant_remaining_stock'.trParams({
                      'stock': v.stockQuantity.toString(),
                    }),
              style: TextStyle(
                fontSize: 12,
                color: outOfStock
                    ? AppColors.statusDanger
                    : context.textSecondary,
              ),
            ),
            trailing: CurrencyPriceDisplay(
              amount: effectiveSell,
              currency: _currency,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: outOfStock ? context.textSecondary : context.primaryBlue,
              ),
            ),
            onTap: outOfStock ? null : () => Navigator.pop(ctx, v),
          );
        },
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final existing = _selectedVariantLines[picked.id];
      if (existing != null) {
        existing.quantity++;
      } else {
        _selectedVariantLines[picked.id] = _QuickVariantLine(
          product: product,
          variant: picked,
          quantity: 1,
        );
      }
    });
  }

  void _adjustProductQty(String productId, int delta) {
    setState(() {
      final current = _selectedProductQty[productId] ?? 0;
      final next = current + delta;
      if (next <= 0) {
        _selectedProductQty.remove(productId);
      } else {
        _selectedProductQty[productId] = next;
      }
    });
  }

  void _addCustomItem() {
    final name = _customNameCtrl.text.trim();
    final sell = double.tryParse(_customSellCtrl.text.trim());
    final cost = double.tryParse(_customCostCtrl.text.trim()) ?? 0.0;

    if (name.isEmpty) {
      AppToast.showError(context, 'item_name_label'.i18n());
      return;
    }
    if (sell == null || sell <= 0) {
      AppToast.showError(context, 'validation_amount_positive'.i18n());
      return;
    }

    setState(() {
      _customItems.add(
        _QuickCustomItem(
          id: const Uuid().v4(),
          name: name,
          sellPrice: sell,
          costPrice: cost < 0 ? 0.0 : cost,
        ),
      );
      _customNameCtrl.clear();
      _customSellCtrl.clear();
      _customCostCtrl.clear();
      _showCustomItemForm = false;
    });
  }

  Future<void> _pickFromContacts() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      AppToast.showInfo(context, 'contacts_pick_tooltip'.i18n());
      return;
    }

    try {
      final hasPermission = await FlutterContacts.permissions.has(
        PermissionType.read,
      );
      if (!hasPermission) {
        final status = await FlutterContacts.permissions.request(
          PermissionType.read,
        );
        if (status != PermissionStatus.granted &&
            status != PermissionStatus.limited) {
          if (mounted) {
            AppToast.showError(context, 'contacts_permission_denied'.i18n());
          }
          return;
        }
      }

      final contact = await FlutterContacts.native.showPicker(
        properties: {ContactProperty.phone, ContactProperty.name},
      );
      if (contact == null || !mounted) return;

      final displayName = contact.displayName?.trim() ?? '';
      if (displayName.isNotEmpty) {
        setState(() {
          _isWalkIn = false;
          _selectedCustomerId = null;
          _customerNameCtrl.text = displayName;
        });
      }
    } catch (e) {
      debugPrint('QuickOrderSheet contact pick error: $e');
    }
  }

  Customer? _findMatchingCustomer(String? name, String? phone) {
    if (phone != null && phone.trim().isNotEmpty) {
      final parsedWa = YemenPhoneHelper.cleanForWhatsApp(phone);
      final parsedDigits = parsedWa.length >= 9
          ? parsedWa.substring(parsedWa.length - 9)
          : parsedWa;
      if (parsedDigits.isNotEmpty) {
        for (final c in _customers) {
          for (final candidate in [c.phone, c.whatsapp]) {
            if (candidate == null || candidate.trim().isEmpty) continue;
            final candWa = YemenPhoneHelper.cleanForWhatsApp(candidate);
            final candDigits = candWa.length >= 9
                ? candWa.substring(candWa.length - 9)
                : candWa;
            if (candDigits == parsedDigits) return c;
          }
        }
      }
    }

    if (name != null && name.trim().isNotEmpty) {
      final normName = WhatsAppOrderParser.normalizeText(name).trim();
      if (normName.isNotEmpty) {
        for (final c in _customers) {
          if (WhatsAppOrderParser.normalizeText(c.name).trim() == normName) {
            return c;
          }
        }
      }
    }

    return null;
  }

  void _applyParsedWhatsAppOrder(ParsedWhatsAppOrder parsed) {
    final matchedCustomer = _findMatchingCustomer(
      parsed.customerName,
      parsed.customerPhone,
    );

    setState(() {
      for (final line in parsed.matchedItems) {
        final current = _selectedProductQty[line.product.id] ?? 0;
        _selectedProductQty[line.product.id] = current + line.quantity;
      }

      if (matchedCustomer != null) {
        _isWalkIn = false;
        _selectedCustomerId = matchedCustomer.id;
        _customerNameCtrl.text = matchedCustomer.name;
      } else if ((parsed.customerName != null &&
              parsed.customerName!.trim().isNotEmpty) ||
          (parsed.customerPhone != null &&
              parsed.customerPhone!.trim().isNotEmpty)) {
        _isWalkIn = false;
        _selectedCustomerId = null;
        _customerNameCtrl.text =
            parsed.customerName?.trim().isNotEmpty == true
                ? parsed.customerName!.trim()
                : parsed.customerPhone!.trim();
        if (parsed.customerPhone != null &&
            parsed.customerPhone!.trim().isNotEmpty &&
            parsed.customerName?.trim().isNotEmpty == true) {
          final existingNotes = _notesCtrl.text.trim();
          final phoneText = parsed.customerPhone!.trim();
          if (!existingNotes.contains(phoneText)) {
            _notesCtrl.text = existingNotes.isEmpty
                ? phoneText
                : '$existingNotes | $phoneText';
          }
        }
      }

      if (parsed.deliveryType != null) {
        _deliveryType = parsed.deliveryType!;
      }
      if (parsed.deliveryAddress != null &&
          parsed.deliveryAddress!.trim().isNotEmpty) {
        _deliveryAddressCtrl.text = parsed.deliveryAddress!.trim();
        if (parsed.deliveryType == null) {
          _deliveryType = AppConstants.deliveryDelivery;
        }
      }

      if (parsed.rawNotes != null && parsed.rawNotes!.trim().isNotEmpty) {
        final existingNotes = _notesCtrl.text.trim();
        final newNote = parsed.rawNotes!.trim();
        if (existingNotes.isEmpty) {
          _notesCtrl.text = newNote;
        } else if (!existingNotes.contains(newNote)) {
          _notesCtrl.text = '$existingNotes | $newNote';
        }
      }
    });

    if (!mounted) return;
    if (parsed.matchedItems.isNotEmpty) {
      AppToast.showSuccess(
        context,
        'quick_order_wa_parsed_items'.trParams({
          'count': parsed.matchedItems.length.toString(),
        }),
      );
    } else if (parsed.hasAnyData) {
      AppToast.showInfo(context, 'quick_order_wa_parsed_no_items'.i18n());
    } else {
      AppToast.showInfo(context, 'quick_order_wa_parsed_empty'.i18n());
    }
  }

  Future<void> _openWhatsAppPasteSheet() async {
    final textCtrl = TextEditingController();
    final parsed = await showAppModalSheet<ParsedWhatsAppOrder>(
      context: context,
      title: 'quick_order_paste_whatsapp'.i18n(),
      subtitle: 'quick_order_paste_wa_subtitle'.i18n(),
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      final clipText = data?.text?.trim() ?? '';
                      if (clipText.isEmpty) {
                        if (sheetCtx.mounted) {
                          AppToast.showInfo(
                            sheetCtx,
                            'quick_order_clipboard_empty'.i18n(),
                          );
                        }
                        return;
                      }
                      setSheetState(() {
                        textCtrl.text = clipText;
                        textCtrl.selection = TextSelection.collapsed(
                          offset: clipText.length,
                        );
                      });
                    },
                    icon: const Icon(Icons.content_paste_rounded, size: 18),
                    label: Text(
                      'quick_order_paste_clipboard_btn'.i18n(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: textCtrl,
                  label: 'quick_order_paste_whatsapp'.i18n(),
                  hint: 'quick_order_paste_wa_hint'.i18n(),
                  maxLines: 5,
                ),
                const SizedBox(height: 14),
                AppPrimaryButton(
                  label: 'quick_order_parse_fill_btn'.i18n(),
                  icon: Icons.auto_fix_high_rounded,
                  backgroundColor: const Color(0xFF16A34A),
                  onPressed: () {
                    final raw = textCtrl.text.trim();
                    if (raw.isEmpty) {
                      AppToast.showWarning(
                        sheetCtx,
                        'quick_order_paste_empty_error'.i18n(),
                      );
                      return;
                    }
                    final result = WhatsAppOrderParser.parse(raw, _products);
                    Navigator.pop(sheetCtx, result);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
    textCtrl.dispose();
    if (parsed != null && mounted) {
      _applyParsedWhatsAppOrder(parsed);
    }
  }

  Widget _buildWhatsAppPasteBanner(BuildContext context) {
    const waGreen = Color(0xFF16A34A);
    return InkWell(
      onTap: _openWhatsAppPasteSheet,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: waGreen.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: waGreen.withValues(alpha: 0.32),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: waGreen.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.content_paste_go_rounded,
                size: 18,
                color: waGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'quick_order_paste_whatsapp'.i18n(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: waGreen,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'quick_order_paste_wa_subtitle'.i18n(),
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
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: waGreen,
            ),
          ],
        ),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount <= 0) return '0';
    return amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
  }

  Future<void> _saveQuickOrder() async {
    if (_totalItemCount() == 0) {
      AppToast.showError(context, 'quick_order_tap_catalog'.i18n());
      return;
    }

    final totalSell = _calculateTotalSell();
    double paidAmount = 0.0;
    if (_isInstantCashSale || _paymentStatus == AppConstants.paymentPrepaid) {
      paidAmount = totalSell;
    } else if (_paymentStatus == AppConstants.paymentPartial) {
      paidAmount = double.tryParse(_depositCtrl.text.trim()) ?? 0.0;
      if (paidAmount < 0 || (totalSell > 0 && paidAmount > totalSell + 0.01)) {
        AppToast.showError(context, 'validation_amount_exceeds_total'.i18n());
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final orderId = const Uuid().v4();
      final orderNumber = DateTime.now().millisecondsSinceEpoch
          .toString()
          .substring(7);
      final List<OrderItem> items = [];

      for (final entry in _selectedProductQty.entries) {
        if (entry.value <= 0) continue;
        final product = _products.firstWhere(
          (p) => p.id == entry.key,
          orElse: () => Product(id: '', name: '', sellPrice: 0),
        );
        if (product.id.isEmpty) continue;
        items.add(
          OrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            productId: product.id,
            name: product.name,
            quantity: entry.value,
            costPrice: _productCostInOrderCurrency(product),
            sellPrice: _productSellInOrderCurrency(product),
            currency: _currency,
          ),
        );
      }

      for (final line in _selectedVariantLines.values) {
        if (line.quantity <= 0) continue;
        final sell = line.variant.sellPrice ?? line.product.sellPrice;
        final cost = line.variant.costPrice ?? line.product.costPrice;
        items.add(
          OrderItem(
            id: const Uuid().v4(),
            orderId: orderId,
            productId: line.product.id,
            variantId: line.variant.id,
            variantName: line.variant.variantName,
            name: line.product.name,
            quantity: line.quantity,
            costPrice: _amountInOrderCurrency(cost, line.product.currency),
            sellPrice: _amountInOrderCurrency(sell, line.product.currency),
            currency: _currency,
          ),
        );
      }

      for (final custom in _customItems) {
        items.add(
          OrderItem(
            id: custom.id,
            orderId: orderId,
            name: custom.name,
            quantity: custom.quantity,
            costPrice: custom.costPrice,
            sellPrice: custom.sellPrice,
            currency: _currency,
          ),
        );
      }

      String? resolvedCustomerName;
      if (_isInstantCashSale || _isWalkIn) {
        resolvedCustomerName = 'quick_order_customer_walkin'.i18n();
      } else if (_selectedCustomerId != null) {
        final found = _customers.firstWhere(
          (c) => c.id == _selectedCustomerId,
          orElse: () => Customer(id: '', name: ''),
        );
        resolvedCustomerName = found.name.isNotEmpty
            ? found.name
            : 'quick_order_customer_walkin'.i18n();
      } else {
        final typed = _customerNameCtrl.text.trim();
        resolvedCustomerName = typed.isNotEmpty
            ? typed
            : 'quick_order_customer_walkin'.i18n();
      }

      final deliveryFee =
          (!_isInstantCashSale && _deliveryType == AppConstants.deliveryDelivery)
          ? (double.tryParse(_deliveryFeeCtrl.text.trim()) ?? 0.0)
          : 0.0;
      final discount = _isInstantCashSale
          ? 0.0
          : (double.tryParse(_discountCtrl.text.trim()) ?? 0.0);

      final order = IndividualOrder(
        id: orderId,
        orderNumber: orderNumber,
        customerId: (_isInstantCashSale || _isWalkIn) ? null : _selectedCustomerId,
        customerName: resolvedCustomerName,
        paymentStatus: _isInstantCashSale
            ? AppConstants.paymentPrepaid
            : _paymentStatus,
        orderStatus: _isInstantCashSale
            ? AppConstants.orderStatusDelivered
            : AppConstants.orderStatusPending,
        expectedDeliveryDate:
            _isInstantCashSale ? DateTime.now() : _expectedDeliveryDate,
        paidAmount: paidAmount,
        discount: discount,
        deliveryFee: deliveryFee,
        deliveryType:
            _isInstantCashSale ? AppConstants.deliveryPickup : _deliveryType,
        deliveryAddress:
            (!_isInstantCashSale &&
                _deliveryType == AppConstants.deliveryDelivery &&
                _deliveryAddressCtrl.text.trim().isNotEmpty)
            ? _deliveryAddressCtrl.text.trim()
            : null,
        isQuickOrder: true,
        requiresDeposit: _isInstantCashSale ? false : _requiresDeposit,
        depositAmount: (!_isInstantCashSale && _requiresDeposit)
            ? (double.tryParse(_depositRequiredCtrl.text.trim()) ?? 0.0)
            : 0.0,
        currency: _currency,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        items: items,
      );

      await _orderService.saveQuickOrder(order, items);

      if (!mounted) return;
      AppToast.showSuccess(context, 'quick_order_saved_success'.i18n());
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.showError(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalSell = _calculateTotalSell();

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
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
                    Icon(
                      Icons.flash_on_rounded,
                      color: context.primaryBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'quick_order_title'.i18n(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context, false),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: _isLoadingData
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSaleModeSwitcher(context),
                          const SizedBox(height: 12),
                          if (_isInstantCashSale) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.primaryGreen
                                      .withValues(alpha: 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.flash_on_rounded,
                                    size: 16,
                                    color: AppColors.primaryGreen,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'quick_order_instant_cash_hint'.i18n(),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        height: 1.35,
                                        color: context.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ] else ...[
                            _buildWhatsAppPasteBanner(context),
                            const SizedBox(height: 14),
                          ],
                          _buildStepOneItems(context),
                          if (!_isInstantCashSale) ...[
                            const SizedBox(height: 16),
                            _buildStepTwoCustomer(context),
                            const SizedBox(height: 16),
                            _buildStepThreePaymentAndDate(context, totalSell),
                            const SizedBox(height: 12),
                            _buildMoreOptionsExpansion(context),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
              ),
              _buildBottomSaveBar(context, totalSell),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepOneItems(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'quick_order_tap_catalog'.i18n(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _showCustomItemForm = !_showCustomItemForm),
                icon: Icon(
                  _showCustomItemForm
                      ? Icons.close_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  'quick_order_custom_item'.i18n(),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        if (_products.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final product = _products[index];
                final hasVariants =
                    (_variantsByProduct[product.id] ?? const []).isNotEmpty;
                final qty = _totalQtyForProduct(product.id);
                final sell = _productSellInOrderCurrency(product);
                return Container(
                  width: 152,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: qty > 0
                        ? context.primaryBlue.withValues(alpha: 0.08)
                        : context.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: qty > 0
                          ? context.primaryBlue
                          : context.borderDivider,
                      width: qty > 0 ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CurrencyPriceDisplay(
                        amount: sell,
                        currency: _currency,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: context.primaryBlue,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (!hasVariants)
                            InkWell(
                              onTap: qty > 0
                                  ? () => _adjustProductQty(product.id, -1)
                                  : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: qty > 0
                                      ? context.borderDivider.withValues(
                                          alpha: 0.5,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.remove_rounded,
                                  size: 18,
                                  color: qty > 0
                                      ? context.textPrimary
                                      : context.textSecondary.withValues(
                                          alpha: 0.3,
                                        ),
                                ),
                              ),
                            )
                          else
                            Flexible(
                              child: Text(
                                'quick_order_variants_label'.i18n(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: context.primaryBlue,
                                ),
                              ),
                            ),
                          Text(
                            qty.toString(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: qty > 0
                                  ? context.primaryBlue
                                  : context.textSecondary,
                            ),
                          ),
                          InkWell(
                            onTap: hasVariants
                                ? () => _pickVariantForProduct(product)
                                : () => _adjustProductQty(product.id, 1),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: context.primaryBlue,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        if (_selectedVariantLines.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._selectedVariantLines.entries.map((entry) {
            final vid = entry.key;
            final line = entry.value;
            final unitSell = _amountInOrderCurrency(
              line.variant.sellPrice ?? line.product.sellPrice,
              line.product.currency,
            );
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderDivider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${line.product.name} — ${line.variant.variantName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        CurrencyPriceDisplay(
                          amount: unitSell,
                          currency: _currency,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        if (line.quantity > 1) {
                          line.quantity--;
                        } else {
                          _selectedVariantLines.remove(vid);
                        }
                      });
                    },
                  ),
                  Text(
                    '${line.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: line.quantity < line.variant.stockQuantity
                        ? () => setState(() => line.quantity++)
                        : null,
                  ),
                ],
              ),
            );
          }),
        ],
        if (_showCustomItemForm) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                AppTextField(
                  controller: _customNameCtrl,
                  label: 'item_name_label'.i18n(),
                  prefixIcon: Icons.shopping_bag_outlined,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _customSellCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        label: 'item_sell_price_label'.trParams({
                          'symbol': AppConstants.getCurrencySymbol(
                            _currency,
                          ).i18n(),
                        }),
                        prefixIcon: Icons.sell_outlined,
                        inputFormatters: AppFormatters.positiveDecimal(
                          decimalRange: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppTextField(
                        controller: _customCostCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        label: 'item_cost_price_label'.trParams({
                          'symbol': AppConstants.getCurrencySymbol(
                            _currency,
                          ).i18n(),
                        }),
                        prefixIcon: Icons.price_change_outlined,
                        inputFormatters: AppFormatters.positiveDecimal(
                          decimalRange: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                AppPrimaryButton(
                  onPressed: _addCustomItem,
                  label: 'common_add'.i18n(),
                  icon: Icons.add_rounded,
                ),
              ],
            ),
          ),
        ],
        if (_customItems.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._customItems.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.borderDivider),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        CurrencyPriceDisplay(
                          amount: item.sellPrice,
                          currency: _currency,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, size: 20),
                    onPressed: () {
                      setState(() {
                        if (item.quantity > 1) {
                          item.quantity--;
                        } else {
                          _customItems.removeAt(idx);
                        }
                      });
                    },
                  ),
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    onPressed: () => setState(() => item.quantity++),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Customer? get _selectedCustomer {
    if (_isWalkIn || _selectedCustomerId == null) return null;
    for (final c in _customers) {
      if (c.id == _selectedCustomerId) return c;
    }
    return null;
  }

  Widget _buildRepeatRefusalWarning(BuildContext context, Customer customer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 18,
              color: AppColors.statusWarning,
            ),
          ),
          const SizedBox(width: 8),
            Expanded(
              child: Text(
                'customer_repeat_refusal_warning'.trParams({
                  'count': customer.returnCount.toString(),
                }),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepTwoCustomer(BuildContext context) {
    final selectedCustomer = _selectedCustomer;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'order_customer_info_section'.i18n(),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.contacts_outlined,
                  color: context.primaryBlue,
                  size: 20,
                ),
                tooltip: 'contacts_pick_tooltip'.i18n(),
                onPressed: _pickFromContacts,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('quick_order_customer_walkin'.i18n()),
                selected: _isWalkIn,
                onSelected: (_) {
                  setState(() {
                    _isWalkIn = true;
                    _selectedCustomerId = null;
                    _customerNameCtrl.clear();
                  });
                },
              ),
              ChoiceChip(
                label: Text('quick_order_customer_pick'.i18n()),
                selected: !_isWalkIn,
                onSelected: (_) {
                  setState(() => _isWalkIn = false);
                },
              ),
            ],
          ),
          if (!_isWalkIn) ...[
            const SizedBox(height: 10),
            AppCustomerSearchDropdown(
              customers: _customers,
              selectedCustomerId: _selectedCustomerId,
              onChanged: (customer) {
                setState(() {
                  _selectedCustomerId = customer?.id;
                  if (customer != null) {
                    _customerNameCtrl.text = customer.name;
                    if (!_customers.any((c) => c.id == customer.id)) {
                      _customers.add(customer);
                    }
                  } else {
                    _customerNameCtrl.clear();
                  }
                });
              },
              onCustomerCreated: (newCustomer) {
                setState(() {
                  if (!_customers.any((c) => c.id == newCustomer.id)) {
                    _customers.add(newCustomer);
                  }
                  _selectedCustomerId = newCustomer.id;
                  _customerNameCtrl.text = newCustomer.name;
                });
              },
            ),
            if (selectedCustomer != null &&
                selectedCustomer.hasRepeatRefusals) ...[
              const SizedBox(height: 10),
              _buildRepeatRefusalWarning(context, selectedCustomer),
            ],
            if (_selectedCustomerId == null) ...[
              const SizedBox(height: 10),
              AppTextField(
                controller: _customerNameCtrl,
                label: 'order_quick_customer_name'.i18n(),
                hint: 'order_quick_customer_example'.i18n(),
                prefixIcon: Icons.person_outline_rounded,
                inputFormatters: AppFormatters.personName(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  int _activeOrdersCountForDate(DateTime date) {
    int count = 0;
    for (final o in _existingOrders) {
      if (o.orderStatus == AppConstants.orderStatusDelivered) continue;
      final d = o.expectedDeliveryDate;
      if (d == null) continue;
      if (d.year == date.year && d.month == date.month && d.day == date.day) {
        count++;
      }
    }
    return count;
  }

  Widget _buildDailyCapWarningBanner(
    BuildContext context, {
    required int activeCount,
    required int dailyCap,
  }) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.statusWarning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.statusWarning.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_busy_rounded,
                size: 18,
                color: AppColors.statusWarning,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'order_daily_cap_warning'.trParams({
                    'count': activeCount.toString(),
                    'cap': dailyCap.toString(),
                  }),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  final nextDate = _expectedDeliveryDate.add(
                    const Duration(days: 1),
                  );
                  final isTomorrow =
                      nextDate.year == tomorrow.year &&
                      nextDate.month == tomorrow.month &&
                      nextDate.day == tomorrow.day;
                  setState(() {
                    _expectedDeliveryDate = nextDate;
                    _deliveryDateOption = isTomorrow ? 'tomorrow' : 'custom';
                  });
                },
                icon: const Icon(Icons.next_plan_outlined, size: 16),
                label: Text('order_cap_shift_tomorrow'.i18n()),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final msg =
                      WhatsAppTemplateEngine.buildCapacityFullApologyMessage(
                        fullDate: _expectedDeliveryDate,
                        nextAvailableDate: _expectedDeliveryDate.add(
                          const Duration(days: 1),
                        ),
                      );
                  await SharePlus.instance.share(ShareParams(text: msg));
                },
                icon: const WhatsAppIcon(size: 16),
                label: Text('order_cap_whatsapp_apology'.i18n()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepThreePaymentAndDate(BuildContext context, double totalSell) {
    final paymentStatuses = [
      AppConstants.paymentPrepaid,
      AppConstants.paymentPartial,
      AppConstants.paymentCod,
      AppConstants.paymentDebt,
    ];
    final dailyCap = PreferencesService.instance.getDailyOrderCap();
    final activeCount = dailyCap > 0
        ? _activeOrdersCountForDate(_expectedDeliveryDate)
        : 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'order_payment_status_label'.i18n(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: paymentStatuses.map((status) {
              return ChoiceChip(
                label: Text(
                  AppConstants.getPaymentStatusLabel(
                    status,
                    isProductiveFamily: true,
                  ),
                ),
                selected: _paymentStatus == status,
                onSelected: (_) {
                  setState(() => _paymentStatus = status);
                },
              );
            }).toList(),
          ),
          if (_paymentStatus == AppConstants.paymentPartial) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _depositCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    label: 'order_paid_amount_label'.trParams({
                      'symbol': AppConstants.getCurrencySymbol(
                        _currency,
                      ).i18n(),
                    }),
                    hint: '0.00',
                    prefixIcon: Icons.payments_outlined,
                    inputFormatters: AppFormatters.positiveDecimal(
                      decimalRange: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  label: const Text('50%'),
                  onPressed: () {
                    setState(() {
                      _depositCtrl.text = _formatAmount(totalSell / 2);
                    });
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'order_expected_delivery_date'.i18n(),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text('quick_order_delivery_today'.i18n()),
                selected: _deliveryDateOption == 'today',
                onSelected: (_) {
                  setState(() {
                    _deliveryDateOption = 'today';
                    _expectedDeliveryDate = DateTime.now();
                  });
                },
              ),
              ChoiceChip(
                label: Text('quick_order_delivery_tomorrow'.i18n()),
                selected: _deliveryDateOption == 'tomorrow',
                onSelected: (_) {
                  setState(() {
                    _deliveryDateOption = 'tomorrow';
                    _expectedDeliveryDate = DateTime.now().add(
                      const Duration(days: 1),
                    );
                  });
                },
              ),
              ChoiceChip(
                label: Text(
                  _deliveryDateOption == 'custom'
                      ? '${_expectedDeliveryDate.year}/${_expectedDeliveryDate.month}/${_expectedDeliveryDate.day}'
                      : 'quick_order_delivery_custom'.i18n(),
                ),
                selected: _deliveryDateOption == 'custom',
                onSelected: (_) async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expectedDeliveryDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2035),
                  );
                  if (picked != null && mounted) {
                    setState(() {
                      _deliveryDateOption = 'custom';
                      _expectedDeliveryDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
          if (dailyCap > 0 && activeCount >= dailyCap) ...[
            const SizedBox(height: 10),
            _buildDailyCapWarningBanner(
              context,
              activeCount: activeCount,
              dailyCap: dailyCap,
            ),
          ],
          if (PreferencesService.instance.getFeatureFlags().seasonalDeposit ||
              _requiresDeposit) ...[
            const SizedBox(height: 12),
            AppSwitchTile(
              title: 'order_requires_deposit_label'.i18n(),
              subtitle: 'order_requires_deposit_hint'.i18n(),
              value: _requiresDeposit,
              onChanged: (val) => setState(() => _requiresDeposit = val),
            ),
            if (_requiresDeposit) ...[
              const SizedBox(height: 8),
              AppTextField(
                controller: _depositRequiredCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                label: 'order_deposit_amount_label'.trParams({
                  'symbol': AppConstants.getCurrencySymbol(_currency).i18n(),
                }),
                hint: '0.00',
                prefixIcon: Icons.savings_outlined,
                inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMoreOptionsExpansion(BuildContext context) {
    return AppCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 8),
          title: Text(
            'quick_order_more_options'.i18n(),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: Text('order_delivery_pickup'.i18n()),
                    selected: _deliveryType == AppConstants.deliveryPickup,
                    onSelected: (_) => setState(
                      () => _deliveryType = AppConstants.deliveryPickup,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: Text('order_delivery_home'.i18n()),
                    selected: _deliveryType == AppConstants.deliveryDelivery,
                    onSelected: (_) => setState(
                      () => _deliveryType = AppConstants.deliveryDelivery,
                    ),
                  ),
                ),
              ],
            ),
            if (_deliveryType == AppConstants.deliveryDelivery) ...[
              const SizedBox(height: 10),
              AppTextField(
                controller: _deliveryAddressCtrl,
                label: 'order_delivery_address_label'.i18n(),
                hint: 'order_delivery_address_hint'.i18n(),
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 10),
              AppTextField(
                controller: _deliveryFeeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                label: 'order_delivery_fee_label'.i18n(),
                hint: '0.00',
                prefixIcon: Icons.delivery_dining_outlined,
                inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 10),
            AppTextField(
              controller: _discountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: 'order_discount_label'.i18n(),
              hint: '0.00',
              prefixIcon: Icons.discount_outlined,
              inputFormatters: AppFormatters.positiveDecimal(decimalRange: 2),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            AppTextField(
              controller: _notesCtrl,
              maxLines: 2,
              label: 'order_notes_label'.i18n(),
              hint: 'customer_notes_hint'.i18n(),
              prefixIcon: Icons.notes_rounded,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () {
                  final navigator = Navigator.of(context);
                  navigator.pop(false);
                  navigator.push(
                    MaterialPageRoute(
                      builder: (_) => const AddEditOrderScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text('quick_order_advanced_form'.i18n()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleModeSwitcher(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _buildSaleModeTab(
            label: 'quick_order_mode_instant_cash'.i18n(),
            icon: Icons.bolt_rounded,
            selected: _isInstantCashSale,
            activeColor: AppColors.primaryGreen,
            isDark: isDark,
            onTap: () => setState(() => _isInstantCashSale = true),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildSaleModeTab(
            label: 'quick_order_mode_detailed'.i18n(),
            icon: Icons.tune_rounded,
            selected: !_isInstantCashSale,
            activeColor: AppColors.primaryBlue,
            isDark: isDark,
            onTap: () => setState(() => _isInstantCashSale = false),
          ),
        ),
      ],
    );
  }

  Widget _buildSaleModeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required Color activeColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceMuted),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? activeColor : context.borderSubtle,
            width: selected ? 1.4 : 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? activeColor : context.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? activeColor : context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSaveBar(BuildContext context, double totalSell) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        border: Border(top: BorderSide(color: context.borderDivider)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'order_total_sell_price'.i18n(),
                style: TextStyle(fontSize: 11, color: context.textSecondary),
              ),
              CurrencyPriceDisplay(
                amount: totalSell,
                currency: _currency,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isInstantCashSale
                      ? AppColors.primaryGreen
                      : context.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: AppPrimaryButton(
              onPressed: _isSaving ? null : _saveQuickOrder,
              isLoading: _isSaving,
              backgroundColor:
                  _isInstantCashSale ? AppColors.primaryGreen : null,
              label: _isInstantCashSale
                  ? 'quick_order_save_cash_btn'.i18n()
                  : 'quick_order_save_btn'.i18n(),
              icon: _isInstantCashSale
                  ? Icons.bolt_rounded
                  : Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}
