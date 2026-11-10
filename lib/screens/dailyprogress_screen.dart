import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:caltrac/widgets/refreshing_summary.dart';

// DailyProgressScreen shows daily nutritional summary with navigation between days
class DailyProgressScreen extends StatefulWidget {
  const DailyProgressScreen({
    super.key,
    this.initialDate,
    this.loadSummary,
    this.refreshWhoop,
  });
  final DateTime? initialDate;
  final Future<Map<String, dynamic>> Function(DateTime)? loadSummary;
  final Future<void> Function(DateTime)? refreshWhoop;
  @override
  State<DailyProgressScreen> createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen> {
  int netCalories(Map<String, dynamic> data) =>
      data['calories_in'] - data['calories_out'];
  late DateTime _currentDate;
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';

  // Navigate to next day
  void goToNextDay() {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 1));
    });
  }

  // Navigate to previous day
  void goToPreviousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(Duration(days: 1));
    });
  }

  String get formattedDate {
    return DateFormat('MMM d').format(_currentDate);
  }

  // Fetch WHOOP calories via Firebase Function and update Firestore
  Future<void> updateWhoopCals(DateTime date) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(DateFormat('yyyy-MM-dd').format(date))
        .get();

    final data = doc.data();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayKey = DateTime(date.year, date.month, date.day);

    final isToday = DateUtils.isSameDay(date, DateTime.now());
    final isYesterday = dayKey.isAtSameMomentAs(yesterday);

    if (data != null &&
        (data['whoop_cals'] ?? 0) > 0 &&
        !isToday &&
        !isYesterday) {
      // Data exists and the day is NOT today or yesterday (in case we log on after midnight),
      // so skip fetching
      return;
    }

    // Fetch from WHOOP
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final callable = FirebaseFunctions.instance.httpsCallable(
      'fetchWhoopCalories',
    );
    await callable.call({
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'userId': uid,
    });
  }

  @override
  void initState() {
    super.initState();
    _currentDate = widget.initialDate ?? DateTime.now();
  }

  // Fetch daily summary data from Firestore
  Future<Map<String, dynamic>> fetchDailySummary(
    String userId,
    DateTime date,
  ) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final doc = await firestore
        .collection('users')
        .doc(userId)
        .collection('dailyLogs')
        .doc(DateFormat('yyyy-MM-dd').format(date))
        .get();

    // Return default values if no document exists
    if (!doc.exists) {
      return {
        'calories_in': 0,
        'calories_out': 0,
        'protein': 0,
        'carbs': 0,
        'fat': 0,
      };
    }

    final data = doc.data()!;

    return {
      'calories_in': data['calories_in'] ?? 0,
      'calories_out': data['calories_out'] ?? 0,
      'protein': data['protein'] ?? 0,
      'carbs': data['carbs'] ?? 0,
      'fat': data['fat'] ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final date = _currentDate;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    onPressed: goToPreviousDay,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  SizedBox(width: 10),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
                  ),
                  SizedBox(width: 10),
                  FloatingActionButton.small(
                    onPressed: goToNextDay,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.arrow_forward, color: Colors.black),
                  ),
                ],
              ),
              SizedBox(height: 24),
              //
              RefreshingSummary(
                period: date,
                loadSummary: () =>
                    widget.loadSummary?.call(date) ??
                    fetchDailySummary(uid, date),
                refreshWhoop: () =>
                    widget.refreshWhoop?.call(date) ?? updateWhoopCals(date),
                builder: (data) {
                  final netCals =
                      (data['calories_in'] ?? 0) - (data['calories_out'] ?? 0);

                  final allZero = data.values.every((v) => v == 0);
                  if (allZero) {
                    return const Text('No data available for this day.');
                  }

                  // Build the progress widgets with the fetched data
                  return Column(
                    children: [
                      ProgressWidget(
                        title: 'Calories In',
                        data: data['calories_in'] ?? 0,
                        unit: 'kcal',
                      ),
                      ProgressWidget(
                        title: 'Calories Out',
                        data: data['calories_out'] ?? 0,
                        unit: 'kcal',
                      ),
                      ProgressWidget(
                        title: 'Net Calories',
                        data: netCals,
                        unit: 'kcal',
                      ),
                      ProgressWidget(
                        title: 'Protein',
                        data: data['protein'] ?? 0,
                        unit: 'g',
                      ),
                      ProgressWidget(
                        title: 'Carbs',
                        data: data['carbs'] ?? 0,
                        unit: 'g',
                      ),
                      ProgressWidget(
                        title: 'Fats',
                        data: data['fat'] ?? 0,
                        unit: 'g',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
