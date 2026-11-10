import 'dart:async';

import 'package:caltrac/widgets/view_weight_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const first = {'id': '2026-11-09', 'weight': 170};
const second = {'id': '2026-11-10', 'weight': 169.5};

Future<void> open(
  WidgetTester tester,
  Future<List<Map<String, dynamic>>> Function() load, {
  Future<void> Function(String)? delete,
  GlobalKey<ViewWeightWidgetState>? key,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ViewWeightWidget(key: key, loadWeights: load, deleteWeight: delete),
    ),
  );
  await tester.pump();
}

Future<void> confirmDeletion(WidgetTester tester, {int index = 0}) async {
  await tester.tap(find.byIcon(Icons.delete).at(index));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Delete'));
  // Deletion may remain pending, so do not wait for its progress animation.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('loading ends with an empty message when no weights exist', (
    tester,
  ) async {
    final pending = Completer<List<Map<String, dynamic>>>();
    await open(tester, () => pending.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('No weight entries yet.'), findsNothing);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No weight entries yet.'), findsOneWidget);
  });

  testWidgets('loaded entries display their weights and dates', (tester) async {
    await open(tester, () async => [first, second]);
    expect(find.text('170 lbs'), findsOneWidget);
    expect(find.text('169.5 lbs'), findsOneWidget);
    expect(find.text('November 9, 2026'), findsOneWidget);
    expect(find.text('November 10, 2026'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'a failed read shows an error and retry instead of loading or empty',
    (tester) async {
      await open(tester, () async => throw StateError('Read failed'));
      expect(
        find.text('Could not load weight logs. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('No weight entries yet.'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final hasEntries in [false, true]) {
    testWidgets(
      'retry recovers to ${hasEntries ? 'entries' : 'empty history'}',
      (tester) async {
        var loads = 0;
        await open(tester, () async {
          if (++loads == 1) throw StateError('Read failed');
          return hasEntries ? [first] : [];
        });
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(loads, 2);
        expect(find.text('Retry'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.text(hasEntries ? '170 lbs' : 'No weight entries yet.'),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets('reloading after adding a weight replaces the empty state', (
    tester,
  ) async {
    final key = GlobalKey<ViewWeightWidgetState>();
    var loads = 0;
    await open(tester, () async => ++loads == 1 ? [] : [first], key: key);
    expect(find.text('No weight entries yet.'), findsOneWidget);
    await key.currentState!.reloadForDate(DateTime(2026, 11, 9));
    await tester.pumpAndSettle();
    expect(find.text('170 lbs'), findsOneWidget);
    expect(find.text('No weight entries yet.'), findsNothing);
  });

  testWidgets(
    'deleting the final weight shows empty history only after success',
    (tester) async {
      final pending = Completer<void>();
      final deletedIds = <String>[];
      await open(
        tester,
        () async => const [first],
        delete: (id) {
          deletedIds.add(id);
          return pending.future;
        },
      );
      await confirmDeletion(tester);
      expect(deletedIds, ['2026-11-09']);
      expect(find.text('170 lbs'), findsOneWidget);
      expect(find.text('No weight entries yet.'), findsNothing);
      expect(
        tester.widget<IconButton>(find.byType(IconButton).last).onPressed,
        isNull,
      );
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('170 lbs'), findsNothing);
      expect(find.text('No weight entries yet.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );

  testWidgets(
    'a failed deletion preserves the entry and enables another attempt',
    (tester) async {
      await open(
        tester,
        () async => [first],
        delete: (_) async => throw StateError('Delete failed'),
      );
      await confirmDeletion(tester);
      await tester.pumpAndSettle();
      expect(find.text('170 lbs'), findsOneWidget);
      expect(
        find.text('Could not delete weight entry. Please try again.'),
        findsOneWidget,
      );
      expect(find.text('No weight entries yet.'), findsNothing);
      expect(find.byIcon(Icons.delete), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.delete))
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'canceling deletion leaves the entry and does not call the service',
    (tester) async {
      var deletes = 0;
      await open(
        tester,
        () async => [first],
        delete: (_) async {
          deletes++;
        },
      );
      await tester.tap(find.byIcon(Icons.delete));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(find.text('170 lbs'), findsOneWidget);
    },
  );

  testWidgets(
    'a reload that reorders entries does not change which weight is deleted',
    (tester) async {
      final key = GlobalKey<ViewWeightWidgetState>();
      final pending = Completer<void>();
      var loads = 0;
      await open(
        tester,
        () async => ++loads == 1 ? [first] : [second, first],
        key: key,
        delete: (id) {
          expect(id, '2026-11-09');
          return pending.future;
        },
      );
      await confirmDeletion(tester);
      await key.currentState!.reloadForDate(DateTime(2026, 11, 10));
      await tester.pump();
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('169.5 lbs'), findsOneWidget);
      expect(find.text('170 lbs'), findsNothing);
    },
  );

  testWidgets('an older read cannot replace a newer reload', (tester) async {
    final key = GlobalKey<ViewWeightWidgetState>();
    final older = Completer<List<Map<String, dynamic>>>();
    var loads = 0;
    await open(
      tester,
      () => ++loads == 1 ? older.future : Future.value([first]),
      key: key,
    );
    await key.currentState!.reloadForDate(DateTime(2026, 11, 9));
    await tester.pump();
    expect(find.text('170 lbs'), findsOneWidget);
    older.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('170 lbs'), findsOneWidget);
    expect(find.text('No weight entries yet.'), findsNothing);
  });

  for (final fail in [false, true]) {
    testWidgets(
      'a disposed widget ignores a read ${fail ? 'failure' : 'completion'}',
      (tester) async {
        final pending = Completer<List<Map<String, dynamic>>>();
        await open(tester, () => pending.future);
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        if (fail) {
          pending.completeError(StateError('Read failed'));
        } else {
          pending.complete([first]);
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'a disposed widget ignores a delete ${fail ? 'failure' : 'completion'}',
      (tester) async {
        final pending = Completer<void>();
        await open(tester, () async => [first], delete: (_) => pending.future);
        await confirmDeletion(tester);
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        if (fail) {
          pending.completeError(StateError('Delete failed'));
        } else {
          pending.complete();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
