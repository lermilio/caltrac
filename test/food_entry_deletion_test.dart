import 'package:caltrac/services/food_entry_deletion.dart';
import 'package:flutter_test/flutter_test.dart';

const meal = {
  'input': 'Chicken breast',
  'calories': 200,
  'protein': 30,
  'carbs': 5,
  'fat': 7,
};

Map<String, dynamic> dailyLog(List<Map<String, dynamic>> meals) => {
  'meals': meals,
  'calories_in': 200 * meals.length,
  'protein': 30 * meals.length,
  'carbs': 5 * meals.length,
  'fat': 7 * meals.length,
  'calories_out': 2000,
};

void main() {
  test(
    'deleting one of two identical meals removes only its ID and nutrition',
    () {
      final first = {...meal, 'id': 'first'};
      final second = {...meal, 'id': 'second'};
      final original = dailyLog([first, second]);
      final update = foodEntryDeletionUpdate(original, first)!;
      expect(update, {
        'meals': [second],
        'calories_in': 200,
        'protein': 30,
        'carbs': 5,
        'fat': 7,
      });
      expect(original['meals'], [first, second]); // No snapshot mutation.
      expect({...original, ...update}['calories_out'], 2000);
    },
  );

  test('a repeated deletion does not decrement totals twice', () {
    final selected = {...meal, 'id': 'first'};
    final original = dailyLog([selected]);
    final update = foodEntryDeletionUpdate(original, selected)!;
    expect(update['calories_in'], 0);
    expect(foodEntryDeletionUpdate({...original, ...update}, selected), isNull);
  });

  test('legacy deletion removes just one matching entry without an ID', () {
    final update = foodEntryDeletionUpdate(dailyLog([meal, meal]), meal)!;
    expect(update['meals'], [meal]);
    expect(update['calories_in'], 200);
  });

  test('legacy matching does not remove an identical entry that has an ID', () {
    final modern = {...meal, 'id': 'modern'};
    expect(foodEntryDeletionUpdate(dailyLog([modern]), meal), isNull);
    final update = foodEntryDeletionUpdate(dailyLog([modern, meal]), meal)!;
    expect(update['meals'], [modern]);
    expect(update['calories_in'], 200);
  });

  test('an absent ID does not fall back to deleting identical food', () {
    final stored = {...meal, 'id': 'stored'};
    expect(
      foodEntryDeletionUpdate(dailyLog([stored]), {...meal, 'id': 'different'}),
      isNull,
    );
  });

  test('deletion subtracts stored nutrition rather than a stale UI value', () {
    final stored = {...meal, 'id': 'first'};
    final stale = {...stored, 'calories': 500};
    final update = foodEntryDeletionUpdate(dailyLog([stored]), stale)!;
    expect(update['calories_in'], 0);
  });

  test('a meal added since the UI loaded survives deletion', () {
    final selected = {...meal, 'id': 'selected'};
    final concurrent = {...meal, 'id': 'concurrent'};
    final update = foodEntryDeletionUpdate(
      dailyLog([selected, concurrent]),
      selected,
    )!;
    expect(update['meals'], [concurrent]);
    expect(update['calories_in'], 200);
  });

  test('empty meals produce no deletion update', () {
    expect(foodEntryDeletionUpdate({}, meal), isNull);
  });
}
