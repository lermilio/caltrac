import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Logs a nutrition or calorie entry to Firestore via a Firebase Function.
Future<void> logEntryToFirebase({
  required String userId,
  required DateTime date,
  required Map entryData,
}) async {
  final String dateStr =
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('addEntryLog');

  try {
    await callable.call({
      'userId': userId,
      'dateString': dateStr,
      'entryData': entryData,
    });
    print('Entry logged!');
  } catch (e) {
    print('Error: $e');
  }
}

// Adds or updates extra calories burned for a given date.
Future<void> logCalsOutToFirebase({
  required String userId,
  required DateTime date,
  required int extraCals,
}) async {
  final dateKey = date.toIso8601String().split('T').first;
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('dailyLogs')
      .doc(dateKey);

  final snapshot = await docRef.get();

  // If the doc doesn't exist yet, initialize with base structure
  if (!snapshot.exists) {
    await docRef.set({
      'whoop_cals': 0,
      'extra_cals': extraCals,
      'calories_out': extraCals,
      'calories_in': 0,
      'net_calories': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'meals': [],
      'date': dateKey,
    });
    return;
  }

  // Merge in updated calories-out values
  final existing = snapshot.data() ?? {};
  final int whoopCalories = existing['whoop_cals'] ?? 0;
  final int totalCaloriesOut = whoopCalories + extraCals;

  await docRef.set({
    'extra_cals': extraCals,
    'calories_out': totalCaloriesOut,
  }, SetOptions(merge: true));
}

// Logs a weight entry to Firestore via a Firebase Function.
Future<void> logWeightToFirebase({
  required String userId,
  required DateTime date,
  required double weight,
}) async {
  final String dateStr =
      "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('addWeightLog');

  await callable.call({
    'userId': userId,
    'dateString': dateStr,
    'weight': weight,
  });
}
