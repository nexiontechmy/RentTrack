import 'package:intl/intl.dart';

/// Helpers for converting between the "Month YYYY" strings used in
/// [Payment.month] (e.g. "August 2026") and [DateTime].
class MonthUtils {
  static final _format = DateFormat('MMMM yyyy');

  static String format(DateTime date) => _format.format(DateTime(date.year, date.month));

  static String currentMonthLabel() => format(DateTime.now());

  /// Parses a "Month YYYY" label into a DateTime (day 1). Returns null if
  /// the string doesn't match the expected format.
  static DateTime? tryParse(String label) {
    try {
      return _format.parseStrict(label);
    } catch (_) {
      return null;
    }
  }

  static bool isBeforeCurrentMonth(String label) {
    final parsed = tryParse(label);
    if (parsed == null) return false;
    return parsed.isBefore(currentMonth());
  }

  /// The current month, normalised to day 1 for safe comparison.
  static DateTime currentMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// Steps [months] forward, rolling the year over as needed. Always
  /// lands on day 1, so it never overflows short months the way
  /// DateTime(y, m, 31) would.
  static DateTime addMonths(DateTime date, int months) {
    final zeroBased = date.month - 1 + months;
    // Floor division, not truncating (~/): going backwards past January
    // gives a negative index, and ~/ rounds toward zero, which would
    // leave the year unchanged (Feb 2026 - 3 => Nov 2026, not Nov 2025).
    final yearShift = (zeroBased / 12).floor();
    return DateTime(date.year + yearShift, (zeroBased % 12) + 1);
  }
}
