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
  late TimeRange _range; 

  // keep all days if it's a past week; trim to today if it's the current week; (future weeks end up empty)
  List<DateTime> _daysForRange(TimeRange range) {
    final today = DateTime.now();
    final all = List.generate(7, (i) => range.start.add(Duration(days: i)));
    return all.where((d) => !d.isAfter(today)).toList();
  }

  // Calculations for weekly totals and averages
  int _avgDenomFor(TimeRange r) {
    final len = _daysForRange(r).length;
    print('len for $_range is $len');
    return len == 0 ? 1 : len;
  }
  int weeklyNetCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / _avgDenomFor(_range)).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / _avgDenomFor(_range)).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / _avgDenomFor(_range)).round();  

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

    for (final date in _daysForRange(dateRange)) {      
    final doc = firestore.collection('users').doc(userId)
      .collection('dailyLogs').doc(DateFormat('yyyy-MM-dd').format(date));
    final docSnap = await doc.get();
    if (!docSnap.exists) continue;
      final data = docSnap.data();
      if (data != null) {
        totalCalsIn += (data['calories_in'] ?? 0) as int;
        totalCarbs  += (data['carbs']       ?? 0) as int;
        totalFats   += (data['fat']         ?? 0) as int;
        totalProtein+= (data['protein']     ?? 0) as int;
        totalCalsOut+= (data['calories_out']?? 0) as int;
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayKey = DateTime(date.year, date.month, date.day);

    final isToday = dayKey.isAtSameMomentAs(today);
    final isYesterday = dayKey.isAtSameMomentAs(yesterday);

    if (data != null && (data['whoop_cals'] ?? 0) > 0 && !isToday && !isYesterday) {
      // Data exists and the day is not today or yesterday → skip fetching
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

  Future<void> updateWhoopForRange(TimeRange range) async {
    for (final day in _daysForRange(range)) {
      await updateWhoopCalsForDate(day, uid);
    }
  }

  @override
  void initState() {
    super.initState();
    _range = TimeRange.week(DateTime.now());
    // kick WHOOP updates, then fetch summary
    updateWhoopForRange(_range).then((_) {
      setState(() {
        _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
      });
    });
  }

  // Navigate to next week, updating the range and fetching new data
  void goToNextWeek() {
    setState(() {
      _range = _range.nextWeek();
      _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
    });
    updateWhoopForRange(_range).then((_) {
      if (mounted) setState(() {}); // optional nudge
    });
  }

  // Navigate to the previous week, update
  void goToPreviousWeek() {
    setState(() {
      _range = _range.previousWeek();
      _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
    });
    updateWhoopForRange(_range).then((_) {
      if (mounted) setState(() {});
    });
  }

  String formatTrimmedWeek(TimeRange r) {
    final today = DateTime.now();
    final start = r.start;
    final end = r.end;

    final isFutureWeek = start.isAfter(DateTime(today.year, today.month, today.day));
    final isCurrentWeek = !isFutureWeek && end.isAfter(today);

    final displayEnd = isCurrentWeek
        ? DateTime(today.year, today.month, today.day)  // trim only current week
        : end;                                          // full range for past/future

    final sameMonth = start.month == displayEnd.month && start.year == displayEnd.year;
    final startFmt = DateFormat('MMM d').format(start);
    final endFmt   = sameMonth ? DateFormat('d').format(displayEnd)
                              : DateFormat('MMM d').format(displayEnd);
    return '$startFmt – $endFmt';
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
                    formatTrimmedWeek(_range),
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
