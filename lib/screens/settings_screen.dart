import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/rent_settings.dart';
import '../services/excel_service.dart';
import '../services/settings_service.dart';
import '../theme/theme_controller.dart';
import '../widgets/gradient_app_bar.dart';

class SettingsScreen extends StatefulWidget {
  final ThemeController themeController;

  const SettingsScreen({super.key, required this.themeController});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _excelService = ExcelService();
  final _formKey = GlobalKey<FormState>();

  bool _loading = true;
  bool _saving = false;
  bool _exporting = false;
  bool _importing = false;

  final _landlordNameController = TextEditingController();
  final _landlordPhoneController = TextEditingController();
  final _landlordAddressController = TextEditingController();
  final _currencySymbolController = TextEditingController();

  int _reminderDay = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await _settingsService.load();
    _landlordNameController.text = settings.landlordName;
    _landlordPhoneController.text = settings.landlordPhone;
    _landlordAddressController.text = settings.landlordAddress;
    _currencySymbolController.text = settings.currencySymbol;
    _reminderDay = settings.reminderDay;
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final settings = RentSettings(
      landlordName: _landlordNameController.text.trim(),
      landlordPhone: _landlordPhoneController.text.trim(),
      landlordAddress: _landlordAddressController.text.trim(),
      currencySymbol: _currencySymbolController.text.trim().isEmpty
          ? 'RM'
          : _currencySymbolController.text.trim(),
      reminderDay: _reminderDay,
    );

    await _settingsService.save(settings);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings saved')),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _exporting = true);
    try {
      final file = await _excelService.exportToFile();
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'RentTrack backup'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );
    if (file == null || file.path == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Replace all data?'),
        content: const Text(
          'Importing will permanently replace every tenant and payment '
          'currently stored in the app with the contents of this file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _importing = true);
    try {
      await _excelService.importFromFile(File(file.path!));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Import complete')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _landlordNameController.dispose();
    _landlordPhoneController.dispose();
    _landlordAddressController.dispose();
    _currencySymbolController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Settings'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionTitle('Landlord'),
                    _textField(
                      controller: _landlordNameController,
                      label: 'Landlord name',
                      requiredField: true,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _landlordPhoneController,
                      label: 'Landlord phone',
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _textField(
                      controller: _landlordAddressController,
                      label: 'Landlord address',
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Currency'),
                    _textField(
                      controller: _currencySymbolController,
                      label: 'Currency symbol',
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Rent Reminder'),
                    const Text(
                      'Day of the month to send a recurring payment reminder',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    _ReminderDayPicker(
                      value: _reminderDay,
                      onChanged: (day) => setState(() => _reminderDay = day),
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
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Settings'),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _sectionTitle('Appearance'),
                    _darkModeToggle(),
                    const SizedBox(height: 32),
                    _sectionTitle('Backup & Restore'),
                    const Text(
                      'Export every tenant and payment to an Excel file, '
                      'or import one to restore/replace your data.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _exporting ? null : _exportBackup,
                            icon: _exporting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.upload_file),
                            label: const Text('Export'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _importing ? null : _importBackup,
                            icon: _importing
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download_outlined),
                            label: const Text('Import'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _darkModeToggle() {
    return ListenableBuilder(
      listenable: widget.themeController,
      builder: (context, _) {
        final isDark = widget.themeController.mode == ThemeMode.dark;
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Dark mode'),
          value: isDark,
          onChanged: (value) => widget.themeController
              .setMode(value ? ThemeMode.dark : ThemeMode.light),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(label: Text(label)),
      validator: requiredField
          ? (value) =>
              (value == null || value.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}

class _ReminderDayPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _ReminderDayPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 28,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final day = index + 1;
          final selected = day == value;
          return ChoiceChip(
            label: Text('$day'),
            selected: selected,
            onSelected: (_) => onChanged(day),
          );
        },
      ),
    );
  }
}
