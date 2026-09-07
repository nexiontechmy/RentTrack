import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/payment.dart';
import '../models/payment_status.dart';
import '../models/rent_settings.dart';
import '../models/tenant.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../theme/app_theme.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/status_badge.dart';

/// A single form used for both adding a new payment and editing an
/// existing one. Pass [payment] to edit; omit it to add (optionally with
/// [initialTenantId] pre-selected).
class PaymentFormScreen extends StatefulWidget {
  final Payment? payment;
  final String? initialTenantId;

  const PaymentFormScreen({super.key, this.payment, this.initialTenantId});

  bool get isEditing => payment != null;

  @override
  State<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends State<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = PaymentRepository();
  final _settingsService = SettingsService();
  final _tenantRepository = TenantRepository();

  late DateTime _selectedMonth;
  final _amountDueController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _referenceNumberController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _paidDate;
  String? _tenantId;

  RentSettings? _settings;
  List<Tenant> _tenants = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final payment = widget.payment;
    if (payment != null) {
      _selectedMonth = MonthUtils.tryParse(payment.month) ?? DateTime.now();
      _amountDueController.text = payment.amountDue.toStringAsFixed(2);
      _amountPaidController.text = payment.amountPaid.toStringAsFixed(2);
      _referenceNumberController.text = payment.referenceNumber;
      _notesController.text = payment.notes;
      _paidDate = DateTime.tryParse(payment.paidDate);
      _tenantId = payment.tenantId;
    } else {
      _selectedMonth = DateTime.now();
      _tenantId = widget.initialTenantId;
    }

    // Keep the derived status badge in sync as the amounts are typed.
    _amountDueController.addListener(_onAmountsChanged);
    _amountPaidController.addListener(_onAmountsChanged);

    _loadInitialData();
  }

  void _onAmountsChanged() => setState(() {});

  double get _amountDue =>
      double.tryParse(_amountDueController.text.trim()) ?? 0;
  double get _amountPaid =>
      double.tryParse(_amountPaidController.text.trim()) ?? 0;

  String get _derivedStatus =>
      PaymentStatus.of(amountDue: _amountDue, amountPaid: _amountPaid);

  Future<void> _loadInitialData() async {
    final settings = await _settingsService.load();
    final tenants = await _tenantRepository.getAll();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _tenants = tenants;
      _loading = false;
      if (!widget.isEditing && _amountDueController.text.isEmpty) {
        _prefillAmountDue();
      }
    });
  }

  void _prefillAmountDue() {
    for (final tenant in _tenants) {
      if (tenant.id == _tenantId) {
        _amountDueController.text = tenant.monthlyRent.toStringAsFixed(2);
        return;
      }
    }
  }

  String get _tenantName {
    for (final tenant in _tenants) {
      if (tenant.id == _tenantId) return tenant.name;
    }
    return '';
  }

  /// One tap for the common case: tenant paid the full amount today.
  void _markPaidInFull() {
    setState(() {
      _amountPaidController.text = _amountDue.toStringAsFixed(2);
      _paidDate ??= DateTime.now();
    });
  }

  @override
  void dispose() {
    _amountDueController.dispose();
    _amountPaidController.dispose();
    _referenceNumberController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      helpText: 'Select any day in the rent month',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _pickPaidDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _paidDate = picked);
    }
  }

  /// Guards against recording the same rent month twice for one tenant,
  /// which would double-count in every total.
  Future<bool> _confirmIfDuplicateMonth(String month) async {
    final existing = await _repository.getForTenant(_tenantId!);
    final clash = existing.any(
      (p) => p.month == month && p.id != widget.payment?.id,
    );
    if (!clash || !mounted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Already recorded'),
        content: Text(
          'There is already a payment recorded for $_tenantName in $month. '
          'Adding another will double-count it in your totals.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add anyway'),
          ),
        ],
      ),
    );
    return proceed ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final month = MonthUtils.format(_selectedMonth);
    if (!await _confirmIfDuplicateMonth(month)) return;
    if (!mounted) return;

    setState(() => _saving = true);

    final payment = Payment(
      id: widget.payment?.id ?? const Uuid().v4(),
      tenantId: _tenantId!,
      month: month,
      amountDue: _amountDue,
      amountPaid: _amountPaid,
      paidDate:
          _paidDate == null ? '' : DateFormat('yyyy-MM-dd').format(_paidDate!),
      referenceNumber: _referenceNumberController.text.trim(),
      notes: _notesController.text.trim(),
    );

    if (widget.isEditing) {
      await _repository.update(payment);
    } else {
      await _repository.add(payment);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final currency = _settings?.currencySymbol ?? 'RM';

    return Scaffold(
      appBar: GradientAppBar(
        title: widget.isEditing ? 'Edit Payment' : 'Add Payment',
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Tenant'),
                            Text(
                              _tenantName,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        StatusBadge(status: _derivedStatus),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _label('Month'),
                    _pickerField(
                      text: MonthUtils.format(_selectedMonth),
                      onTap: _pickMonth,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _amountField(
                            controller: _amountDueController,
                            label: 'Amount due ($currency)',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _amountField(
                            controller: _amountPaidController,
                            label: 'Amount paid ($currency)',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _markPaidInFull,
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Paid in full'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _label('Paid date'),
                    _pickerField(
                      text: _paidDate == null
                          ? 'Not set'
                          : DateFormat('d MMM yyyy').format(_paidDate!),
                      onTap: _pickPaidDate,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referenceNumberController,
                      decoration: const InputDecoration(
                          label: Text('Reference number')),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(label: Text('Notes')),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(widget.isEditing
                                ? 'Update Payment'
                                : 'Save Payment'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.subtleText(context))),
      );

  Widget _pickerField({required String text, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text),
            const Icon(Icons.calendar_today, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _amountField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(label: Text(label)),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        if (double.tryParse(value.trim()) == null) return 'Invalid number';
        return null;
      },
    );
  }
}
