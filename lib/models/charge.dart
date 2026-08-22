/// A one-off, non-rent charge billed to a tenant (utility bill,
/// maintenance, deposit, etc.).
class Charge {
  final String id;
  final String tenantId;
  final String description;
  final double amount;
  final double amountPaid;
  final String status; // "Paid" | "Partial" | "Unpaid"
  final String date; // when the charge was billed, yyyy-MM-dd
  final String paidDate;
  final String notes;

  const Charge({
    required this.id,
    required this.tenantId,
    required this.description,
    required this.amount,
    required this.amountPaid,
    required this.status,
    required this.date,
    required this.paidDate,
    required this.notes,
  });

  double get balance => amount - amountPaid;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'description': description,
      'amount': amount,
      'amountPaid': amountPaid,
      'status': status,
      'date': date,
      'paidDate': paidDate,
      'notes': notes,
    };
  }

  factory Charge.fromJson(Map<String, dynamic> json) {
    return Charge(
      id: json['id'].toString(),
      tenantId: json['tenantId']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      amountPaid: _toDouble(json['amountPaid']),
      status: json['status']?.toString() ?? 'Unpaid',
      date: json['date']?.toString() ?? '',
      paidDate: json['paidDate']?.toString() ?? '',
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
