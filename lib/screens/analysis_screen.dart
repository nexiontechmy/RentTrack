import 'package:flutter/material.dart';

import '../models/charge.dart';
import '../models/payment.dart';
import '../models/tenant.dart';
import '../services/charge_repository.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../theme/app_theme.dart';
import '../utils/currency.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';

/// Analysis tab: cross-tenant payment analytics.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final _tenantRepository = TenantRepository();
  final _paymentRepository = PaymentRepository();
  final _chargeRepository = ChargeRepository();
  final _settingsService = SettingsService();

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

  String _money(double amount) => Currency.format(_currencySymbol, amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Analysis'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tenants.isEmpty
              ? Center(
                  child: Text('Add a tenant to see analytics here.',
                      style: TextStyle(color: AppColors.subtleText(context))),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _content(),
                ),
    );
  }

  Widget _content() {
    final rentCollected =
        _payments.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final chargesCollected =
        _charges.fold<double>(0, (sum, c) => sum + c.amountPaid);

    var outstanding = 0.0;
    for (final p in _payments) {
      if (p.balance > 0) outstanding += p.balance;
    }
    for (final c in _charges) {
      if (c.balance > 0) outstanding += c.balance;
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  'Rent Collected',
                  _money(rentCollected),
                  Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Charges Collected',
                  _money(chargesCollected),
                  Icons.receipt_long_outlined,
                ),
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
                  'Total Outstanding',
                  _money(outstanding),
                  Icons.account_balance_wallet_outlined,
                  color: outstanding > 0 ? AppColors.unpaid : AppColors.paid,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Total Received',
                  _money(rentCollected + chargesCollected),
                  Icons.trending_up,
                  color: AppColors.paid,
                ),
              ),
            ],
          ),
        ),
        _monthlyBreakdown(),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text('By Tenant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ..._tenants.map(_tenantBreakdownCard),
      ],
    );
  }

  /// Rent collected per month, most recent first, with a proportional bar
  /// so months can be compared at a glance.
  Widget _monthlyBreakdown() {
    if (_payments.isEmpty) return const SizedBox.shrink();

    final byMonth = <String, double>{};
    for (final payment in _payments) {
      byMonth[payment.month] = (byMonth[payment.month] ?? 0) + payment.amountPaid;
    }

    final months = byMonth.keys.toList()
      ..sort((a, b) {
        final dateA = MonthUtils.tryParse(a);
        final dateB = MonthUtils.tryParse(b);
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA); // newest first
      });

    final maxValue =
        byMonth.values.fold<double>(0, (max, v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text('Collected by Month',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: months.take(12).map((month) {
                final value = byMonth[month]!;
                final fraction = maxValue == 0 ? 0.0 : value / maxValue;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(month, style: const TextStyle(fontSize: 13)),
                          Text(_money(value),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fraction,
                          minHeight: 6,
                          backgroundColor:
                              AppColors.navyLight.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tenantBreakdownCard(Tenant tenant) {
    final tenantPayments =
        _payments.where((p) => p.tenantId == tenant.id).toList();
    final tenantCharges =
        _charges.where((c) => c.tenantId == tenant.id).toList();

    final collected =
        tenantPayments.fold<double>(0, (sum, p) => sum + p.amountPaid) +
            tenantCharges.fold<double>(0, (sum, c) => sum + c.amountPaid);

    var outstanding = 0.0;
    for (final p in tenantPayments) {
      if (p.balance > 0) outstanding += p.balance;
    }
    for (final c in tenantCharges) {
      if (c.balance > 0) outstanding += c.balance;
    }

    final paidCount = tenantPayments.where((p) => p.status == 'Paid').length;
    final unpaidCount = tenantPayments.where((p) => p.status != 'Paid').length;

    return Card(
      child: ListTile(
        title: Text(tenant.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Collected ${_money(collected)}  ·  '
              '$paidCount paid / $unpaidCount unpaid',
              style: TextStyle(color: AppColors.subtleText(context)),
            ),
            if (outstanding > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Outstanding ${_money(outstanding)}',
                  style: const TextStyle(
                      color: AppColors.unpaid, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
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
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.subtleText(context))),
          ],
        ),
      ),
    );
  }
}
