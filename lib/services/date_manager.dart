import 'package:intl/intl.dart';

// This class manages date ranges for daily, weekly, and monthly views.
class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({required this.start, required this.end});

  // Factory constructors to create TimeRange instances for different periods.
  factory TimeRange.month(DateTime referenceDate) {
    final start = DateTime(referenceDate.year, referenceDate.month, 1);
    final end = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    return TimeRange(start: start, end: end);
  }

  // Factory constructor to create a TimeRange for the current week.
  factory TimeRange.week(DateTime referenceDate) {
    final weekday = referenceDate.weekday % 7; // Sunday = 0
    final start = referenceDate.subtract(Duration(days: weekday));
    final end = start.add(const Duration(days: 6));
    return TimeRange(start: start, end: end);
  }

  factory TimeRange.day(DateTime date) => TimeRange(start: date, end: date);

  TimeRange nextMonth() => TimeRange.month(DateTime(start.year, start.month + 1));
  TimeRange previousMonth() => TimeRange.month(DateTime(start.year, start.month - 1));

  TimeRange nextWeek() => TimeRange.week(start.add(const Duration(days: 7)));
  TimeRange previousWeek() => TimeRange.week(start.subtract(const Duration(days: 7)));

  // Format the date range for display.
  String formatRange() {
    final formatter = DateFormat('MMM d');
    final startStr = formatter.format(start);
    final endStr = formatter.format(end);

    // If it's the same day (e.g. daily view)
    if (startStr == endStr) return startStr;

    return "$startStr – $endStr";
  }
}