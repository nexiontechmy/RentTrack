import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/payment.dart';
import '../models/rent_settings.dart';
import '../models/tenant.dart';
import '../services/payment_repository.dart';
import '../services/settings_service.dart';
import '../services/tenant_repository.dart';
import '../utils/month_utils.dart';
import '../widgets/gradient_app_bar.dart';

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
  String _status = 'Unpaid';
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
      _status = payment.status;
      _paidDate = DateTime.tryParse(payment.paidDate);
      _tenantId = payment.tenantId;
    } else {
      _selectedMonth = DateTime.now();
      _tenantId = widget.initialTenantId;
    }
    _loadInitialData();
  }

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final amountDue = double.tryParse(_amountDueController.text.trim()) ?? 0;
    final amountPaid =
        double.tryParse(_amountPaidController.text.trim()) ?? 0;

    final payment = Payment(
      id: widget.payment?.id ?? const Uuid().v4(),
      tenantId: _tenantId!,
      month: MonthUtils.format(_selectedMonth),
      amountDue: amountDue,
      amountPaid: amountPaid,
      status: _status,
      paidDate: _paidDate == null ? '' : DateFormat('yyyy-MM-dd').format(_paidDate!),
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
                    _label('Tenant'),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        _tenantName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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
                    const SizedBox(height: 16),
                    _label('Status'),
                    _statusDropdown(),
                    const SizedBox(height: 16),
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
                      decoration:
                          const InputDecoration(label: Text('Reference number')),
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

  String get _tenantName {
    for (final tenant in _tenants) {
      if (tenant.id == _tenantId) return tenant.name;
    }
    return '';
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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

  Widget _statusDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _status,
      decoration: const InputDecoration(),
      items: const [
        DropdownMenuItem(value: 'Paid', child: Text('Paid')),
        DropdownMenuItem(value: 'Partial', child: Text('Partial')),
        DropdownMenuItem(value: 'Unpaid', child: Text('Unpaid')),
      ],
      onChanged: (value) => setState(() => _status = value ?? 'Unpaid'),
    );
  }
}
