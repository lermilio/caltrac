import 'package:cloud_functions/cloud_functions.dart';

Future<void> logEntryToFirebase({
  required String userId,
  required DateTime date,
  required Map entryData,
}) async {
  final String dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

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

Future<void> logWeightToFirebase({
  required String userId,
  required DateTime date,
  required double weight,
}) async {
  final String dateStr = "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('addWeightLog');

  await callable.call({
    'userId': userId,
    'dateString': dateStr,
    'weight': weight,
  });
}