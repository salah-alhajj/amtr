import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/customer.dart';
import '../../../../models/individual_order.dart';
import '../../../orders/data/repositories/order_repository_impl.dart';
import '../../../orders/domain/repositories/order_repository.dart';
import '../../../orders/presentation/screens/add_edit_order_screen.dart';
import '../../../orders/presentation/screens/order_details_screen.dart';
import '../../domain/customer_financial_helper.dart';
import '../../domain/customer_whatsapp_helper.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../bloc/customers_bloc.dart';
import '../widgets/add_edit_customer_sheet.dart';
import '../widgets/settle_partial_debt_sheet.dart';
import '../../../printing/presentation/widgets/print_options_sheet.dart';

/// صفحة العميل المتكاملة بتصميم آبل الموحد
/// تحتوي على تابات منفصلة للطلبات، المديونيات كل على حدة مع إمكانية تسديد جزء،
/// والحالة المالية الفعلية (أخضر مستفاد، أحمر مديونيات، أزرق متبقي له)،
/// مع الاحتساب التلقائي من الطلبات السابقة والمعلقة، وخانة للإدخال اليدوي،
/// ودعم المراسلة وإرسال حالة طلب أو مجموعة طلبات محددة عبر واتساب مباشرة.
class CustomerDetailsScreen extends StatefulWidget {
  final Customer initialCustomer;

  const CustomerDetailsScreen({super.key, required this.initialCustomer});

  @override
  State<CustomerDetailsScreen> createState() => _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends State<CustomerDetailsScreen>
    with SingleTickerProviderStateMixin {
  final OrderRepository _orderRepo = OrderRepositoryImpl();
  final CurrencyService _currencyService = CurrencyService.instance;

  late Customer _customer;
  late TabController _tabController;

  List<IndividualOrder> _orders = [];
  bool _isLoading = true;

  // فلاتر الطلبات والاحتساب
  CustomerOrderFilter _calcFilter = CustomerOrderFilter.all;
  String _ordersStatusFilter = 'all'; // all, pending, delivered

  // وضع تحديد طلبات متعددة لإرسال تقرير بها عبر واتساب
  bool _isSelectionMode = false;
  final Set<String> _selectedOrderIds = {};

  // حقول الإدخال والتسوية اليدوية
  late TextEditingController _manualDebtCtrl;
  late TextEditingController _manualCreditCtrl;
  late TextEditingController _manualProfitCtrl;
  late TextEditingController _manualNotesCtrl;
  bool _isManualEnabled = false;

  @override
  void initState() {
    super.initState();
    _customer = widget.initialCustomer;
    _tabController = TabController(length: 3, vsync: this);

    final override = CustomerFinancialHelper.parseOverride(_customer.notes);
    _isManualEnabled = override.isManualEnabled;
    _manualDebtCtrl = TextEditingController(
      text: override.manualDebt > 0
          ? override.manualDebt.toStringAsFixed(0)
          : '',
    );
    _manualCreditCtrl = TextEditingController(
      text: override.manualCredit > 0
          ? override.manualCredit.toStringAsFixed(0)
          : '',
    );
    _manualProfitCtrl = TextEditingController(
      text: override.manualProfit > 0
          ? override.manualProfit.toStringAsFixed(0)
          : '',
    );
    _manualNotesCtrl = TextEditingController(text: override.manualNotes ?? '');

    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _manualDebtCtrl.dispose();
    _manualCreditCtrl.dispose();
    _manualProfitCtrl.dispose();
    _manualNotesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final orders = await _orderRepo.getOrdersByCustomerId(_customer.id);
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  CustomerFinancialSummary get _financialSummary {
    return CustomerFinancialHelper.calculate(
      customer: _customer,
      orders: _orders,
      currencyService: _currencyService,
      filter: _calcFilter,
    );
  }

  // --- تعديل بيانات العميل ---
  void _editCustomer() {
    AddEditCustomerSheet.show(
      context,
      customerToEdit: _customer,
      onSave: (updated) async {
        context.read<CustomersBloc>().add(UpdateCustomerEvent(updated));
        setState(() {
          _customer = updated;
        });
        AppToast.showSuccess(
          context,
          'customer_updated_success'.i18n(),
          title: 'customer_edit_title'.i18n(),
        );
      },
    );
  }

  // --- إرسال حالة طلب فردي عبر واتساب ---
  void _sendSingleOrderWhatsApp(IndividualOrder order) {
    final message = CustomerWhatsAppHelper.buildSingleOrderStatusMessage(
      customer: _customer,
      order: order,
    );
    CustomerWhatsAppHelper.launchChat(
      context: context,
      customer: _customer,
      message: message,
    );
  }

  // --- إرسال تقرير الطلبات المحددة عبر واتساب ---
  void _sendSelectedOrdersWhatsApp() {
    if (_selectedOrderIds.isEmpty) return;
    final selectedOrders = _orders
        .where((o) => _selectedOrderIds.contains(o.id))
        .toList();
    final message = CustomerWhatsAppHelper.buildMultipleOrdersStatusMessage(
      customer: _customer,
      selectedOrders: selectedOrders,
    );
    CustomerWhatsAppHelper.launchChat(
      context: context,
      customer: _customer,
      message: message,
    );
  }

  // --- تسديد دفعة من مديونية طلب معين ---
  void _payPartialDebt(IndividualOrder order) {
    SettlePartialDebtSheet.show(
      context,
      order: order,
      onConfirmPayment: (amountPaid, newStatus) async {
        final newTotalPaid = order.paidAmount + amountPaid;
        await _orderRepo.updatePaymentStatus(order.id, newStatus, newTotalPaid);
        await _loadData();
        if (mounted) {
          AppToast.showSuccess(
            context,
            'customer_order_payment_msg'.trParams({
              'amount': amountPaid.toString(),
              'number': order.orderNumber,
            }),
            title: 'customer_payment_success'.i18n(),
          );
        }
      },
    );
  }

  // --- حفظ التسوية اليدوية ---
  Future<void> _saveManualAdjustment() async {
    final manualDebt = double.tryParse(_manualDebtCtrl.text.trim()) ?? 0.0;
    final manualCredit = double.tryParse(_manualCreditCtrl.text.trim()) ?? 0.0;
    final manualProfit = double.tryParse(_manualProfitCtrl.text.trim()) ?? 0.0;
    final manualNotes = _manualNotesCtrl.text.trim();

    final override = CustomerFinancialOverride(
      manualDebt: manualDebt,
      manualCredit: manualCredit,
      manualProfit: manualProfit,
      isManualEnabled: _isManualEnabled,
      manualNotes: manualNotes.isNotEmpty ? manualNotes : null,
    );

    final cleanNotes = CustomerFinancialHelper.cleanUserNotes(_customer.notes);
    final encodedNotes = CustomerFinancialHelper.encodeNotesWithOverride(
      cleanNotes,
      override,
    );

    final updatedCustomer = Customer(
      id: _customer.id,
      name: _customer.name,
      phone: _customer.phone,
      whatsapp: _customer.whatsapp,
      notes: encodedNotes.isNotEmpty ? encodedNotes : null,
      createdAt: _customer.createdAt,
    );

    context.read<CustomersBloc>().add(UpdateCustomerEvent(updatedCustomer));
    setState(() {
      _customer = updatedCustomer;
    });

    AppToast.showSuccess(
      context,
      'customer_manual_saved_success'.i18n(),
      title: 'customer_save_manual_adj'.i18n(),
    );
  }

  // --- إعادة ضبط التسوية اليدوية للتلقائي 100% ---
  Future<void> _resetManualAdjustment() async {
    final override = const CustomerFinancialOverride(isManualEnabled: false);
    final cleanNotes = CustomerFinancialHelper.cleanUserNotes(_customer.notes);
    final encodedNotes = cleanNotes.isNotEmpty
        ? CustomerFinancialHelper.encodeNotesWithOverride(cleanNotes, override)
        : null;

    final updatedCustomer = Customer(
      id: _customer.id,
      name: _customer.name,
      phone: _customer.phone,
      whatsapp: _customer.whatsapp,
      notes: encodedNotes,
      createdAt: _customer.createdAt,
    );

    _manualDebtCtrl.clear();
    _manualCreditCtrl.clear();
    _manualProfitCtrl.clear();
    _manualNotesCtrl.clear();
    _isManualEnabled = false;

    context.read<CustomersBloc>().add(UpdateCustomerEvent(updatedCustomer));
    setState(() {
      _customer = updatedCustomer;
    });

    AppToast.showInfo(
      context,
      'customer_manual_reset_success'.i18n(),
      title: 'customer_reset_manual_adj'.i18n(),
    );
  }

  // --- إنشاء طلب جديد لهذا العميل ---
  Future<void> _createNewOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditOrderScreen(
          initialCustomerId: _customer.id,
          initialCustomerName: _customer.name,
        ),
      ),
    );
    if (result == true || mounted) {
      _loadData();
    }
  }

  // --- فتح واتساب المباشر ---
  Future<void> _launchWhatsApp() async {
    await CustomerWhatsAppHelper.launchChat(
      context: context,
      customer: _customer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = _financialSummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(_customer.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'print_customer_invoices_tooltip'.i18n(),
            onPressed: () {
              PrintOptionsSheet.show(
                context,
                allOrders: _orders,
                customerName: _customer.name,
                customerPhone: _customer.phone,
                title: 'print_customer_invoices_title'.trParams({
                  'name': _customer.name,
                }),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'customer_edit_title'.i18n(),
            onPressed: _editCustomer,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'common_refresh'.i18n(),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? AppShimmer.list(itemCount: 4)
          : Column(
              children: [
                // ترويسة العميل والبطاقات المالية الثلاث
                _buildHeader(isDark, summary),

                // شريط التابات الثلاث
                _buildTabBar(isDark),

                // محتوى التابات
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrdersTab(isDark),
                      _buildDebtsTab(isDark),
                      _buildFinanceTab(isDark, summary),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _tabController.index == 0 && _isSelectionMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'customer_new_order_fab',
              backgroundColor: AppColors.primaryBlue,
              icon: const Icon(
                Icons.add_shopping_cart_rounded,
                color: Colors.white,
              ),
              label: Text(
                'customer_add_order_for_client'.i18n(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: _createNewOrder,
            ),
    );
  }

  // ==========================================
  // ترويسة العميل وبطاقات الحالة المالية الفعلية
  // ==========================================
  Widget _buildHeader(bool isDark, CustomerFinancialSummary summary) {
    final cleanNotes = CustomerFinancialHelper.cleanUserNotes(_customer.notes);
    final hasPhone = _customer.phone != null && _customer.phone!.isNotEmpty;
    final hasWhatsApp =
        _customer.whatsapp != null && _customer.whatsapp!.isNotEmpty;
    final phoneOp = hasPhone
        ? YemenPhoneHelper.getOperator(_customer.phone)
        : YemenTelecomOperator.unknown;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceCard : AppColors.surfaceWhite,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        children: [
          // سطر معلومات العميل وأزرار الاتصال
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryBlue.withValues(alpha: 0.2),
                      AppColors.primaryGreen.withValues(alpha: 0.2),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _customer.name.isNotEmpty ? _customer.name[0] : 'ع',
                  style: const TextStyle(
                    fontSize: 20,
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
                    Text(
                      _customer.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    if (hasPhone) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            YemenPhoneHelper.formatForDisplay(
                                  _customer.phone!,
                                  context: context,
                                ) ??
                                _customer.phone!,
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                            ),
                          ),
                          if (phoneOp != YemenTelecomOperator.unknown) ...[
                            const SizedBox(width: 6),
                            AppBadge(
                              label: YemenPhoneHelper.getOperatorLabel(phoneOp),
                              color: AppColors.primaryBlue,
                              fontSize: 10,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    if (hasWhatsApp &&
                        _customer.whatsapp != _customer.phone) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const WhatsAppIcon(size: 13),
                          const SizedBox(width: 4),
                          Text(
                            YemenPhoneHelper.formatForDisplay(
                                  _customer.whatsapp!,
                                  context: context,
                                ) ??
                                _customer.whatsapp!,
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (cleanNotes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        cleanNotes,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasWhatsApp || hasPhone) ...[
                AppIconButton(
                  customIcon: const WhatsAppIcon(size: 20),
                  color: AppColors.primaryGreen,
                  size: 36,
                  tooltip: 'customer_whatsapp_btn'.i18n(),
                  onPressed: _launchWhatsApp,
                ),
                const SizedBox(width: 6),
              ],
              if (hasPhone) ...[
                AppIconButton(
                  icon: Icons.phone_outlined,
                  color: AppColors.primaryBlue,
                  size: 36,
                  iconSize: 18,
                  tooltip: 'customer_call_btn'.i18n(),
                  onPressed: () => YemenPhoneHelper.launchPhoneCall(
                    context,
                    _customer.phone,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 12),

          // -------------------------------------------------------------------
          // الحالة المالية الحالية الفعلية:
          // أخضر: المبالغ المستفادة منه وتختفي إذا كان صفر
          // أحمر: مديونياته لنا وتختفي إذا كان صفر
          // أزرق: المبالغ المتبقية له لدينا وتختفي إذا كان صفر
          // -------------------------------------------------------------------
          _buildActualFinancialStatusCards(summary, isDark),
        ],
      ),
    );
  }

  /// البطاقات الملونة الثلاث للحالة المالية الفعلية (الأخضر، الأحمر، الأزرق)
  Widget _buildActualFinancialStatusCards(
    CustomerFinancialSummary summary,
    bool isDark,
  ) {
    final List<Widget> cards = [];

    // أخضر: المبالغ المستفادة منه وتختفي تماماً إذا كان صفر
    if (summary.showBenefited) {
      cards.add(
        _buildFinancialTile(
          title: 'customer_benefit_amount'.i18n(),
          amount: summary.benefitedAmount,
          currency: summary.activeCurrency,
          icon: Icons.trending_up_rounded,
          color: AppColors.primaryGreen,
          isDark: isDark,
        ),
      );
    }

    // أحمر: المبالغ مديونياته لنا وتختفي تماماً إذا كان صفر
    if (summary.showDebt) {
      cards.add(
        _buildFinancialTile(
          title: 'customer_debts_owed'.i18n(),
          amount: summary.debtsOwed,
          currency: summary.activeCurrency,
          icon: Icons.receipt_long_rounded,
          color: AppColors.statusDanger,
          isDark: isDark,
        ),
      );
    }

    // أزرق: المبالغ المتبقية له لدينا وتختفي تماماً إذا كان صفر
    if (summary.showCredit) {
      cards.add(
        _buildFinancialTile(
          title: 'customer_credit_balance'.i18n(),
          amount: summary.creditBalance,
          currency: summary.activeCurrency,
          icon: Icons.account_balance_wallet_rounded,
          color: AppColors.primaryBlue,
          isDark: isDark,
        ),
      );
    }

    if (cards.isEmpty) {
      // إذا كانت جميع القيم صفر تظهر شارة التوازن اللطيفة
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 16,
              color: AppColors.primaryGreen,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'customer_balanced_account'.i18n(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i < cards.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _buildFinancialTile({
    required String title,
    required double amount,
    required String currency,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          CurrencyPriceDisplay(
            amount: amount,
            currency: currency,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // شريط التابات بأسلوب آبل
  // ==========================================
  Widget _buildTabBar(bool isDark) {
    final debtsCount = _orders.where((o) => o.remainingDebt > 0.001).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceMuted : AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          width: 0.8,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.primaryBlue,
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: context.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        onTap: (_) => setState(() {}),
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 16),
                const SizedBox(width: 4),
                Text('customer_tab_orders'.i18n()),
                const SizedBox(width: 4),
                Text(
                  '(${_orders.length})',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_outlined, size: 16),
                const SizedBox(width: 4),
                Text('customer_tab_debts'.i18n()),
                if (debtsCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusDanger,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$debtsCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_graph_rounded, size: 16),
                const SizedBox(width: 4),
                Text('customer_tab_finance'.i18n()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // تاب الطلبات (Orders Tab) مع تحديد مجموعات
  // ==========================================
  Widget _buildOrdersTab(bool isDark) {
    final filtered = _orders.where((o) {
      if (_ordersStatusFilter == 'pending') {
        return o.orderStatus != AppConstants.orderStatusDelivered;
      }
      if (_ordersStatusFilter == 'delivered') {
        return o.orderStatus == AppConstants.orderStatusDelivered;
      }
      return true;
    }).toList();

    final pendingCount = _orders
        .where((o) => o.orderStatus != AppConstants.orderStatusDelivered)
        .length;
    final deliveredCount = _orders
        .where((o) => o.orderStatus == AppConstants.orderStatusDelivered)
        .length;

    return Column(
      children: [
        // شريط التصفية وأيقونة وضع التحديد
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppFilterChip(
                        label: 'customer_filter_all_orders'.i18n(),
                        isSelected: _ordersStatusFilter == 'all',
                        count: _orders.length,
                        icon: Icons.list_alt_rounded,
                        color: AppColors.primaryBlue,
                        showColoredUnselected: true,
                        onSelected: (_) =>
                            setState(() => _ordersStatusFilter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      AppFilterChip(
                        label: 'customer_filter_pending_orders'.i18n(),
                        isSelected: _ordersStatusFilter == 'pending',
                        count: pendingCount,
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.statusWarning,
                        showColoredUnselected: true,
                        onSelected: (_) =>
                            setState(() => _ordersStatusFilter = 'pending'),
                      ),
                      const SizedBox(width: 8),
                      AppFilterChip(
                        label: 'customer_filter_completed_orders'.i18n(),
                        isSelected: _ordersStatusFilter == 'delivered',
                        count: deliveredCount,
                        icon: Icons.check_circle_outline_rounded,
                        color: AppColors.primaryGreen,
                        showColoredUnselected: true,
                        onSelected: (_) =>
                            setState(() => _ordersStatusFilter = 'delivered'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AppIconButton(
                icon: _isSelectionMode
                    ? Icons.close_rounded
                    : Icons.checklist_rounded,
                color: _isSelectionMode
                    ? AppColors.statusDanger
                    : AppColors.primaryBlue,
                size: 34,
                iconSize: 18,
                tooltip: _isSelectionMode
                    ? 'customer_cancel_selection'.i18n()
                    : 'customer_select_orders_mode'.i18n(),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = !_isSelectionMode;
                    if (!_isSelectionMode) _selectedOrderIds.clear();
                  });
                },
              ),
            ],
          ),
        ),

        // شريط التحديد المتعدد
        if (_isSelectionMode)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.primaryBlue.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'customer_selected_orders_count'.trParams({
                    'count': _selectedOrderIds.length.toString(),
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
                AppSecondaryButton(
                  label: _selectedOrderIds.length == filtered.length
                      ? 'customer_deselect_all'.i18n()
                      : 'customer_select_all'.i18n(),
                  height: 30,
                  borderRadius: 8,
                  onPressed: () {
                    setState(() {
                      if (_selectedOrderIds.length == filtered.length) {
                        _selectedOrderIds.clear();
                      } else {
                        _selectedOrderIds.addAll(filtered.map((o) => o.id));
                      }
                    });
                  },
                ),
              ],
            ),
          ),

        // قائمة الطلبات
        Expanded(
          child: filtered.isEmpty
              ? EmptyStateView.section(
                  icon: Icons.inventory_2_outlined,
                  title: 'customer_no_orders_recorded'.i18n(),
                  subtitle: 'common_empty'.i18n(),
                )
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    6,
                    16,
                    _isSelectionMode && _selectedOrderIds.isNotEmpty ? 130 : 80,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final o = filtered[idx];
                    final isSelected = _selectedOrderIds.contains(o.id);

                    return AppAnimatedCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      onTap: () async {
                        if (_isSelectionMode) {
                          setState(() {
                            if (isSelected) {
                              _selectedOrderIds.remove(o.id);
                            } else {
                              _selectedOrderIds.add(o.id);
                            }
                          });
                        } else {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OrderDetailsScreen(orderId: o.id),
                            ),
                          );
                          _loadData();
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  if (_isSelectionMode) ...[
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? AppColors.primaryGreen
                                          : context.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    '#${o.orderNumber}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  AppBadge(
                                    label: AppConstants.getOrderStatusLabel(
                                      o.orderStatus,
                                    ),
                                    color:
                                        o.orderStatus ==
                                            AppConstants.orderStatusDelivered
                                        ? AppColors.primaryGreen
                                        : AppColors.primaryBlue,
                                  ),
                                  const SizedBox(width: 6),
                                  AppBadge(
                                    label: AppConstants.getPaymentStatusLabel(
                                      o.paymentStatus,
                                    ),
                                    color:
                                        o.paymentStatus ==
                                            AppConstants.paymentPrepaid
                                        ? AppColors.primaryGreen
                                        : (o.remainingDebt > 0
                                              ? AppColors.statusDanger
                                              : AppColors.statusWarning),
                                  ),
                                  if (!_isSelectionMode) ...[
                                    const SizedBox(width: 6),
                                    AppIconButton(
                                      customIcon: const WhatsAppIcon(size: 16),
                                      color: AppColors.primaryGreen,
                                      size: 30,
                                      tooltip:
                                          'customer_send_order_status_whatsapp'
                                              .i18n(),
                                      onPressed: () =>
                                          _sendSingleOrderWhatsApp(o),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${'items_count'.trParams({'count': o.items.length.toString()})} • ${o.createdAt.year}/${o.createdAt.month}/${o.createdAt.day}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textSecondary,
                                ),
                              ),
                              CurrencyPriceDisplay(
                                amount: o.totalSellPrice,
                                currency: o.currency,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          if (o.remainingDebt > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusDanger.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'customer_remaining_debt_on_order'.i18n(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.statusDanger,
                                    ),
                                  ),
                                  CurrencyPriceDisplay(
                                    amount: o.remainingDebt,
                                    currency: o.currency,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.statusDanger,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
        ),

        // شريط الواتساب العائم لإرسال التقرير للمجموعة المحددة
        if (_isSelectionMode && _selectedOrderIds.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceCard : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : AppColors.borderSubtle,
                  width: 0.8,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: AppPrimaryButton(
                      backgroundColor: AppColors.primaryGreen,
                      customIcon: const WhatsAppIcon(
                        size: 18,
                        color: Colors.white,
                      ),
                      label: 'customer_send_selected_orders_whatsapp'.trParams({
                        'count': _selectedOrderIds.length.toString(),
                      }),
                      onPressed: _sendSelectedOrdersWhatsApp,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: AppSecondaryButton(
                      icon: Icons.print,
                      label: 'print_selected_btn'.trParams({
                        'count': _selectedOrderIds.length.toString(),
                      }),
                      onPressed: () {
                        PrintOptionsSheet.show(
                          context,
                          allOrders: _orders,
                          initialSelectedOrderIds: _selectedOrderIds,
                          customerName: _customer.name,
                          customerPhone: _customer.phone,
                          title: 'print_customer_selected_invoices_title'
                              .trParams({'name': _customer.name}),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ==========================================
  // تاب المديونيات كل على حدة وسداد جزء (Debts Tab)
  // ==========================================
  Widget _buildDebtsTab(bool isDark) {
    final debtOrders = _orders.where((o) => o.remainingDebt > 0.001).toList();

    if (debtOrders.isEmpty) {
      return EmptyStateView.section(
        icon: Icons.verified_outlined,
        title: 'customer_no_debts'.i18n(),
        subtitle: 'customer_no_debts_subtitle'.i18n(),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: debtOrders.length,
      itemBuilder: (ctx, idx) {
        final order = debtOrders[idx];
        return AppCard(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // رقم الطلب والحالة وأيقونة الواتساب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.statusDanger.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          color: AppColors.statusDanger,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'طلب #${order.orderNumber}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      AppBadge(
                        label: AppConstants.getPaymentStatusLabel(
                          order.paymentStatus,
                        ),
                        color: AppColors.statusDanger,
                      ),
                      const SizedBox(width: 6),
                      AppIconButton(
                        customIcon: const WhatsAppIcon(size: 16),
                        color: AppColors.primaryGreen,
                        size: 28,
                        tooltip: 'customer_send_order_status_whatsapp'.i18n(),
                        onPressed: () => _sendSingleOrderWhatsApp(order),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // التفاصيل المالية للطلب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${'order_total_sell_price'.i18n()}:',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  CurrencyPriceDisplay(
                    amount: order.totalSellPrice,
                    currency: order.currency,
                    style: TextStyle(fontSize: 13, color: context.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'customer_current_paid'.i18n(),
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                  CurrencyPriceDisplay(
                    amount: order.paidAmount,
                    currency: order.currency,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              const Divider(height: 16),

              // المتبقي وزر تسديد دفعة
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'customer_remaining_debt_on_order'.i18n(),
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                        CurrencyPriceDisplay(
                          amount: order.remainingDebt,
                          currency: order.currency,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // زر تسديد دفعة أو جزء من المبلغ
                  AppSecondaryButton(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    label: 'customer_pay_part_debt'.i18n(),
                    icon: Icons.payments_outlined,
                    color: AppColors.statusDanger,
                    height: 38,
                    onPressed: () => _payPartialDebt(order),
                  ),
                ],
              ),

              if (order.debtDueDate != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      order.hasDebtReminder
                          ? Icons.alarm_on_rounded
                          : Icons.calendar_today_rounded,
                      size: 13,
                      color: AppColors.statusWarning,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'customer_due_date_prefix'.trParams({
                        'date': '${order.debtDueDate!.year}/${order.debtDueDate!.month}/${order.debtDueDate!.day}',
                      }),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.statusWarning,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // تاب المركز المالي والاحتساب التلقائي واليدوي
  // ==========================================
  Widget _buildFinanceTab(bool isDark, CustomerFinancialSummary summary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // -------------------------------------------------------------
          // قسم الاحتساب التلقائي الذكي من الطلبات السابقة والمعلقة
          // -------------------------------------------------------------
          Text(
            'customer_calc_mode_auto'.i18n(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'customer_calc_scope_hint'.i18n(),
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 10),

          // خيارات نطاق الاحتساب بشكل أفقي متمركز ومرن بدون أي قص أو overflow
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                AppFilterChip(
                  label: 'customer_filter_all_orders'.i18n(),
                  isSelected: _calcFilter == CustomerOrderFilter.all,
                  count: _orders.length,
                  icon: Icons.all_inclusive_rounded,
                  color: AppColors.primaryBlue,
                  showColoredUnselected: true,
                  onSelected: (_) =>
                      setState(() => _calcFilter = CustomerOrderFilter.all),
                ),
                const SizedBox(width: 8),
                AppFilterChip(
                  label: 'customer_filter_completed_orders'.i18n(),
                  isSelected: _calcFilter == CustomerOrderFilter.completedOnly,
                  count: _orders
                      .where(
                        (o) =>
                            o.orderStatus == AppConstants.orderStatusDelivered,
                      )
                      .length,
                  icon: Icons.task_alt_rounded,
                  color: AppColors.primaryGreen,
                  showColoredUnselected: true,
                  onSelected: (_) => setState(
                    () => _calcFilter = CustomerOrderFilter.completedOnly,
                  ),
                ),
                const SizedBox(width: 8),
                AppFilterChip(
                  label: 'customer_filter_pending_orders'.i18n(),
                  isSelected: _calcFilter == CustomerOrderFilter.pendingOnly,
                  count: _orders
                      .where(
                        (o) =>
                            o.orderStatus != AppConstants.orderStatusDelivered,
                      )
                      .length,
                  icon: Icons.hourglass_bottom_rounded,
                  color: AppColors.statusWarning,
                  showColoredUnselected: true,
                  onSelected: (_) => setState(
                    () => _calcFilter = CustomerOrderFilter.pendingOnly,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // بطاقة تفاصيل الاحتساب التلقائي
          AppCard(
            child: Column(
              children: [
                _buildSummaryRow(
                  label: 'customer_total_sales_volume'.i18n(),
                  amount: summary.totalSales,
                  currency: summary.activeCurrency,
                  icon: Icons.point_of_sale_rounded,
                  color: AppColors.primaryBlue,
                ),
                const Divider(height: 14),
                _buildSummaryRow(
                  label: 'customer_total_cost_volume'.i18n(),
                  amount: summary.totalCost,
                  currency: summary.activeCurrency,
                  icon: Icons.inventory_2_outlined,
                  color: context.textSecondary,
                ),
                const Divider(height: 14),
                _buildSummaryRow(
                  label: 'customer_total_paid_volume'.i18n(),
                  amount: summary.totalPaid,
                  currency: summary.activeCurrency,
                  icon: Icons.task_alt_rounded,
                  color: AppColors.primaryGreen,
                ),
                const Divider(height: 14),
                _buildSummaryRow(
                  label: '${'customer_benefit_amount'.i18n()}:',
                  amount: summary.benefitedAmount,
                  currency: summary.activeCurrency,
                  icon: Icons.trending_up_rounded,
                  color: AppColors.primaryGreen,
                  isBold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // -------------------------------------------------------------
          // خانة الإدخال والتسوية اليدوية (Manual Override & Adjustment)
          // -------------------------------------------------------------
          AppSwitchTile(
            title: 'customer_manual_section_title'.i18n(),
            subtitle: 'customer_manual_section_desc'.i18n(),
            value: _isManualEnabled,
            activeColor: AppColors.primaryBlue,
            onChanged: (val) {
              setState(() => _isManualEnabled = val);
            },
          ),
          const SizedBox(height: 10),

          if (_isManualEnabled) ...[
            AppCard(
              backgroundColor: isDark
                  ? AppColors.darkSurfaceMuted
                  : AppColors.surfaceCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // مديونية يدوية
                  AppTextField(
                    controller: _manualDebtCtrl,
                    label: 'customer_manual_debt_label'.i18n(),
                    hint: '0.00',
                    prefixIcon: Icons.receipt_long_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: AppFormatters.positiveDecimal(
                      decimalRange: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // مبالغ متبقية له يدوية
                  AppTextField(
                    controller: _manualCreditCtrl,
                    label: 'customer_manual_credit_label'.i18n(),
                    hint: '0.00',
                    prefixIcon: Icons.account_balance_wallet_outlined,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: AppFormatters.positiveDecimal(
                      decimalRange: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // مبالغ مستفادة / أرباح يدوية إضافية
                  AppTextField(
                    controller: _manualProfitCtrl,
                    label: 'customer_manual_profit_label'.i18n(),
                    hint: '0.00',
                    prefixIcon: Icons.trending_up_rounded,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: AppFormatters.positiveDecimal(
                      decimalRange: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // بيان وملاحظات التسوية اليدوية
                  AppTextField(
                    controller: _manualNotesCtrl,
                    label: 'customer_manual_notes_label'.i18n(),
                    hint: 'customer_manual_notes_hint'.i18n(),
                    prefixIcon: Icons.notes_rounded,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),

                  // أزرار الحفظ والإلغاء
                  Row(
                    children: [
                      Expanded(
                        child: AppPrimaryButton(
                          label: 'customer_save_manual_adj'.i18n(),
                          icon: Icons.check_circle_outline_rounded,
                          onPressed: _saveManualAdjustment,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppSecondaryButton(
                          label: 'common_cancel'.i18n(),
                          height: 50,
                          onPressed: _resetManualAdjustment,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceMuted
                    : AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? AppColors.darkBorderSubtle
                      : AppColors.borderSubtle,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'customer_manual_disabled_hint'.i18n(),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryRow({
    required String label,
    required double amount,
    required String currency,
    required IconData icon,
    required Color color,
    bool isBold = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: context.textPrimary,
            ),
          ),
        ),
        CurrencyPriceDisplay(
          amount: amount,
          currency: currency,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
