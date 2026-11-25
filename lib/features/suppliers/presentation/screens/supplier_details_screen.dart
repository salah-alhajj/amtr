import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/audit/audit.dart';
import '../../../../core/constants.dart';
import '../../../../core/di/app_services.dart';
import '../../../../core/localization/localization.dart';
import '../../../../core/services/currency_service.dart';
import '../../../../core/services/data_sync_bus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/yemen_phone_helper.dart';
import '../../../../core/widgets/design_system.dart';
import '../../../../models/expense.dart';
import '../../../../models/product.dart';
import '../../../../models/raw_material.dart';
import '../../../../models/supplier.dart';
import '../../../../models/supplier_transaction.dart';
import '../../../audit/presentation/screens/audit_log_screen.dart';
import '../../../whatsapp/domain/whatsapp_template_engine.dart';
import '../../data/repositories/supplier_ledger_repository.dart';
import '../../domain/services/supplier_business_service.dart';
import '../bloc/suppliers_bloc.dart';
import '../widgets/add_edit_supplier_sheet.dart';
import '../widgets/supplier_transaction_sheet.dart';

class SupplierDetailsScreen extends StatefulWidget {
  final Supplier supplier;

  const SupplierDetailsScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailsScreen> createState() => _SupplierDetailsScreenState();
}

class _SupplierDetailsScreenState extends State<SupplierDetailsScreen> {
  static const Color _creditWarmAmber = Color(0xFFD97706);

  final SupplierBusinessService _supplierService =
      AppServices.instance.supplierService;
  late Supplier _supplier;
  List<Product> _products = const [];
  List<RawMaterial> _materials = const [];
  List<Expense> _expenses = const [];
  SupplierBalanceSummary _balanceSummary = SupplierBalanceSummary.zero;
  List<SupplierTransaction> _transactions = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _supplier = widget.supplier;
    _loadLinkedData();
  }

  Future<void> _loadLinkedData() async {
    setState(() => _isLoading = true);
    try {
      final workspace =
          await _supplierService.loadSupplierWorkspace(_supplier.id);
      if (!mounted) return;
      setState(() {
        _products = workspace.products;
        _materials = workspace.materials;
        _expenses = workspace.expenses;
        _balanceSummary = workspace.balanceSummary;
        _transactions = workspace.transactions;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchWhatsApp() async {
    final raw = (_supplier.whatsapp ?? _supplier.phone ?? '').trim();
    if (raw.isEmpty) return;
    final clean = YemenPhoneHelper.cleanForWhatsApp(raw);
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchWhatsAppMessage(String message) async {
    final raw = (_supplier.whatsapp ?? _supplier.phone ?? '').trim();
    if (raw.isNotEmpty) {
      final clean = YemenPhoneHelper.cleanForWhatsApp(raw);
      if (clean.isNotEmpty) {
        final uri = Uri.parse(
          'https://wa.me/$clean?text=${Uri.encodeComponent(message)}',
        );
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        } catch (_) {}
      }
    }
    await SharePlus.instance.share(ShareParams(text: message));
  }

  Future<void> _sendPaymentReceiptWhatsApp(
    SupplierTransaction tx,
    double remainingBalanceYer,
  ) async {
    final message = WhatsAppTemplateEngine.buildSupplierPaymentReceiptMessage(
      supplierName: _supplier.name,
      paidAmount: tx.amount,
      currency: tx.currency,
      remainingBalanceYer: remainingBalanceYer,
    );
    await _launchWhatsAppMessage(message);
  }

  Future<void> _sendStatementWhatsApp() async {
    final message = WhatsAppTemplateEngine.buildSupplierStatementMessage(
      supplierName: _supplier.name,
      totalPurchasesYer: _balanceSummary.totalCreditPurchasesYer,
      totalPaymentsYer: _balanceSummary.totalPaymentsYer,
      balanceYer: _balanceSummary.payableBalanceYer,
    );
    await _launchWhatsAppMessage(message);
  }

  Future<void> _openTransactionSheet({required bool isPayment}) async {
    final result = await SupplierTransactionSheet.showWithStock(
      context,
      supplierId: _supplier.id,
      supplierName: _supplier.name,
      isPayment: isPayment,
    );
    if (result == null || !mounted) return;

    final tx = result.transaction;
    await _supplierService.recordTransaction(
      tx,
      supplierName: _supplier.name,
      stockItemType: result.stockItemType,
      stockItemId: result.stockItemId,
      stockQuantity: result.stockQuantity,
    );
    await _loadLinkedData();
    if (!mounted) return;

    try {
      context.read<SuppliersBloc>().add(const LoadSuppliers());
    } catch (_) {}

    if (tx.isPayment) {
      final remainingYer = _balanceSummary.payableBalanceYer;
      AppToast.showSuccess(
        context,
        'supplier_payment_saved_success'.i18n(),
        duration: const Duration(seconds: 6),
        actionLabel: 'supplier_send_receipt_whatsapp'.i18n(),
        onAction: () => _sendPaymentReceiptWhatsApp(tx, remainingYer),
      );
    } else if (result.hasStockLink) {
      AppToast.showSuccess(context, 'supplier_stock_saved_toast'.i18n());
    } else {
      AppToast.showSuccess(context, 'supplier_tx_saved_success'.i18n());
    }
  }

  Future<void> _deleteTransaction(SupplierTransaction tx) async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'supplier_tx_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (confirm != true || !mounted) return;

    await _supplierService.deleteTransaction(tx.id);
    await _loadLinkedData();
    if (!mounted) return;

    try {
      context.read<SuppliersBloc>().add(const LoadSuppliers());
    } catch (_) {}
    AppToast.showSuccess(context, 'supplier_tx_deleted_success'.i18n());
  }

  void _previewReceipt(String photoPath) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AppPhotoLightboxDialog(
        photos: [photoPath],
        initialIndex: 0,
      ),
    );
  }

  void _editSupplier() {
    AddEditSupplierSheet.show(
      context,
      supplierToEdit: _supplier,
      onSave: (updated) async {
        await _supplierService.updateSupplier(updated);
        if (!mounted) return;
        setState(() => _supplier = updated);
        try {
          context.read<SuppliersBloc>().add(const LoadSuppliers());
        } catch (_) {}
        DataSyncBus.instance.notify(DataDomain.suppliers);
        AppToast.showSuccess(context, 'supplier_updated_success'.i18n());
      },
    );
  }

  Future<void> _deleteSupplier() async {
    final confirm = await showAppConfirmationDialog(
      context: context,
      title: 'common_delete'.i18n(),
      message: 'supplier_delete_confirm'.i18n(),
      isDestructive: true,
    );
    if (confirm != true || !mounted) return;
    await _supplierService.deleteSupplier(_supplier.id);
    if (!mounted) return;
    try {
      context.read<SuppliersBloc>().add(const LoadSuppliers());
    } catch (_) {}
    DataSyncBus.instance.notify(DataDomain.suppliers);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleBloc>();
    final cs = CurrencyService.instance;
    final activeCurrency = cs.activeDisplayCurrency;
    final hasPhone = _supplier.phone != null && _supplier.phone!.isNotEmpty;
    final hasWa = (_supplier.whatsapp != null && _supplier.whatsapp!.isNotEmpty) || hasPhone;

    return Scaffold(
      appBar: AppBar(
        title: Text(_supplier.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'audit_center_title'.i18n(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AuditLogScreen(
                    entityType: AuditEntityType.supplier,
                    entityId: _supplier.id,
                    entityTitle: _supplier.name,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const WhatsAppIcon(size: 20),
            onPressed: _sendStatementWhatsApp,
            tooltip: 'supplier_whatsapp_statement_btn'.i18n(),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editSupplier,
            tooltip: 'common_edit'.i18n(),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.statusDanger,
            ),
            onPressed: _deleteSupplier,
            tooltip: 'common_delete'.i18n(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLinkedData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppColors.primaryBlue.withValues(alpha: 0.14),
                        child: Text(
                          _supplier.name.isNotEmpty
                              ? _supplier.name[0].toUpperCase()
                              : 'S',
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
                              _supplier.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppBadge(
                              label: _supplier.category.i18n(),
                              color: AppColors.primaryBlue,
                            ),
                          ],
                        ),
                      ),
                      if (hasWa)
                        AppIconButton(
                          customIcon: const WhatsAppIcon(size: 20),
                          color: AppColors.primaryGreen,
                          size: 36,
                          tooltip: 'customer_whatsapp_btn'.i18n(),
                          onPressed: _launchWhatsApp,
                        ),
                      if (hasPhone) ...[
                        const SizedBox(width: 6),
                        AppIconButton(
                          icon: Icons.phone_outlined,
                          color: AppColors.primaryBlue,
                          size: 36,
                          iconSize: 18,
                          tooltip: 'customer_call_btn'.i18n(),
                          onPressed: () => YemenPhoneHelper.launchPhoneCall(
                            context,
                            _supplier.phone,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (hasPhone) ...[
                    const SizedBox(height: 10),
                    Text(
                      _supplier.phone!,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  if (_supplier.address != null &&
                      _supplier.address!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: context.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _supplier.address!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_supplier.notes != null && _supplier.notes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _supplier.notes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildBalanceCard(context, cs, activeCurrency),
            const SizedBox(height: 10),
            _buildLedgerActionButtons(),
            const SizedBox(height: 16),
            if (_isLoading)
              AppShimmer.list(itemCount: 3)
            else ...[
              _buildSectionHeader(
                'supplier_ledger_history_title'.i18n(),
                _transactions.length,
                Icons.receipt_long_rounded,
                _creditWarmAmber,
              ),
              const SizedBox(height: 8),
              if (_transactions.isEmpty)
                _buildEmptyHint('supplier_ledger_empty'.i18n())
              else
                ..._transactions.map(
                  (tx) => _buildLedgerTransactionTile(context, tx, cs),
                ),
              const SizedBox(height: 16),
              _buildSectionHeader(
                'supplier_linked_products'.i18n(),
                _products.length,
                Icons.inventory_2_outlined,
                AppColors.primaryBlue,
              ),
              const SizedBox(height: 8),
              if (_products.isEmpty)
                _buildEmptyHint('supplier_no_linked_products'.i18n())
              else
                ..._products.map(
                  (p) => AppCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          cs.formatAmount(p.sellPrice, currencyCode: p.currency),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildSectionHeader(
                'supplier_linked_materials'.i18n(),
                _materials.length,
                Icons.science_outlined,
                AppColors.vibrantTeal,
              ),
              const SizedBox(height: 8),
              if (_materials.isEmpty)
                _buildEmptyHint('supplier_no_linked_materials'.i18n())
              else
                ..._materials.map(
                  (m) => AppCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${m.name} (${m.unit})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          cs.formatAmount(m.unitCost, currencyCode: m.currency),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              _buildSectionHeader(
                'supplier_linked_expenses'.i18n(),
                _expenses.length,
                Icons.receipt_long_outlined,
                AppColors.statusDanger,
              ),
              const SizedBox(height: 8),
              if (_expenses.isEmpty)
                _buildEmptyHint('supplier_no_linked_expenses'.i18n())
              else
                ..._expenses.map(
                  (e) => AppCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                DateFormat('yyyy/MM/dd').format(e.expenseDate),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          cs.formatAmount(e.amount, currencyCode: e.currency),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.statusDanger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    CurrencyService cs,
    String activeCurrency,
  ) {
    final balanceYer = _balanceSummary.payableBalanceYer;
    final Color statusColor;
    final IconData statusIcon;
    final String headline;

    if (balanceYer > 0.009) {
      statusColor = _creditWarmAmber;
      statusIcon = Icons.account_balance_wallet_outlined;
      final formatted = cs.formatAmount(
        cs.fromBaseYer(balanceYer, activeCurrency),
        currencyCode: activeCurrency,
      );
      headline = 'supplier_balance_owed'.trParams({'amount': formatted});
    } else if (balanceYer < -0.009) {
      statusColor = AppColors.vibrantTeal;
      statusIcon = Icons.savings_outlined;
      final absFormatted = cs.formatAmount(
        cs.fromBaseYer(balanceYer.abs(), activeCurrency),
        currencyCode: activeCurrency,
      );
      headline = 'supplier_balance_advance'.trParams({'amount': absFormatted});
    } else {
      statusColor = AppColors.statusSuccess;
      statusIcon = Icons.check_circle_outline_rounded;
      headline = 'supplier_balance_settled'.i18n();
    }

    final creditFormatted = cs.formatAmount(
      cs.fromBaseYer(_balanceSummary.totalCreditPurchasesYer, activeCurrency),
      currencyCode: activeCurrency,
    );
    final paymentsFormatted = cs.formatAmount(
      cs.fromBaseYer(_balanceSummary.totalPaymentsYer, activeCurrency),
      currencyCode: activeCurrency,
    );

    return AppCard(
      padding: const EdgeInsets.all(14),
      backgroundColor: statusColor.withValues(
        alpha: context.isDarkMode ? 0.14 : 0.07,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(statusIcon, size: 20, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          if (_transactions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: statusColor.withValues(alpha: 0.22)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'supplier_summary_credit_purchases'.i18n(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          creditFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'supplier_summary_payments'.i18n(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          paymentsFormatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: InkWell(
              onTap: _sendStatementWhatsApp,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primaryGreen.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const WhatsAppIcon(size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'supplier_whatsapp_statement_btn'.i18n(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedgerActionButtons() {
    return Row(
      children: [
        Expanded(
          child: AppPrimaryButton(
            label: 'supplier_action_bought'.i18n(),
            icon: Icons.shopping_bag_outlined,
            backgroundColor: AppColors.primaryBlue,
            height: 46,
            onPressed: () => _openTransactionSheet(isPayment: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppPrimaryButton(
            label: 'supplier_action_paid'.i18n(),
            icon: Icons.payments_outlined,
            backgroundColor: AppColors.primaryGreen,
            height: 46,
            onPressed: () => _openTransactionSheet(isPayment: true),
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTransactionTile(
    BuildContext context,
    SupplierTransaction tx,
    CurrencyService cs,
  ) {
    final String typeLabel;
    final Color typeColor;
    final IconData typeIcon;

    if (tx.type == AppConstants.supplierTxPayment) {
      typeLabel = 'supplier_tx_type_payment'.i18n();
      typeColor = AppColors.statusSuccess;
      typeIcon = Icons.payments_outlined;
    } else if (tx.type == AppConstants.supplierTxPurchaseCash) {
      typeLabel = 'supplier_tx_type_cash'.i18n();
      typeColor = AppColors.primaryBlue;
      typeIcon = Icons.point_of_sale_outlined;
    } else {
      typeLabel = 'supplier_tx_type_credit'.i18n();
      typeColor = _creditWarmAmber;
      typeIcon = Icons.schedule_rounded;
    }

    final hasReceipt =
        tx.receiptPhotoPath != null && tx.receiptPhotoPath!.isNotEmpty;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, size: 17, color: typeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AppBadge(
                      label: typeLabel,
                      color: typeColor,
                      fontSize: 10,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                    ),
                    Text(
                      DateFormat('yyyy/MM/dd').format(tx.txDate),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                    if (hasReceipt)
                      InkWell(
                        onTap: () => _previewReceipt(tx.receiptPhotoPath!),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.receipt_outlined,
                                size: 11,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'expense_receipt_badge'.i18n(),
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                if (tx.notes != null && tx.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tx.notes!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cs.formatAmount(tx.amount, currencyCode: tx.currency),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (tx.isPayment)
                    InkWell(
                      onTap: () => _sendPaymentReceiptWhatsApp(
                        tx,
                        _balanceSummary.payableBalanceYer,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Tooltip(
                          message: 'supplier_send_receipt_whatsapp'.i18n(),
                          child: const WhatsAppIcon(size: 16),
                        ),
                      ),
                    ),
                  InkWell(
                    onTap: () => _deleteTransaction(tx),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Tooltip(
                        message: 'common_delete'.i18n(),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                          color: AppColors.statusDanger,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        AppBadge(label: '$count', color: color),
      ],
    );
  }

  Widget _buildEmptyHint(String text) {
    return AppCard(
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontSize: 12, color: context.textSecondary),
        ),
      ),
    );
  }
}
