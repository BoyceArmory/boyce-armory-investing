import '../utils/formatters.dart';

extension DateTimeX on DateTime {
  String get ago => Formatters.timeAgo(this);
  String get shortDate => Formatters.shortDate(this);
  String get fullDate => Formatters.fullDate(this);

  bool isSameDayAs(DateTime other) =>
      year == other.year && month == other.month && day == other.day;
}
