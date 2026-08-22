import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/charge.dart';

/// Local, on-device store for non-rent charges.
class ChargeRepository {
  static const _storageKey = 'rent_track_charges';

  Future<List<Charge>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Charge.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Charge>> getForTenant(String tenantId) async {
    final charges = await getAll();
    return charges.where((c) => c.tenantId == tenantId).toList();
  }

  Future<void> add(Charge charge) async {
    final charges = await getAll();
    charges.add(charge);
    await _saveAll(charges);
  }

  Future<void> update(Charge charge) async {
    final charges = await getAll();
    final index = charges.indexWhere((c) => c.id == charge.id);
    if (index == -1) {
      throw StateError('Charge not found: ${charge.id}');
    }
    charges[index] = charge;
    await _saveAll(charges);
  }

  Future<void> delete(String id) async {
    final charges = await getAll();
    charges.removeWhere((c) => c.id == id);
    await _saveAll(charges);
  }

  Future<void> deleteForTenant(String tenantId) async {
    final charges = await getAll();
    charges.removeWhere((c) => c.tenantId == tenantId);
    await _saveAll(charges);
  }

  /// Replaces the entire local store — used by Excel import.
  Future<void> replaceAll(List<Charge> charges) async {
    await _saveAll(charges);
  }

  Future<void> _saveAll(List<Charge> charges) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(charges.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
