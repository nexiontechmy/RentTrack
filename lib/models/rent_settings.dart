/// Landlord-level configuration, shared across all tenants, stored
/// locally on-device.
class RentSettings {
  final String landlordName;
  final String landlordPhone;
  final String landlordAddress;
  final String currencySymbol;
  final int reminderDay; // day of month (1-28) for the rent reminder

  /// When on, each month's rent record is created automatically so rent
  /// counts as owed whether or not it was logged by hand.
  final bool autoCreateMonthlyRent;

  const RentSettings({
    this.landlordName = '',
    this.landlordPhone = '',
    this.landlordAddress = '',
    this.currencySymbol = 'RM',
    this.reminderDay = 1,
    this.autoCreateMonthlyRent = true,
  });

  RentSettings copyWith({
    String? landlordName,
    String? landlordPhone,
    String? landlordAddress,
    String? currencySymbol,
    int? reminderDay,
    bool? autoCreateMonthlyRent,
  }) {
    return RentSettings(
      landlordName: landlordName ?? this.landlordName,
      landlordPhone: landlordPhone ?? this.landlordPhone,
      landlordAddress: landlordAddress ?? this.landlordAddress,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      reminderDay: reminderDay ?? this.reminderDay,
      autoCreateMonthlyRent:
          autoCreateMonthlyRent ?? this.autoCreateMonthlyRent,
    );
  }

  bool get isConfigured => landlordName.isNotEmpty;
}
