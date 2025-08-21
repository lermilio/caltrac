import 'package:caltrac/services/date_manager.dart';
import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

class WeeklyProgressScreen extends StatefulWidget {
  const WeeklyProgressScreen({super.key});

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {
  late TimeRange _range; // Current week range
  late List<DateTime> _daysInWeek; // Days in current week up to today

  // Calculations for weekly totals and averages
  int weeklyNetCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / _daysInWeek.length).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / _daysInWeek.length).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / _daysInWeek.length).round();  

  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; 
  Future<Map<String, dynamic>>? _weeklySummaryFuture; // Weekly summary data

  // Fetch and sum up daily log data from Firestore
  Future<Map<String, dynamic>> fetchWeeklySummary(String userId, TimeRange dateRange) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int totalCalsIn = 0;
    int totalCalsOut = 0;
    int totalFats = 0;
    int totalProtein = 0;
    int totalCarbs = 0;

    for (int i = 0; i < _daysInWeek.length; i++) {
      final DateTime date = dateRange.start.add(Duration(days: i));

      final doc = firestore
          .collection('users')
          .doc(userId)
          .collection('dailyLogs')
          .doc(DateFormat('yyyy-MM-dd').format(date));

      final docSnap = await doc.get();
      if (!docSnap.exists) continue; // Skip if no data for the day

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

  Future<void> updateWhoopCalsForDate(DateTime date, String uid) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(DateFormat('yyyy-MM-dd').format(date))
        .get();

    final data = doc.data();
    if (data != null && (data['whoop_cals'] ?? 0) > 0) {
      // Data already exists, skip fetching
      print("WHOOP cals already present for $date, skipping fetch.");
      return;
    }

    // Otherwise, fetch from WHOOP
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
      print("Error fetching WHOOP cals for $date: $e");
    }
  }

  Future<void> updateWhoopForWeek() async {
    for (final day in _daysInWeek) {
      await updateWhoopCalsForDate(day, uid);
    }
  }

  @override
  void initState() {
    _range = TimeRange.week(DateTime.now());
    _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
        .where((day) => !day.isAfter(DateTime.now()))
        .toList();
    updateWhoopForWeek().then((_) {
      _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
      setState(() {});
    });
  }

  // Navigate to next week and refresh data
  void goToNextWeek() {
    setState(() {
      _range = _range.nextWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
      updateWhoopForWeek().then((_) {
        _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
        setState(() {});
      });
    });
  }

  // Navigate to previous week and refresh data
  void goToPreviousWeek() {
    setState(() {
      _range = _range.previousWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
      updateWhoopForWeek().then((_) {
        _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
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
              // Week navigation row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    onPressed: goToPreviousWeek,
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
                    onPressed: goToNextWeek,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.arrow_forward, color: Colors.black),
                  ),
                ],
              ),

              // Load and display weekly summary
              FutureBuilder<Map<String, dynamic>>(
                future: _weeklySummaryFuture,
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
                    return const Text('No data available for this week.');
                  }

                  return Column(
                    children: [
                      ProgressWidget(title: 'Week Caloric Net', data: weeklyNetCalories(data), unit: 'kcal'),
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
