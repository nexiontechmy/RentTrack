import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/tenant.dart';
import '../services/tenant_repository.dart';
import '../widgets/gradient_app_bar.dart';

/// Form used for both adding a new tenant and editing an existing one.
/// Pass [tenant] to edit; omit it to add.
class TenantFormScreen extends StatefulWidget {
  final Tenant? tenant;

  const TenantFormScreen({super.key, this.tenant});

  bool get isEditing => tenant != null;

  @override
  State<TenantFormScreen> createState() => _TenantFormScreenState();
}

class _TenantFormScreenState extends State<TenantFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TenantRepository();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _propertyDescriptionController = TextEditingController();
  final _monthlyRentController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final tenant = widget.tenant;
    if (tenant != null) {
      _nameController.text = tenant.name;
      _phoneController.text = tenant.phone;
      _propertyDescriptionController.text = tenant.propertyDescription;
      _monthlyRentController.text = tenant.monthlyRent == 0.0
          ? ''
          : tenant.monthlyRent.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _propertyDescriptionController.dispose();
    _monthlyRentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final tenant = Tenant(
      id: widget.tenant?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      propertyDescription: _propertyDescriptionController.text.trim(),
      monthlyRent:
          double.tryParse(_monthlyRentController.text.trim()) ?? 0.0,
    );

    if (widget.isEditing) {
      await _repository.update(tenant);
    } else {
      await _repository.add(tenant);
    }

    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GradientAppBar(
        title: widget.isEditing ? 'Edit Tenant' : 'Add Tenant',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(label: Text('Tenant name')),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Required'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(label: Text('Phone')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _propertyDescriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                    label: Text('Property description')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _monthlyRentController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(label: Text('Monthly rent')),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Required';
                  if (double.tryParse(value.trim()) == null) {
                    return 'Enter a valid number';
                  }
                  return null;
                },
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
                      : Text(widget.isEditing ? 'Update Tenant' : 'Add Tenant'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
