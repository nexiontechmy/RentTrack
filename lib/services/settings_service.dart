import 'package:shared_preferences/shared_preferences.dart';

import '../models/rent_settings.dart';

/// Reads/writes landlord-level configuration to local device storage.
class SettingsService {
  static const _landlordNameKey = 'landlordName';
  static const _landlordPhoneKey = 'landlordPhone';
  static const _landlordAddressKey = 'landlordAddress';
  static const _currencySymbolKey = 'currencySymbol';
  static const _reminderDayKey = 'reminderDay';
  static const _autoCreateMonthlyRentKey = 'autoCreateMonthlyRent';

  Future<RentSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return RentSettings(
      landlordName: prefs.getString(_landlordNameKey) ?? '',
      landlordPhone: prefs.getString(_landlordPhoneKey) ?? '',
      landlordAddress: prefs.getString(_landlordAddressKey) ?? '',
      currencySymbol: prefs.getString(_currencySymbolKey) ?? 'RM',
      reminderDay: prefs.getInt(_reminderDayKey) ?? 1,
      autoCreateMonthlyRent:
          prefs.getBool(_autoCreateMonthlyRentKey) ?? true,
    );
  }

  Future<void> save(RentSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_landlordNameKey, settings.landlordName);
    await prefs.setString(_landlordPhoneKey, settings.landlordPhone);
    await prefs.setString(_landlordAddressKey, settings.landlordAddress);
    await prefs.setString(_currencySymbolKey, settings.currencySymbol);
    await prefs.setInt(_reminderDayKey, settings.reminderDay);
    await prefs.setBool(
        _autoCreateMonthlyRentKey, settings.autoCreateMonthlyRent);
  }
}
