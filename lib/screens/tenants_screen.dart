import 'package:flutter/material.dart';

import '../models/payment.dart';
import '../models/tenant.dart';
import '../services/charge_repository.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/status_badge.dart';
import 'home_screen.dart';
import 'tenant_form_screen.dart';

/// Home tab: overview of every tenant, showing whether this month's
/// payment is due/paid, plus the tenant list itself.
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

  bool _loading = true;
  List<Tenant> _tenants = [];
  List<Payment> _payments = [];
  String _currencySymbol = 'RM';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final tenants = await _tenantRepository.getAll();
    final payments = await _paymentRepository.getAll();
    final settings = await _settingsService.load();
    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _payments = payments;
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
            const Text(
              'Add a tenant to start tracking their rent payments.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
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

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openTenantHome(tenant),
        leading: CircleAvatar(
          backgroundColor: AppColors.navyLight,
          foregroundColor: Colors.white,
          child: Text(tenant.name.isNotEmpty ? tenant.name[0].toUpperCase() : '?'),
        ),
        title: Text(tenant.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          currentPayment == null
              ? 'This month not recorded · $_currencySymbol ${tenant.monthlyRent.toStringAsFixed(2)}/mo'
              : 'Due $_currencySymbol${currentPayment.amountDue.toStringAsFixed(2)}  ·  '
                  'Bal $_currencySymbol${currentPayment.balance.toStringAsFixed(2)}',
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
