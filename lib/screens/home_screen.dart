import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/charge.dart';
import '../models/payment.dart';
import '../models/rent_settings.dart';
import '../models/tenant.dart';
import '../services/charge_repository.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/status_badge.dart';
import 'charge_form_screen.dart';
import 'invoice_screen.dart';
import 'payment_form_screen.dart';

/// A single tenant's payment dashboard.
class HomeScreen extends StatefulWidget {
  final Tenant tenant;

  const HomeScreen({super.key, required this.tenant});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = PaymentRepository();
  final _chargeRepository = ChargeRepository();
  final _settingsService = SettingsService();

  bool _loading = true;
  RentSettings _settings = const RentSettings();
  List<Payment> _payments = [];
  List<Charge> _charges = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final settings = await _settingsService.load();
    final payments = await _repository.getForTenant(widget.tenant.id);
    final charges = await _chargeRepository.getForTenant(widget.tenant.id);
    payments.sort((a, b) {
      final dateA = MonthUtils.tryParse(a.month);
      final dateB = MonthUtils.tryParse(b.month);
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA); // newest first
    });
    charges.sort((a, b) => b.date.compareTo(a.date));

    if (!mounted) return;
    setState(() {
      _settings = settings;
      _payments = payments;
      _charges = charges;
      _loading = false;
    });
  }

  String _money(double amount) =>
      Currency.format(_settings.currencySymbol, amount);

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.home_outlined),
              title: const Text('Add Rent Payment'),
              onTap: () => Navigator.of(context).pop('payment'),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Add Charge (bill, deposit, etc.)'),
              onTap: () => Navigator.of(context).pop('charge'),
            ),
          ],
        ),
      ),
    );

    if (choice == 'payment') {
      _openAddPayment();
    } else if (choice == 'charge') {
      _openAddCharge();
    }
  }

  Future<void> _openAddPayment() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PaymentFormScreen(initialTenantId: widget.tenant.id),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openEditPayment(Payment payment) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentFormScreen(payment: payment)),
    );
    if (result == true) _load();
  }

  Future<void> _openAddCharge() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChargeFormScreen(tenantId: widget.tenant.id),
      ),
    );
    if (result == true) _load();
  }

  Future<void> _openEditCharge(Charge charge) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ChargeFormScreen(charge: charge)),
    );
    if (result == true) _load();
  }

  /// Settles a record in one tap — the overwhelmingly common action —
  /// instead of opening the form to retype the same number.
  Future<void> _markPaymentPaid(Payment payment) async {
    await _repository.update(payment.copyWith(
      amountPaid: payment.amountDue,
      paidDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${payment.month} marked as paid')),
    );
    _load();
  }

  void _openInvoice(Payment payment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(payment: payment, tenant: widget.tenant),
      ),
    );
  }

  Future<bool> _confirmDelete(String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this record?'),
        content: Text('This will permanently delete $label.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.unpaid)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deletePayment(Payment payment) async {
    await _repository.delete(payment.id);
    if (!mounted) return;
    setState(() => _payments.removeWhere((p) => p.id == payment.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${payment.month}')),
    );
  }

  Future<void> _deleteCharge(Charge charge) async {
    await _chargeRepository.delete(charge.id);
    if (!mounted) return;
    setState(() => _charges.removeWhere((c) => c.id == charge.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${charge.description}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(title: widget.tenant.name),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddMenu,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _dashboardAndList(),
            ),
    );
  }

  Widget _dashboardAndList() {
    final totalCollected =
        _payments.fold<double>(0, (sum, p) => sum + p.amountPaid);

    // Arrears across rent and charges, each clamped at zero so an
    // overpayment in one record can't mask a shortfall in another.
    var outstanding = 0.0;
    for (final p in _payments) {
      if (p.balance > 0) outstanding += p.balance;
    }
    for (final c in _charges) {
      if (c.balance > 0) outstanding += c.balance;
    }

    final paidCount = _payments.where((p) => p.status == 'Paid').length;
    final unpaidCount = _payments.where((p) => p.status != 'Paid').length;
    final overdueCount = _payments
        .where((p) =>
            p.status != 'Paid' && MonthUtils.isBeforeCurrentMonth(p.month))
        .length;

    var streak = 0;
    for (final payment in _payments) {
      if (payment.status == 'Paid') {
        streak++;
      } else {
        break;
      }
    }

    final currentMonthLabel = MonthUtils.currentMonthLabel();
    Payment? currentMonthPayment;
    for (final payment in _payments) {
      if (payment.month == currentMonthLabel) {
        currentMonthPayment = payment;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard('Collected', _money(totalCollected),
                    Icons.savings_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Outstanding',
                  _money(outstanding),
                  Icons.account_balance_wallet_outlined,
                  color: outstanding > 0 ? AppColors.unpaid : AppColors.paid,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                    'Streak', '$streak mo', Icons.local_fire_department),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                    'Paid', '$paidCount', Icons.check_circle_outline,
                    color: AppColors.paid),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('Unpaid', '$unpaidCount', Icons.error_outline,
                    color: AppColors.unpaid),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                    'Overdue', '$overdueCount', Icons.warning_amber,
                    color: AppColors.partial),
              ),
            ],
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(currentMonthLabel,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    StatusBadge(
                        status: currentMonthPayment?.status ?? 'Unpaid'),
                  ],
                ),
                const SizedBox(height: 8),
                if (currentMonthPayment == null)
                  Text('No payment recorded for this month yet.',
                      style: TextStyle(color: AppColors.subtleText(context)))
                else
                  Text(
                    'Due ${_money(currentMonthPayment.amountDue)}  ·  '
                    'Paid ${_money(currentMonthPayment.amountPaid)}  ·  '
                    'Balance ${_money(currentMonthPayment.balance)}',
                    style: TextStyle(color: AppColors.subtleText(context)),
                  ),
              ],
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text('Payment History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (_payments.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No payments yet. Tap + to add one.',
                  style: TextStyle(color: AppColors.subtleText(context))),
            ),
          )
        else
          ..._payments.map(_paymentListItem),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 16, 8),
          child: Text('Other Charges',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (_charges.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text('No extra charges recorded.',
                  style: TextStyle(color: AppColors.subtleText(context))),
            ),
          )
        else
          ..._charges.map(_chargeListItem),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? AppColors.navyLight, size: 22),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.subtleText(context))),
          ],
        ),
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.unpaid,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  Widget _paymentListItem(Payment payment) {
    final settled = payment.balance <= 0;

    return Dismissible(
      key: ValueKey(payment.id),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) => _confirmDelete(payment.month),
      onDismissed: (_) => _deletePayment(payment),
      child: Card(
        child: ListTile(
          onTap: () => _openInvoice(payment),
          title: Text(payment.month,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            'Due ${_money(payment.amountDue)}  ·  '
            'Paid ${_money(payment.amountPaid)}  ·  '
            'Bal ${_money(payment.balance)}',
          ),
          leading: StatusBadge(status: payment.status),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'paid') {
                _markPaymentPaid(payment);
              } else if (value == 'edit') {
                _openEditPayment(payment);
              } else if (value == 'invoice') {
                _openInvoice(payment);
              } else if (value == 'delete') {
                if (await _confirmDelete(payment.month)) {
                  _deletePayment(payment);
                }
              }
            },
            itemBuilder: (context) => [
              if (!settled)
                const PopupMenuItem(
                    value: 'paid', child: Text('Mark as paid')),
              const PopupMenuItem(value: 'edit', child: Text('Edit')),
              const PopupMenuItem(
                  value: 'invoice', child: Text('View Invoice')),
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chargeListItem(Charge charge) {
    return Dismissible(
      key: ValueKey(charge.id),
      direction: DismissDirection.endToStart,
      background: _deleteBackground(),
      confirmDismiss: (_) => _confirmDelete(charge.description),
      onDismissed: (_) => _deleteCharge(charge),
      child: Card(
        child: ListTile(
          onTap: () => _openEditCharge(charge),
          title: Text(charge.description,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
            '${charge.date}  ·  '
            'Amt ${_money(charge.amount)}  ·  '
            'Bal ${_money(charge.balance)}',
          ),
          leading: StatusBadge(status: charge.status),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                _openEditCharge(charge);
              } else if (value == 'delete') {
                if (await _confirmDelete(charge.description)) {
                  _deleteCharge(charge);
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ),
      ),
    );
  }
}
