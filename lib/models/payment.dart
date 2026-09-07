import 'payment_status.dart';

/// A single month's rent payment record, belonging to one tenant.
class Payment {
  final String id;
  final String tenantId;
  final String month; // e.g. "August 2026"
  final double amountDue;
  final double amountPaid;
  final String paidDate;
  final String referenceNumber;
  final String notes;

  const Payment({
    required this.id,
    required this.tenantId,
    required this.month,
    required this.amountDue,
    required this.amountPaid,
    required this.paidDate,
    required this.referenceNumber,
    required this.notes,
  });

  double get balance => amountDue - amountPaid;

  /// Derived, never stored — see [PaymentStatus].
  String get status =>
      PaymentStatus.of(amountDue: amountDue, amountPaid: amountPaid);

  Payment copyWith({
    String? id,
    String? tenantId,
    String? month,
    double? amountDue,
    double? amountPaid,
    String? paidDate,
    String? referenceNumber,
    String? notes,
  }) {
    return Payment(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      month: month ?? this.month,
      amountDue: amountDue ?? this.amountDue,
      amountPaid: amountPaid ?? this.amountPaid,
      paidDate: paidDate ?? this.paidDate,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      notes: notes ?? this.notes,
    );
  }

  /// Serializes to a 9-column row for Excel export. `status` is included
  /// for readability in the spreadsheet but is ignored on import, since
  /// it is always derived from the amounts.
  List<dynamic> toRow() {
    return [
      id,
      tenantId,
      month,
      amountDue,
      amountPaid,
      status,
      paidDate,
      referenceNumber,
      notes,
    ];
  }

  factory Payment.fromRow(List<dynamic> row) {
    return Payment(
      id: row[0].toString(),
      tenantId: row[1].toString(),
      month: row[2].toString(),
      amountDue: _toDouble(row[3]),
      amountPaid: _toDouble(row[4]),
      // row[5] is the exported status — deliberately ignored.
      paidDate: row.length > 6 ? row[6].toString() : '',
      referenceNumber: row.length > 7 ? row[7].toString() : '',
      notes: row.length > 8 ? row[8].toString() : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'month': month,
      'amountDue': amountDue,
      'amountPaid': amountPaid,
      'status': status,
      'paidDate': paidDate,
      'referenceNumber': referenceNumber,
      'notes': notes,
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'].toString(),
      tenantId: json['tenantId']?.toString() ?? '',
      month: json['month'].toString(),
      amountDue: _toDouble(json['amountDue']),
      amountPaid: _toDouble(json['amountPaid']),
      paidDate: json['paidDate']?.toString() ?? '',
      referenceNumber: json['referenceNumber']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
    );
  }

  static double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
