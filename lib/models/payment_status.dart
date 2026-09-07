/// The single source of truth for payment/charge status.
///
/// Status is a pure function of the amounts, so it is always derived and
/// never stored as an independently-editable field. Storing it separately
/// allowed records like "due 1200 / paid 1200 / status Unpaid", which
/// silently corrupted every dashboard stat that trusts the status string.
class PaymentStatus {
  static const paid = 'Paid';
  static const partial = 'Partial';
  static const unpaid = 'Unpaid';

  static String of({required double amountDue, required double amountPaid}) {
    if (amountPaid <= 0) return unpaid;
    if (amountPaid >= amountDue) return paid;
    return partial;
  }
}
