import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';


// DailyProgressScreen shows daily nutritional summary with navigation between days
class DailyProgressScreen extends StatefulWidget{ 
  const DailyProgressScreen({
    super.key, 
  });
  @override
  State<DailyProgressScreen> createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen> {

  int netCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  late DateTime _currentDate;
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';
  Future<Map<String, dynamic>>? _summaryFuture;  // Holds the result of fetching a single day’s nutrition data from Firestore.

  // Navigate to next day
  void goToNextDay() {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 1));
      updateWhoopCals(_currentDate);
      _summaryFuture = fetchDailySummary(uid, _currentDate);
    });
  }

  // Navigate to previous day
  void goToPreviousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(Duration(days: 1));
      updateWhoopCals(_currentDate);
      _summaryFuture = fetchDailySummary(uid, _currentDate);
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
    if (data != null && (data['whoop_cals'] ?? 0) > 0) {
      // Data already exists, skip fetching
      print("WHOOP cals already present for $date, skipping fetch.");
      return;
    }

    // Fetch from WHOOP as before
    final start = DateTime.utc(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    print("Sending WHOOP request:");
    print("start: $start");
    print("end: $end");

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('fetchWhoopCalories');
      final res = await callable.call({
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'userId': uid,
      });

      final data = Map<String, dynamic>.from(res.data as Map);
      final whoopCals = (data['whoop_cals'] ?? 0) as int;
      final caloriesOut = (data['calories_out'] ?? 0) as int;

      print("WHOOP cals updated: whoop=$whoopCals, out=$caloriesOut");
    } catch (e) {
      print("Error fetching WHOOP cals: $e");
    }
  }

  // Initialize state and fetch initial data
   @override
  void initState() {
    _currentDate = DateTime.now();
    super.initState();
    updateWhoopCals(_currentDate).then((_) {
      _summaryFuture = fetchDailySummary(uid, _currentDate);
      setState(() {});
    });
  }

  // Fetch daily summary data from Firestore
  Future<Map<String, dynamic>> fetchDailySummary(String userId, DateTime date) async {
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
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.black
                    )
                  ),
                  SizedBox( width: 10,),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox( width: 10,),
                  FloatingActionButton.small(
                    onPressed: goToNextDay,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.black
                    )
                  ),
                ],
              ),
              SizedBox(height: 24),
              // 
              FutureBuilder<Map<String, dynamic>>(
                future: _summaryFuture,
                builder: (context, snapshot) {

                  // Handle loading, error, and data states
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

                  
                  // Extract data from snapshot
                  final data = snapshot.data!;
                  final netCals = (data['calories_in'] ?? 0) - (data['calories_out'] ?? 0);

                  final allZero = data.values.every((v) => v == 0);
                  if (allZero) {
                    return const Text('No data available for this day.');
                  }

                  // Build the progress widgets with the fetched data
                  return Column(
                    children: [
                      ProgressWidget(title: 'Calories In', data: data['calories_in'] ?? 0, unit: 'kcal'),
                      ProgressWidget(title: 'Calories Out', data: data['calories_out'] ?? 0, unit: 'kcal'),
                      ProgressWidget(title: 'Net Calories', data: netCals, unit: 'kcal'),
                      ProgressWidget(title: 'Protein', data: data['protein'] ?? 0, unit: 'g'),
                      ProgressWidget(title: 'Carbs', data: data['carbs'] ?? 0, unit: 'g'),
                      ProgressWidget(title: 'Fats', data: data['fat'] ?? 0, unit: 'g'),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      )
    );
  }
}