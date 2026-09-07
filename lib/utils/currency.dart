import 'package:intl/intl.dart';

/// Consistent money formatting across the app. Without this the UI mixed
/// "RM1200.00" and "RM 1200.00", and never grouped thousands.
class Currency {
  static final _format = NumberFormat('#,##0.00');

  static String format(String symbol, double amount) =>
      '$symbol ${_format.format(amount)}';
}
