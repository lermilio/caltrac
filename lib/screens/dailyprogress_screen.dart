import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Future<Map<String, dynamic>>? _summaryFuture;

  void goToNextDay() {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 1));
      _summaryFuture = fetchDailySummary(uid, _currentDate);
    });
  }

  void goToPreviousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(Duration(days: 1));
      _summaryFuture = fetchDailySummary(uid, _currentDate);
    });
  }

  String get formattedDate {
    return DateFormat('MMM d').format(_currentDate);
  }

   @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
    _summaryFuture = fetchDailySummary(uid, _currentDate);
  }

  Future<Map<String, dynamic>> fetchDailySummary(String userId, DateTime date) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;

    final doc = await firestore
      .collection('users')
      .doc(userId)
      .collection('dailyLogs')
      .doc(DateFormat('yyyy-MM-dd').format(date))
      .get();

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
              FutureBuilder<Map<String, dynamic>>(
                future: _summaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  final data = snapshot.data!;
                  final netCals = (data['calories_in'] ?? 0) - (data['calories_out'] ?? 0);

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