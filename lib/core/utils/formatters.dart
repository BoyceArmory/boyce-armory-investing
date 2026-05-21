import 'package:intl/intl.dart';

/// Centralized number/date formatters so prices/% values look consistent.
class Formatters {
  Formatters._();

  static final NumberFormat _usd = NumberFormat.simpleCurrency(decimalDigits: 2);
  static final NumberFormat _usdNoCents =
      NumberFormat.simpleCurrency(decimalDigits: 0);
  static final NumberFormat _pct =
      NumberFormat.decimalPercentPattern(decimalDigits: 2);
  static final NumberFormat _decimal2 = NumberFormat('#,##0.00');
  static final NumberFormat _decimal0 = NumberFormat('#,##0');

  static String price(num? value) {
    if (value == null) return '-';
    return _usd.format(value);
  }

  static String priceCompact(num? value) {
    if (value == null) return '-';
    return value.abs() >= 1000 ? _usdNoCents.format(value) : _usd.format(value);
  }

  static String number(num? value, {int fractionDigits = 2}) {
    if (value == null) return '-';
    return (fractionDigits == 0 ? _decimal0 : _decimal2).format(value);
  }

  /// Accepts a fraction (0.07) -> "7.00%", or pass `alreadyPercent: true` for 7 -> "7.00%".
  static String percent(num? value, {bool alreadyPercent = false}) {
    if (value == null) return '-';
    final num v = alreadyPercent ? value / 100 : value;
    return _pct.format(v);
  }

  static String signedPercent(num? value, {bool alreadyPercent = false}) {
    if (value == null) return '-';
    final String formatted = percent(value, alreadyPercent: alreadyPercent);
    return value >= 0 ? '+$formatted' : formatted;
  }

  /// Human-readable "time ago" relative to now.
  static String timeAgo(DateTime when) {
    final Duration diff = DateTime.now().difference(when);
    if (diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(when);
  }

  static String shortDate(DateTime when) => DateFormat('MMM d').format(when);
  static String fullDate(DateTime when) =>
      DateFormat('MMM d, y · h:mm a').format(when);
}
