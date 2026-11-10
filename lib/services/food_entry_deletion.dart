// Build the update from a transaction's current snapshot, not the UI's totals.
Map<String, dynamic>? foodEntryDeletionUpdate(
  Map<String, dynamic> dailyLog,
  Map<String, dynamic> selectedMeal,
) {
  final meals = (dailyLog['meals'] as List? ?? [])
      .map((meal) => Map<String, dynamic>.from(meal as Map))
      .toList();
  final id = selectedMeal['id'];
  final index = meals.indexWhere((meal) {
    if (id != null) return meal['id'] == id;
    // Older entries have no ID. Remove one matching legacy entry only.
    return meal['id'] == null &&
        meal['input'] == selectedMeal['input'] &&
        [
          'calories',
          'protein',
          'carbs',
          'fat',
        ].every((key) => (meal[key] ?? 0) == (selectedMeal[key] ?? 0));
  });
  if (index == -1) return null; // Already deleted: do not decrement twice.

  final removed = meals.removeAt(index);
  int asInt(dynamic value) => value is num ? value.round() : 0;
  return {
    'meals': meals,
    'calories_in': asInt(dailyLog['calories_in']) - asInt(removed['calories']),
    for (final macro in ['protein', 'carbs', 'fat'])
      macro: asInt(dailyLog[macro]) - asInt(removed[macro]),
  };
}
