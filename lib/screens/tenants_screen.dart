import 'package:flutter/material.dart';

import '../models/charge.dart';
import '../models/payment.dart';
import '../models/tenant.dart';
import '../services/charge_repository.dart';
import '../services/payment_repository.dart';
import '../services/rent_scheduler.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/status_badge.dart';
import 'home_screen.dart';
import 'tenant_form_screen.dart';

/// Home tab: who owes what, across every tenant.
class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  final _tenantRepository = TenantRepository();
  final _paymentRepository = PaymentRepository();
  final _chargeRepository = ChargeRepository();
  final _settingsService = SettingsService();
  final _rentScheduler = RentScheduler();

  bool _loading = true;
  List<Tenant> _tenants = [];
  List<Payment> _payments = [];
  List<Charge> _charges = [];
  String _currencySymbol = 'RM';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Bring rent records up to the current month before reading, so the
    // arrears figures below reflect rent that is owed but not yet logged.
    await _rentScheduler.reconcile();
    final tenants = await _tenantRepository.getAll();
    final payments = await _paymentRepository.getAll();
    final charges = await _chargeRepository.getAll();
    final settings = await _settingsService.load();
    tenants.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _payments = payments;
      _charges = charges;
      _currencySymbol = settings.currencySymbol;
      _loading = false;
    });
  }

  Payment? _currentMonthPaymentFor(String tenantId) {
    final currentMonthLabel = MonthUtils.currentMonthLabel();
    for (final payment in _payments) {
      if (payment.tenantId == tenantId && payment.month == currentMonthLabel) {
        return payment;
      }
    }
    return null;
  }

  /// Everything this tenant still owes, rent arrears plus unpaid charges.
  /// Individual balances are clamped at zero so an overpayment in one
  /// month can't mask arrears in another.
  double _outstandingFor(String tenantId) {
    var total = 0.0;
    for (final p in _payments) {
      if (p.tenantId == tenantId && p.balance > 0) total += p.balance;
    }
    for (final c in _charges) {
      if (c.tenantId == tenantId && c.balance > 0) total += c.balance;
    }
    return total;
  }

  int _overdueMonthsFor(String tenantId) {
    return _payments
        .where((p) =>
            p.tenantId == tenantId &&
            p.balance > 0 &&
            MonthUtils.isBeforeCurrentMonth(p.month))
        .length;
  }

  Future<void> _openAddTenant() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const TenantFormScreen()),
    );
    if (result == true) _load();
  }

  Future<void> _openEditTenant(Tenant tenant) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TenantFormScreen(tenant: tenant)),
    );
    if (result == true) _load();
  }

  Future<void> _openTenantHome(Tenant tenant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HomeScreen(tenant: tenant)),
    );
    _load();
  }

  Future<void> _confirmDeleteTenant(Tenant tenant) async {
    final payments = await _paymentRepository.getForTenant(tenant.id);
    final charges = await _chargeRepository.getForTenant(tenant.id);
    if (!mounted) return;

    final recordCount = payments.length + charges.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tenant?'),
        content: Text(
          recordCount == 0
              ? 'This will permanently delete ${tenant.name}.'
              : 'This will permanently delete ${tenant.name} and all '
                  '$recordCount of their payment/charge records.',
        ),
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

    if (confirmed == true) {
      await _paymentRepository.deleteForTenant(tenant.id);
      await _chargeRepository.deleteForTenant(tenant.id);
      await _tenantRepository.delete(tenant.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'RentTrack'),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddTenant,
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tenants.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    children: [
                      _arrearsSummary(),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                        child: Text(
                          MonthUtils.currentMonthLabel(),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ..._tenants.map(_tenantCard),
                    ],
                  ),
                ),
    );
  }

  /// A single "who owes me money" line at the top — the reason a landlord
  /// opens the app. Hidden entirely when everyone is settled up.
  Widget _arrearsSummary() {
    final owing =
        _tenants.where((t) => _outstandingFor(t.id) > 0).toList();
    if (owing.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.check_circle, color: AppColors.paid),
          title: const Text('All settled up',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('No outstanding balances',
              style: TextStyle(color: AppColors.subtleText(context))),
        ),
      );
    }

    final total = owing.fold<double>(0, (sum, t) => sum + _outstandingFor(t.id));
    return Card(
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined,
            color: AppColors.unpaid),
        title: Text(
          Currency.format(_currencySymbol, total),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Outstanding from ${owing.length} '
          '${owing.length == 1 ? 'tenant' : 'tenants'}',
          style: TextStyle(color: AppColors.subtleText(context)),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_outlined,
                size: 72, color: AppColors.navyLight),
            const SizedBox(height: 16),
            const Text(
              'No Tenants Yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a tenant to start tracking their rent payments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.subtleText(context)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _openAddTenant,
              child: const Text('Add Tenant'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tenantCard(Tenant tenant) {
    final currentPayment = _currentMonthPaymentFor(tenant.id);
    final status = currentPayment?.status ?? 'Unpaid';
    final outstanding = _outstandingFor(tenant.id);
    final overdueMonths = _overdueMonthsFor(tenant.id);

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openTenantHome(tenant),
        leading: CircleAvatar(
          backgroundColor: AppColors.navyLight,
          foregroundColor: Colors.white,
          child:
              Text(tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?'),
        ),
        title: Text(tenant.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        // One line, one message. When a tenant owes, the arrears are the
        // only thing worth saying; repeating this month's due/balance
        // alongside it just wrapped the card into an unreadable block.
        subtitle: outstanding > 0
            ? Text(
                'Owes ${Currency.format(_currencySymbol, outstanding)}'
                '${overdueMonths > 0 ? '  ·  $overdueMonths ${overdueMonths == 1 ? 'mo' : 'mos'} overdue' : ''}',
                style: const TextStyle(
                    color: AppColors.unpaid, fontWeight: FontWeight.w600),
              )
            : Text(
                currentPayment == null
                    ? 'This month not recorded'
                    : 'Paid ${Currency.format(_currencySymbol, currentPayment.amountPaid)}',
                style: TextStyle(color: AppColors.subtleText(context)),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(status: status),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditTenant(tenant);
                } else if (value == 'delete') {
                  _confirmDeleteTenant(tenant);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
