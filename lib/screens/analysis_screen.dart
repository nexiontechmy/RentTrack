import 'package:flutter/material.dart';

import '../models/charge.dart';
import '../models/payment.dart';
import '../models/tenant.dart';
import '../services/charge_repository.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../theme/app_theme.dart';
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
    if (!mounted) return;
    setState(() {
      _tenants = tenants;
      _payments = payments;
      _charges = charges;
      _currencySymbol = settings.currencySymbol;
      _loading = false;
    });
  }

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
    final totalCollected =
        _payments.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final totalDue = _payments.fold<double>(0, (sum, p) => sum + p.amountDue);
    final paidCount = _payments.where((p) => p.status == 'Paid').length;
    final unpaidCount = _payments.where((p) => p.status != 'Paid').length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _statCard(
                  'Total Collected',
                  '$_currencySymbol ${totalCollected.toStringAsFixed(2)}',
                  Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  'Total Due',
                  '$_currencySymbol ${totalDue.toStringAsFixed(2)}',
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
                child: _statCard('Paid Records', '$paidCount',
                    Icons.check_circle_outline,
                    color: AppColors.paid),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard('Unpaid Records', '$unpaidCount',
                    Icons.error_outline,
                    color: AppColors.unpaid),
              ),
            ],
          ),
        ),
        if (_charges.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _statCard(
              'Charges Collected',
              '$_currencySymbol ${_charges.fold<double>(0, (sum, c) => sum + c.amountPaid).toStringAsFixed(2)}',
              Icons.receipt_long_outlined,
            ),
          ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 16, 8),
          child: Text('By Tenant',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        ..._tenants.map(_tenantBreakdownCard),
      ],
    );
  }

  Widget _tenantBreakdownCard(Tenant tenant) {
    final tenantPayments =
        _payments.where((p) => p.tenantId == tenant.id).toList();
    final tenantCharges =
        _charges.where((c) => c.tenantId == tenant.id).toList();
    final collected =
        tenantPayments.fold<double>(0, (sum, p) => sum + p.amountPaid);
    final balance = tenantPayments.fold<double>(0, (sum, p) => sum + p.balance);
    final paidCount = tenantPayments.where((p) => p.status == 'Paid').length;
    final unpaidCount = tenantPayments.where((p) => p.status != 'Paid').length;
    final chargesBalance =
        tenantCharges.fold<double>(0, (sum, c) => sum + c.balance);

    return Card(
      child: ListTile(
        title: Text(tenant.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Collected $_currencySymbol${collected.toStringAsFixed(2)}  ·  '
          'Balance $_currencySymbol${balance.toStringAsFixed(2)}  ·  '
          '$paidCount paid / $unpaidCount unpaid'
          '${tenantCharges.isEmpty ? '' : '\nCharges balance $_currencySymbol${chargesBalance.toStringAsFixed(2)}'}',
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
            Text(value,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.subtleText(context))),
          ],
        ),
      ),
    );
  }
}
