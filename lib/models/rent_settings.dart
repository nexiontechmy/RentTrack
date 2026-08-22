/// Landlord-level configuration, shared across all tenants, stored
/// locally on-device.
class RentSettings {
  final String landlordName;
  final String landlordPhone;
  final String landlordAddress;
  final String currencySymbol;
  final int reminderDay; // day of month (1-28) for the rent reminder

  const RentSettings({
    this.landlordName = '',
    this.landlordPhone = '',
    this.landlordAddress = '',
    this.currencySymbol = 'RM',
    this.reminderDay = 1,
  });

  RentSettings copyWith({
    String? landlordName,
    String? landlordPhone,
    String? landlordAddress,
    String? currencySymbol,
    int? reminderDay,
  }) {
    return RentSettings(
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      landlordAddress: landlordAddress ?? this.landlordAddress,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      reminderDay: reminderDay ?? this.reminderDay,
    );
  }

  bool get isConfigured => landlordName.isNotEmpty;
}
