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
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / _daysInMonth.length - 1).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / _daysInMonth.length - 1).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / _daysInMonth.length - 1).round();

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

    // Match Weekly: WHOOP first, then one summary fetch (no flicker)
    updateWhoopForMonth().then((_) {
      if (!mounted) return;
      setState(() {
        _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
      });
    });
  }

    void _kickoffMonthLoad() {
      // Fetch immediately → spinner once
      setState(() {
        _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
      });

      // Run WHOOP in background; don't reassign the future (avoids second load)
      updateWhoopForMonth().then((_) {
        if (!mounted) return;
        setState(() {}); // optional nudge; keeps content on screen
      });
    }

  Future<bool> updateWhoopCalsForDate(DateTime date, String uid) async {
    final snap = await FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('dailyLogs').doc(DateFormat('yyyy-MM-dd').format(date))
        .get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dayKey = DateTime(date.year, date.month, date.day);

    final isToday = dayKey.isAtSameMomentAs(today);
    final isYesterday = dayKey.isAtSameMomentAs(yesterday);

    final data = snap.data();
    if (data != null && (data['whoop_cals'] ?? 0) > 0 && !isToday && !isYesterday) {
      // Data already exists AND this is older than yesterday → skip
      print("WHOOP cals already present for $dayKey, skipping fetch.");
      return false;
    }

    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('fetchWhoopCalories');
      await callable.call({'start': start.toIso8601String(), 'end': end.toIso8601String(), 'userId': uid});
      return true; // wrote new data
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateWhoopForMonth() async {
    var wrote = false;
    for (final day in _daysInMonth) {
      final didWrite = await updateWhoopCalsForDate(day, uid);
      if (didWrite) wrote = true;
    }
    return wrote;
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
    });
    _kickoffMonthLoad();
  }

  // Navigate to previous month and reload data
  void goToPreviousMonth() {
    setState(() {
      _range = _range.previousMonth();
      _generateDaysInMonth();
    });
    _kickoffMonthLoad();
  }

  String formatTrimmedMonth(TimeRange r) {
    final today = DateTime.now();
    final monthStart = DateTime(r.start.year, r.start.month, 1);
    final monthEnd   = DateTime(r.end.year, r.end.month, r.end.day);

    // Trim to today if this is the current month
    final isCurrentMonth = r.start.month == today.month && r.start.year == today.year;
    final displayEnd = isCurrentMonth
        ? DateTime(today.year, today.month, today.day)
        : monthEnd;

    // If month is complete (past months), you can show a clean "August 2025"
    final isPastMonth = displayEnd.isBefore(today) && !isCurrentMonth;
    if (isPastMonth) {
      return DateFormat('MMMM yyyy').format(monthStart);
    }

    // Otherwise show a range like "Aug 1 – 22"
    final startFmt = DateFormat('MMM d').format(monthStart);
    final endFmt   = DateFormat('d').format(displayEnd);
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
                    formatTrimmedMonth(_range),
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
