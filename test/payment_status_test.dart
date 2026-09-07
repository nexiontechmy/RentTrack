import 'package:flutter_test/flutter_test.dart';
import 'package:rent_track/models/charge.dart';
import 'package:rent_track/models/payment.dart';
import 'package:rent_track/models/payment_status.dart';

Payment payment({required double due, required double paid}) => Payment(
      id: 'p1',
      tenantId: 't1',
      month: 'August 2026',
      amountDue: due,
      amountPaid: paid,
      paidDate: '',
      referenceNumber: '',
      notes: '',
    );

void main() {
  group('PaymentStatus.of', () {
    test('nothing paid is Unpaid', () {
      expect(PaymentStatus.of(amountDue: 1200, amountPaid: 0),
          PaymentStatus.unpaid);
    });

    test('paid in full is Paid', () {
      expect(PaymentStatus.of(amountDue: 1200, amountPaid: 1200),
          PaymentStatus.paid);
    });

    test('overpayment still counts as Paid', () {
      expect(PaymentStatus.of(amountDue: 1200, amountPaid: 1500),
          PaymentStatus.paid);
    });

    test('part payment is Partial', () {
      expect(PaymentStatus.of(amountDue: 1200, amountPaid: 500),
          PaymentStatus.partial);
    });

    test('a zero-value record with nothing paid is Unpaid, not Paid', () {
      expect(
          PaymentStatus.of(amountDue: 0, amountPaid: 0), PaymentStatus.unpaid);
    });
  });

  group('Payment', () {
    test('derives status from amounts', () {
      expect(payment(due: 1200, paid: 1200).status, PaymentStatus.paid);
      expect(payment(due: 1200, paid: 400).status, PaymentStatus.partial);
      expect(payment(due: 1200, paid: 0).status, PaymentStatus.unpaid);
    });

    test('balance is due minus paid', () {
      expect(payment(due: 1200, paid: 400).balance, 800);
    });

    test('ignores a stale stored status when reading JSON', () {
      // Simulates a record saved before status was derived, or a
      // spreadsheet where someone edited the amounts but not the status.
      final stale = payment(due: 1200, paid: 1200).toJson()
        ..['status'] = PaymentStatus.unpaid;

      expect(Payment.fromJson(stale).status, PaymentStatus.paid);
    });

    test('ignores a stale status column when reading an Excel row', () {
      final row = payment(due: 1200, paid: 1200).toRow();
      row[5] = PaymentStatus.unpaid; // stale status column

      expect(Payment.fromRow(row).status, PaymentStatus.paid);
    });

    test('round-trips through JSON', () {
      final original = payment(due: 1200, paid: 600);
      final restored = Payment.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.tenantId, original.tenantId);
      expect(restored.month, original.month);
      expect(restored.amountDue, original.amountDue);
      expect(restored.amountPaid, original.amountPaid);
      expect(restored.status, original.status);
    });
  });

  group('Charge', () {
    Charge charge({required double amount, required double paid}) => Charge(
          id: 'c1',
          tenantId: 't1',
          description: 'Electricity',
          amount: amount,
          amountPaid: paid,
          date: '2026-08-01',
          paidDate: '',
          notes: '',
        );

    test('derives status from amounts', () {
      expect(charge(amount: 200, paid: 200).status, PaymentStatus.paid);
      expect(charge(amount: 200, paid: 50).status, PaymentStatus.partial);
      expect(charge(amount: 200, paid: 0).status, PaymentStatus.unpaid);
    });

    test('ignores a stale stored status when reading JSON', () {
      final stale = charge(amount: 200, paid: 200).toJson()
        ..['status'] = PaymentStatus.unpaid;

      expect(Charge.fromJson(stale).status, PaymentStatus.paid);
    });
  });
}
