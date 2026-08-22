import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../models/payment.dart';
import '../models/rent_settings.dart';
import '../models/tenant.dart';
import '../services/pdf_service.dart';
import '../services/settings_service.dart';
import '../widgets/gradient_app_bar.dart';

/// Generates and previews a PDF invoice for a payment, with built-in
/// print/share actions.
class InvoiceScreen extends StatefulWidget {
  final Payment payment;
  final Tenant tenant;

  const InvoiceScreen({super.key, required this.payment, required this.tenant});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  final _pdfService = PdfService();
  final _settingsService = SettingsService();

  RentSettings? _settings;

  @override
  void initState() {
    super.initState();
    _settingsService.load().then((settings) {
      if (mounted) setState(() => _settings = settings);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const GradientAppBar(title: 'Invoice'),
      body: _settings == null
          ? const Center(child: CircularProgressIndicator())
          : PdfPreview(
              build: (format) => _pdfService.buildInvoice(
                settings: _settings!,
                tenant: widget.tenant,
                payment: widget.payment,
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName:
                  'Invoice_${widget.tenant.name}_${widget.payment.month}.pdf'
                      .replaceAll(' ', '_'),
            ),
    );
  }
}
