import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/payment.dart';

/// Local, on-device store for payment records. All data lives in
/// SharedPreferences as a JSON-encoded list — no external backend.
class PaymentRepository {
  static const _storageKey = 'rent_track_payments';

  Future<List<Payment>> getAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((item) => Payment.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<Payment>> getForTenant(String tenantId) async {
    final payments = await getAll();
    return payments.where((p) => p.tenantId == tenantId).toList();
  }

  /// Removes every payment belonging to [tenantId] — used when a tenant is
  /// deleted.
  Future<void> deleteForTenant(String tenantId) async {
    final payments = await getAll();
    payments.removeWhere((p) => p.tenantId == tenantId);
    await _saveAll(payments);
  }

  Future<void> add(Payment payment) async {
    final payments = await getAll();
    payments.add(payment);
    await _saveAll(payments);
  }

  Future<void> update(Payment payment) async {
    final payments = await getAll();
    final index = payments.indexWhere((p) => p.id == payment.id);
    if (index == -1) {
      throw StateError('Payment not found: ${payment.id}');
    }
    payments[index] = payment;
    await _saveAll(payments);
  }

  Future<void> delete(String id) async {
    final payments = await getAll();
    payments.removeWhere((p) => p.id == id);
    await _saveAll(payments);
  }

  /// Replaces the entire local store — used by Excel import.
  Future<void> replaceAll(List<Payment> payments) async {
    await _saveAll(payments);
  }

  Future<void> _saveAll(List<Payment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(payments.map((p) => p.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }
}
