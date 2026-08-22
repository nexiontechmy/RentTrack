/// A tenant/client the landlord rents a property to. Each tenant has their
/// own independent payment history.
class Tenant {
  final String id;
  final String name;
  final String phone;
  final String propertyDescription;
  final double monthlyRent;

  const Tenant({
    required this.id,
    required this.name,
    this.phone = '',
    this.propertyDescription = '',
    this.monthlyRent = 0.0,
  });

  Tenant copyWith({
    String? name,
    String? phone,
    String? propertyDescription,
    double? monthlyRent,
  }) {
    return Tenant(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      propertyDescription: propertyDescription ?? this.propertyDescription,
      monthlyRent: monthlyRent ?? this.monthlyRent,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'propertyDescription': propertyDescription,
      'monthlyRent': monthlyRent,
    };
  }

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: json['id'].toString(),
      name: json['name'].toString(),
      phone: json['phone']?.toString() ?? '',
      propertyDescription: json['propertyDescription']?.toString() ?? '',
      monthlyRent: json['monthlyRent'] is num
          ? (json['monthlyRent'] as num).toDouble()
          : double.tryParse(json['monthlyRent'].toString()) ?? 0.0,
    );
  }
}
