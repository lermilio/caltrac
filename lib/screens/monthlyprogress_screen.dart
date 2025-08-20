import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/services/date_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class MonthlyProgressScreen extends StatefulWidget {
  const MonthlyProgressScreen({super.key});
  @override
  State<MonthlyProgressScreen> createState() => _MonthlyProgressScreenState();
}

class _MonthlyProgressScreenState extends State<MonthlyProgressScreen> {
  late TimeRange _range; // Current month date range
  late List<DateTime> _daysInMonth; // All days in the current month up to today
  Future<Map<String, dynamic>>? _monthlySummaryFuture; // Holds monthly summary data
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; 

  // Calculating summaries for the month.
  int monthlyNetCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / _daysInMonth.length).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / _daysInMonth.length).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / _daysInMonth.length).round();

  // Fetches and aggregates daily data for the entire month from Firestore.
  Future<Map<String, dynamic>> fetchMonthlySummary(String userId, TimeRange dateRange, List<DateTime> days) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int totalCalsIn = 0;
    int totalCalsOut = 0;
    int totalFats = 0;
    int totalProtein = 0;
    int totalCarbs = 0;

    // Loop over each day in the month to get totals.
    for (int i = 0; i < days.length; i++) {
      final DateTime date = dateRange.start.add(Duration(days: i));

      final doc = firestore
          .collection('users')
          .doc(userId)
          .collection('dailyLogs')
          .doc(DateFormat('yyyy-MM-dd').format(date));

      final docSnap = await doc.get();
      if (!docSnap.exists) continue; // Skip days with no data

      final data = docSnap.data();
      if (data != null) {
        totalCalsIn += (data['calories_in'] ?? 0) as int;
        totalCarbs += (data['carbs'] ?? 0) as int;
        totalFats += (data['fat'] ?? 0) as int;
        totalProtein += (data['protein'] ?? 0) as int;
        totalCalsOut += (data['calories_out'] ?? 0) as int;
      }
    }

    return {
      'calories_in': totalCalsIn,
      'calories_out': totalCalsOut,
      'protein': totalProtein,
      'carbs': totalCarbs,
      'fat': totalFats,
    };
  }

  @override
  void initState() {
    super.initState();
    _range = TimeRange.month(DateTime.now());
    _generateDaysInMonth();
    updateWhoopForMonth().then((_) {
      _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
      setState(() {});
    });
  }

  Future<void> updateWhoopCalsForDate(DateTime date, String uid) async {
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('fetchWhoopCalories');
      await callable.call({
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'userId': uid,
      });
    } catch (e) {
      print("❌ Error fetching WHOOP cals for $date: $e");
    }
  }

  Future<void> updateWhoopForMonth() async {
    for (final day in _daysInMonth) {
      await updateWhoopCalsForDate(day, uid);
    }
  }

  // Builds list of DateTime objects for each day in month up to today
  void _generateDaysInMonth() {
    _daysInMonth = List.generate(
      _range.end.difference(_range.start).inDays + 1,
      (i) => _range.start.add(Duration(days: i)),
    ).where((day) => !day.isAfter(DateTime.now())).toList();
  }

  // Navigate to next month and reload data
  void goToNextMonth() {
    setState(() {
      _range = _range.nextMonth();
      _generateDaysInMonth();
      updateWhoopForMonth().then((_) {
        _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
        setState(() {});
      });
    });
  }

  // Navigate to previous month and reload data
  void goToPreviousMonth() {
    setState(() {
      _range = _range.previousMonth();
      _generateDaysInMonth();
      updateWhoopForMonth().then((_) {
        _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
        setState(() {});
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // Month navigation row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    onPressed: goToPreviousMonth,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_back, color: Colors.black),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _range.formatRange(),
                    style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 10),
                  FloatingActionButton.small(
                    onPressed: goToNextMonth,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_forward, color: Colors.black),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Data loader + display
              FutureBuilder<Map<String, dynamic>>(
                future: _monthlySummaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData || snapshot.data == null) {
                    // Still waiting for data to be written to Firestore, show loading
                    return const CircularProgressIndicator();
                  }

                  // Optionally, check if all values are zero and then show "No data" message
                  final data = snapshot.data!;
                  final allZero = data.values.every((v) => v == 0);
                  if (allZero) {
                    return const Text('No data available for this month.');
                  }

                  return Column(
                    children: [
                      ProgressWidget(title: 'Monthly Caloric Net', data: monthlyNetCalories(data), unit: 'kcal'),
                      ProgressWidget(title: 'Average Daily Protein', data: avgDailyProtein(data), unit: 'kcal'),
                      ProgressWidget(title: 'Average Daily Carbs', data: avgDailyCarbs(data), unit: 'kcal'),
                      ProgressWidget(title: 'Average Daily Fats', data: avgDailyFats(data), unit: 'g'),
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
