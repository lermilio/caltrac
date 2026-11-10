import 'dart:async';

import 'package:caltrac/screens/log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const nutrition = {'calories': 200, 'protein': 10, 'carbs': 20, 'fat': 9};

void main() {
  for (final scenario in [
    'retry',
    'new identical log',
    'changed input',
    'changed date',
  ]) {
    testWidgets('food identity: $scenario', (tester) async {
      var parses = 0;
      final saved = <Map<String, dynamic>>[];
      final dates = <DateTime>[];
      await tester.pumpWidget(
        MaterialApp(
          home: LogScreen(
            parseNutrition: (_) async {
              parses++;
              return {...nutrition, 'calories': 200 + parses};
            },
            saveEntry:
                ({required userId, required date, required entryData}) async {
                  saved.add(Map.of(entryData));
                  dates.add(date);
                  if (saved.length == 1 && scenario != 'new identical log') {
                    throw StateError('Response lost; save outcome unknown');
                  }
                },
            entriesWidget: const SizedBox.shrink(),
          ),
        ),
      );

      Future<void> submit() async {
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Submit'));
        await tester.pumpAndSettle();
      }

      await tester.enterText(find.byType(TextField).first, 'Chicken breast');
      await tester.enterText(find.byType(TextField).last, '2026-11-08');
      await submit();
      if (scenario == 'new identical log') {
        await tester.enterText(find.byType(TextField).first, 'Chicken breast');
        await tester.enterText(find.byType(TextField).last, '2026-11-08');
      } else if (scenario == 'changed input') {
        await tester.enterText(find.byType(TextField).first, 'Rice');
      } else if (scenario == 'changed date') {
        await tester.enterText(find.byType(TextField).last, '2026-11-09');
      }
      await submit();
      expect(saved, hasLength(2));
      if (scenario == 'retry') {
        expect(saved[1], saved[0]);
        expect(parses, 1);
        expect(dates[1], dates[0]);
      } else {
        expect(saved[1]['id'], isNot(saved[0]['id']));
        expect(parses, 2);
      }
      if (scenario == 'changed date') expect(dates[1], DateTime(2026, 11, 9));
      if (scenario == 'changed input') expect(saved[1]['input'], 'Rice');
    });
  }

  for (final extraCalories in [false, true]) {
    final mode = extraCalories ? 'extra calories' : 'food';
    final input = extraCalories ? '450' : 'Chicken breast';
    final success = extraCalories ? 'Extra calories logged ✅' : 'Entry saved ✅';

    Future<void> openForm(
      WidgetTester tester,
      Future<void> Function() save,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LogScreen(
            parseNutrition: (_) async => nutrition,
            saveEntry: ({required userId, required date, required entryData}) {
              expect(date, DateTime(2026, 11, 8));
              expect(entryData['id'], matches(RegExp(r'^[0-9a-f]{32}$')));
              expect(Map.of(entryData)..remove('id'), {
                'input': input,
                ...nutrition,
              });
              return save();
            },
            saveExtraCalories:
                ({required userId, required date, required extraCals}) {
                  expect(date, DateTime(2026, 11, 8));
                  expect(extraCals, 450);
                  return save();
                },
            // Keep these UI tests isolated from history's Firestore reads.
            entriesWidget: const SizedBox.shrink(),
          ),
        ),
      );
      if (extraCalories) {
        await tester.tap(find.byType(DropdownButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Enter Extra Kcals').last);
        await tester.pumpAndSettle();
      }
      await tester.enterText(find.byType(TextField).first, input);
      await tester.enterText(find.byType(TextField).last, '2026-11-08');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
    }

    testWidgets('$mode: success waits for persistence', (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await openForm(tester, () {
        calls++;
        return pending.future;
      });
      expect(calls, 0);
      expect(find.text(success), findsNothing);
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text(success), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        input,
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      expect(calls, 1);

      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text(success), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('$mode: save failure retains inputs and allows retry', (
      tester,
    ) async {
      final pending = Completer<void>();
      var calls = 0;
      await openForm(tester, () {
        calls++;
        return calls == 1 ? pending.future : Future<void>.value();
      });
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      pending.completeError(StateError('Save failed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Save failed'), findsOneWidget);
      expect(find.text(success), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        input,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        '2026-11-08',
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
    });

    testWidgets('$mode: cancellation does not save or clear inputs', (
      tester,
    ) async {
      var calls = 0;
      await openForm(tester, () async {
        calls++;
      });
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text(success), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        input,
      );
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNotNull,
      );
    });

    for (final fail in [false, true]) {
      testWidgets(
        '$mode: disposed screen handles save ${fail ? 'failure' : 'success'}',
        (tester) async {
          final pending = Completer<void>();
          await openForm(tester, () => pending.future);
          await tester.tap(find.text('Submit'));
          await tester.pumpAndSettle();
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          if (fail) {
            pending.completeError(StateError('Save failed'));
          } else {
            pending.complete();
          }
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('food: parser failure reaches the UI without saving', (
    tester,
  ) async {
    var saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: LogScreen(
          parseNutrition: (_) async => throw StateError('Parser failed'),
          saveEntry:
              ({required userId, required date, required entryData}) async {
                saves++;
              },
          entriesWidget: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Chicken breast');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.textContaining('Parser failed'), findsOneWidget);
    expect(find.text('Entry saved ✅'), findsNothing);
    expect(saves, 0);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'Chicken breast',
    );
  });

  testWidgets('food: disposed screen does not show parser confirmation', (
    tester,
  ) async {
    final pending = Completer<Map<String, int>>();
    await tester.pumpWidget(
      MaterialApp(
        home: LogScreen(
          parseNutrition: (_) => pending.future,
          entriesWidget: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'Chicken breast');
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    pending.complete(nutrition);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
