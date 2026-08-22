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
    final now = DateTime.now();
    final current = DateTime(now.year, now.month);
    return parsed.isBefore(current);
  }
}
