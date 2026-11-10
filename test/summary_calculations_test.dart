import 'package:caltrac/services/summary_calculations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('averagePerDay', () {
    test('300 grams over three days averages 100, without subtracting one', () {
      expect(averagePerDay(total: 300, dayCount: 3), 100);
    });

    test('a one-day range keeps the full total', () {
      expect(averagePerDay(total: 75, dayCount: 1), 75);
    });

    test('zero intake averages zero rather than negative one', () {
      expect(averagePerDay(total: 0, dayCount: 10), 0);
    });

    test('a future month with zero included days safely returns zero', () {
      expect(averagePerDay(total: 0, dayCount: 0), 0);
      expect(averagePerDay(total: 300, dayCount: 0), 0);
    });

    test('rounds daily averages to the nearest whole gram', () {
      expect(averagePerDay(total: 301, dayCount: 3), 100);
      expect(averagePerDay(total: 302, dayCount: 3), 101);
    });

    test('uses all included days, even when intake was logged on only one', () {
      // One logged day contributes 120 grams across three calendar days.
      expect(averagePerDay(total: 120, dayCount: 3), 40);
    });
  });
}
