import 'package:flutter_test/flutter_test.dart';
import 'package:rent_track/models/payment.dart';
import 'package:rent_track/models/rent_settings.dart';
import 'package:rent_track/models/tenant.dart';
import 'package:rent_track/services/payment_repository.dart';
import 'package:rent_track/services/rent_scheduler.dart';
import 'package:rent_track/services/settings_service.dart';
import 'package:rent_track/services/tenant_repository.dart';
import 'package:rent_track/utils/month_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late TenantRepository tenants;
  late PaymentRepository payments;
  late SettingsService settings;
  late RentScheduler scheduler;

  final thisMonth = MonthUtils.currentMonth();

  /// Label for the month [monthsAgo] before the current one.
  String label(int monthsAgo) =>
      MonthUtils.format(MonthUtils.addMonths(thisMonth, -monthsAgo));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tenants = TenantRepository();
    payments = PaymentRepository();
    settings = SettingsService();
    scheduler = RentScheduler(
      tenantRepository: tenants,
      paymentRepository: payments,
      settingsService: settings,
    );
  });

  Future<void> addTenant({
    String id = 't1',
    double rent = 1200,
    String? startMonth,
  }) {
    return tenants.add(Tenant(
      id: id,
      name: 'Tenant $id',
      monthlyRent: rent,
      startMonth: startMonth ?? MonthUtils.format(thisMonth),
    ));
  }

  Payment payment(String tenantId, String month) => Payment(
        id: 'seed-$month',
        tenantId: tenantId,
        month: month,
        amountDue: 1200,
        amountPaid: 1200,
        paidDate: '',
        referenceNumber: '',
        notes: '',
      );

  test('bills the current month for a tenancy starting this month', () async {
    await addTenant();

    expect(await scheduler.reconcile(), 1);

    final all = await payments.getAll();
    expect(all.single.month, MonthUtils.format(thisMonth));
    expect(all.single.amountDue, 1200);
    expect(all.single.amountPaid, 0);
    expect(all.single.status, 'Unpaid');
  });

  test('backfills every month since the tenancy started', () async {
    await addTenant(startMonth: label(3));

    // Three months ago through this month, inclusive.
    expect(await scheduler.reconcile(), 4);

    final months = (await payments.getAll()).map((p) => p.month).toSet();
    expect(months, {label(3), label(2), label(1), label(0)});
  });

  test('is idempotent — a second run bills nothing extra', () async {
    await addTenant(startMonth: label(2));

    expect(await scheduler.reconcile(), 3);
    expect(await scheduler.reconcile(), 0);
    expect((await payments.getAll()).length, 3);
  });

  test('does not duplicate a month already recorded by hand', () async {
    await addTenant(startMonth: label(1));
    // Landlord already logged this month themselves.
    await payments.addAll([payment('t1', label(0))]);

    // Only last month is missing.
    expect(await scheduler.reconcile(), 1);

    final months = (await payments.getAll()).map((p) => p.month).toList();
    expect(months.where((m) => m == label(0)).length, 1,
        reason: 'the hand-entered month must not be billed twice');
  });

  test('does not resurrect a record the landlord deleted', () async {
    await addTenant();
    await scheduler.reconcile();

    final created = (await payments.getAll()).single;
    await payments.delete(created.id);

    // The watermark has already passed this month, so it stays deleted.
    expect(await scheduler.reconcile(), 0);
    expect(await payments.getAll(), isEmpty);
  });

  test('does nothing when auto-billing is switched off', () async {
    await settings.save(const RentSettings(
      landlordName: 'Landlord',
      autoCreateMonthlyRent: false,
    ));
    await addTenant(startMonth: label(3));

    expect(await scheduler.reconcile(), 0);
    expect(await payments.getAll(), isEmpty);
  });

  test('skips tenants with no rent amount set', () async {
    await addTenant(id: 'paying', rent: 900);
    await addTenant(id: 'unset', rent: 0);

    expect(await scheduler.reconcile(), 1);
    expect((await payments.getAll()).single.tenantId, 'paying');
  });

  test('falls back to the earliest recorded payment when start is unknown',
      () async {
    await addTenant(startMonth: '');
    // A record with no tenancy start on file, e.g. from an older backup.
    await payments.addAll([payment('t1', label(2))]);

    // Fills the gap from that month to now, without duplicating it.
    expect(await scheduler.reconcile(), 2);

    final months = (await payments.getAll()).map((p) => p.month).toSet();
    expect(months, {label(2), label(1), label(0)});
  });

  test('records the resolved start month back onto the tenant', () async {
    await addTenant(startMonth: '');
    await scheduler.reconcile();

    final tenant = (await tenants.getAll()).single;
    expect(tenant.startMonth, isNotEmpty);
    expect(tenant.autoGeneratedThrough, MonthUtils.format(thisMonth));
  });

  group('MonthUtils.addMonths', () {
    test('rolls over the year end', () {
      expect(MonthUtils.addMonths(DateTime(2026, 11), 3), DateTime(2027, 2));
    });

    test('steps backwards across the year start', () {
      expect(MonthUtils.addMonths(DateTime(2026, 2), -3), DateTime(2025, 11));
    });

    test('never overflows a short month', () {
      // Jan 31 + 1 month must land in February, not spill into March.
      expect(MonthUtils.addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2));
    });
  });
}
