import 'dart:async';

import 'package:caltrac/screens/dailyprogress_screen.dart';
import 'package:caltrac/screens/monthlyprogress_screen.dart';
import 'package:caltrac/screens/weeklyprogress_screen.dart';
import 'package:caltrac/widgets/progress_widget.dart';
import 'package:caltrac/widgets/refreshing_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> summary(int caloriesOut) => {
  'calories_in': 2500,
  'calories_out': caloriesOut,
  'protein': 300,
  'carbs': 600,
  'fat': 90,
};

Finder get netCard => find.byWidgetPredicate(
  (widget) =>
      widget is ProgressWidget &&
      [
        'Net Calories',
        'Week Caloric Net',
        'Monthly Caloric Net',
      ].contains(widget.title),
);

int displayedNet(WidgetTester tester) =>
    tester.widget<ProgressWidget>(netCard).data;

// Advance async callbacks without waiting for an indeterminate progress animation.
Future<void> advance(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  for (final period in ['day', 'week', 'month']) {
    final initialDate = DateTime(2026, 1, 12);

    Future<void> open(
      WidgetTester tester,
      Future<Map<String, dynamic>> Function(DateTime) load,
      Future<void> Function(DateTime) refresh,
    ) async {
      final Widget screen;
      if (period == 'day') {
        screen = DailyProgressScreen(
          initialDate: initialDate,
          loadSummary: load,
          refreshWhoop: refresh,
        );
      } else if (period == 'week') {
        screen = WeeklyProgressScreen(
          initialDate: initialDate,
          loadSummary: (range) => load(range.start),
          refreshWhoop: (range) => refresh(range.start),
        );
      } else {
        screen = MonthlyProgressScreen(
          initialDate: initialDate,
          loadSummary: (range) => load(range.start),
          refreshWhoop: (range) => refresh(range.start),
        );
      }
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: screen)));
      await advance(tester);
    }

    testWidgets(
      '$period: saved totals stay visible until refreshed totals finish loading',
      (tester) async {
        final refresh = Completer<void>();
        final updated = Completer<Map<String, dynamic>>();
        var reads = 0;
        await open(tester, (_) {
          reads++;
          return reads == 1 ? Future.value(summary(2000)) : updated.future;
        }, (_) => refresh.future);
        expect(displayedNet(tester), 500);
        expect(reads, 1);
        expect(
          find.text('Updating WHOOP… Showing saved totals.'),
          findsOneWidget,
        );

        refresh.complete();
        await advance(tester);
        expect(reads, 2);
        expect(displayedNet(tester), 500);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);

        updated.complete(summary(2300));
        await advance(tester);
        expect(displayedNet(tester), 200);
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.text('Refresh complete.'), findsOneWidget);
      },
    );

    testWidgets(
      '$period: refresh failure keeps totals and reports incomplete refresh',
      (tester) async {
        var reads = 0;
        await open(tester, (_) async {
          reads++;
          return summary(2000);
        }, (_) async => throw StateError('WHOOP unavailable'));
        expect(
          reads,
          2,
        ); // Include any days that updated before a partial failure.
        expect(displayedNet(tester), 500);
        expect(
          find.text('WHOOP could not be fully updated. Showing saved totals.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsOneWidget);
        expect(find.text('Refresh complete.'), findsNothing);
      },
    );

    testWidgets('$period: failure to reread totals preserves saved data', (
      tester,
    ) async {
      var reads = 0;
      await open(tester, (_) async {
        if (++reads == 1) return summary(2000);
        throw StateError('Read failed');
      }, (_) async {});
      expect(displayedNet(tester), 500);
      expect(
        find.text('Could not reload updated totals. Showing saved totals.'),
        findsOneWidget,
      );
      expect(find.text('Refresh complete.'), findsNothing);
    });

    testWidgets('$period: Retry keeps saved totals visible and recovers', (
      tester,
    ) async {
      var refreshes = 0;
      final retry = Completer<void>();
      await open(
        tester,
        (_) async => summary(retry.isCompleted ? 2300 : 2000),
        (_) {
          if (++refreshes == 1) throw StateError('WHOOP unavailable');
          return retry.future;
        },
      );
      expect(displayedNet(tester), 500);
      await tester.tap(find.text('Retry'));
      await advance(tester);
      expect(displayedNet(tester), 500);
      expect(
        find.text('Updating WHOOP… Showing saved totals.'),
        findsOneWidget,
      );
      retry.complete();
      await advance(tester);
      expect(displayedNet(tester), 200);
      expect(refreshes, 2);
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Refresh complete.'), findsOneWidget);
    });

    testWidgets(
      '$period: an initial read failure can recover after refreshing',
      (tester) async {
        var reads = 0;
        await open(tester, (_) async {
          if (++reads == 1) throw StateError('Initial read failed');
          return summary(2300);
        }, (_) async {});
        expect(displayedNet(tester), 200);
        expect(find.text('Could not load this summary.'), findsNothing);
        expect(find.text('Refresh complete.'), findsOneWidget);
      },
    );

    testWidgets('$period: failed reads stop loading and allow retry', (
      tester,
    ) async {
      await open(
        tester,
        (_) async => throw StateError('Read failed'),
        (_) async {},
      );
      expect(netCard, findsNothing);
      expect(find.text('Could not load this summary.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets(
      '$period: an older refresh cannot replace the newly selected period',
      (tester) async {
        DateTime? first;
        final reads = <DateTime, int>{};
        final firstRefresh = Completer<void>();
        final nextRefresh = Completer<void>();
        await open(tester, (date) async {
          first ??= date;
          reads[date] = (reads[date] ?? 0) + 1;
          return summary(
            date == first ? 2000 : (nextRefresh.isCompleted ? 1700 : 1900),
          );
        }, (date) => date == first ? firstRefresh.future : nextRefresh.future);
        expect(displayedNet(tester), 500);
        await tester.tap(find.byIcon(Icons.arrow_forward));
        await advance(tester);
        expect(displayedNet(tester), 600);
        expect(reads.keys, hasLength(2));
        final next = reads.keys.last;
        final expected = period == 'day'
            ? DateTime(2026, 1, 13)
            : period == 'week'
            ? DateTime(2026, 1, 18)
            : DateTime(2026, 2, 1);
        expect(next, expected);
        nextRefresh.complete();
        await advance(tester);
        expect(displayedNet(tester), 800);
        firstRefresh.complete();
        await advance(tester);
        expect(displayedNet(tester), 800);
        expect(reads[first], 1); // Stale load does not even start another read.
        expect(find.text('Refresh complete.'), findsOneWidget);
      },
    );

    testWidgets(
      '$period: an old initial read cannot appear under the new date',
      (tester) async {
        DateTime? first;
        final oldRead = Completer<Map<String, dynamic>>();
        final newRefresh = Completer<void>();
        final refreshedDates = <DateTime>[];
        await open(
          tester,
          (date) {
            first ??= date;
            return date == first ? oldRead.future : Future.value(summary(1900));
          },
          (date) {
            refreshedDates.add(date);
            return newRefresh.future;
          },
        );
        expect(netCard, findsNothing);
        await tester.tap(find.byIcon(Icons.arrow_forward));
        await advance(tester);
        expect(displayedNet(tester), 600);
        oldRead.complete(summary(2000));
        await advance(tester);
        expect(displayedNet(tester), 600);
        expect(refreshedDates, hasLength(1));
        expect(refreshedDates.single, isNot(first));
        newRefresh.complete();
        await advance(tester);
      },
    );

    testWidgets('$period: an old final read cannot overwrite the new period', (
      tester,
    ) async {
      DateTime? first;
      var oldReads = 0;
      final oldResult = Completer<Map<String, dynamic>>();
      await open(tester, (date) {
        first ??= date;
        if (date == first && ++oldReads == 2) return oldResult.future;
        return Future.value(summary(date == first ? 2000 : 1700));
      }, (_) async {});
      expect(displayedNet(tester), 500);
      await tester.tap(find.byIcon(Icons.arrow_forward));
      await advance(tester);
      expect(displayedNet(tester), 800);
      oldResult.complete(summary(2300));
      await advance(tester);
      expect(displayedNet(tester), 800);
      expect(find.text('Refresh complete.'), findsOneWidget);
    });

    testWidgets(
      '$period: empty saved data still refreshes and can become populated',
      (tester) async {
        final refresh = Completer<void>();
        await open(
          tester,
          (_) async => refresh.isCompleted
              ? summary(2300)
              : {
                  'calories_in': 0,
                  'calories_out': 0,
                  'protein': 0,
                  'carbs': 0,
                  'fat': 0,
                },
          (_) => refresh.future,
        );
        expect(
          find.text('No data available for this $period.'),
          findsOneWidget,
        );
        expect(
          find.text('Updating WHOOP… Showing saved totals.'),
          findsOneWidget,
        );
        refresh.complete();
        await advance(tester);
        expect(displayedNet(tester), 200);
      },
    );
  }

  for (final stage in ['initial read', 'refresh', 'final read']) {
    for (final fail in [false, true]) {
      testWidgets(
        'disposed summary ignores $stage ${fail ? 'failure' : 'completion'}',
        (tester) async {
          final pendingRead = Completer<Map<String, dynamic>>();
          final pendingRefresh = Completer<void>();
          var reads = 0;
          await tester.pumpWidget(
            MaterialApp(
              home: RefreshingSummary(
                period: DateTime(2026, 1, 12),
                loadSummary: () {
                  reads++;
                  if (stage == 'initial read' ||
                      (stage == 'final read' && reads == 2)) {
                    return pendingRead.future;
                  }
                  return Future.value(summary(2000));
                },
                refreshWhoop: () =>
                    stage == 'refresh' ? pendingRefresh.future : Future.value(),
                builder: (_) => const Text('Saved summary'),
              ),
            ),
          );
          await advance(tester);
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          final error = StateError('Operation failed');
          if (stage == 'refresh') {
            if (fail) {
              pendingRefresh.completeError(error);
            } else {
              pendingRefresh.complete();
            }
          } else if (fail) {
            pendingRead.completeError(error);
          } else {
            pendingRead.complete(summary(2300));
          }
          await advance(tester);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
