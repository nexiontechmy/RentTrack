import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tenant.dart';

/// Local, on-device store for tenants.
class TenantRepository {
  static const _storageKey = 'rent_track_tenants';

  Future<List<Tenant>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Tenant.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> add(Tenant tenant) async {
    final tenants = await getAll();
    tenants.add(tenant);
    await _saveAll(tenants);
  }

  Future<void> update(Tenant tenant) async {
    final tenants = await getAll();
    final index = tenants.indexWhere((t) => t.id == tenant.id);
    if (index == -1) {
      throw StateError('Tenant not found: ${tenant.id}');
    }
    tenants[index] = tenant;
    await _saveAll(tenants);
  }

  Future<void> delete(String id) async {
    final tenants = await getAll();
    tenants.removeWhere((t) => t.id == id);
    await _saveAll(tenants);
  }

  /// Replaces the entire local store — used by Excel import.
  Future<void> replaceAll(List<Tenant> tenants) async {
    await _saveAll(tenants);
  }

  Future<void> _saveAll(List<Tenant> tenants) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(tenants.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
