import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../models/charge.dart';
import '../models/payment_status.dart';
import '../models/rent_settings.dart';
import '../services/charge_repository.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_app_bar.dart';
import '../widgets/status_badge.dart';

/// Form used for both adding a new non-rent charge and editing an
/// existing one. Pass [charge] to edit; omit it (with [tenantId]) to add.
class ChargeFormScreen extends StatefulWidget {
  final Charge? charge;
  final String? tenantId;

  const ChargeFormScreen({super.key, this.charge, this.tenantId});

  bool get isEditing => charge != null;

  @override
  State<ChargeFormScreen> createState() => _ChargeFormScreenState();
}

class _ChargeFormScreenState extends State<ChargeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ChargeRepository();
  final _settingsService = SettingsService();

  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _paidDate;

  RentSettings? _settings;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final charge = widget.charge;
    if (charge != null) {
      _descriptionController.text = charge.description;
      _amountController.text = charge.amount.toStringAsFixed(2);
      _amountPaidController.text = charge.amountPaid.toStringAsFixed(2);
      _notesController.text = charge.notes;
      _date = DateTime.tryParse(charge.date) ?? DateTime.now();
      _paidDate = DateTime.tryParse(charge.paidDate);
    }

    // Keep the derived status badge in sync as the amounts are typed.
    _amountController.addListener(_onAmountsChanged);
    _amountPaidController.addListener(_onAmountsChanged);

    _settingsService.load().then((settings) {
      if (mounted) setState(() => _settings = settings);
    });
  }

  void _onAmountsChanged() => setState(() {});

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;
  double get _amountPaid =>
      double.tryParse(_amountPaidController.text.trim()) ?? 0;

  String get _derivedStatus =>
      PaymentStatus.of(amountDue: _amount, amountPaid: _amountPaid);

  void _markPaidInFull() {
    setState(() {
      _amountPaidController.text = _amount.toStringAsFixed(2);
      _paidDate ??= DateTime.now();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickPaidDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidDate ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _paidDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final charge = Charge(
      id: widget.charge?.id ?? const Uuid().v4(),
      tenantId: widget.charge?.tenantId ?? widget.tenantId!,
      description: _descriptionController.text.trim(),
      amount: _amount,
      amountPaid: _amountPaid,
      date: DateFormat('yyyy-MM-dd').format(_date),
      paidDate:
          _paidDate == null ? '' : DateFormat('yyyy-MM-dd').format(_paidDate!),
      notes: _notesController.text.trim(),
    );

    if (widget.isEditing) {
      await _repository.update(charge);
    } else {
      await _repository.add(charge);
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
        title: widget.isEditing ? 'Edit Charge' : 'Add Charge',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: StatusBadge(status: _derivedStatus),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                    label: Text('Description (e.g. Electricity bill)')),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 16),
              _label('Date'),
              _pickerField(
                text: DateFormat('d MMM yyyy').format(_date),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _amountField(
                      controller: _amountController,
                      label: 'Amount ($currency)',
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
                      : Text(widget.isEditing ? 'Update Charge' : 'Save Charge'),
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
