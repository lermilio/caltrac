import 'package:caltrac/date_manager.dart';
import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WeeklyProgressScreen extends StatefulWidget{

  const WeeklyProgressScreen({
    super.key, 
  });

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {

  int weeklyNetCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / 7).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / 7).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / 7).round();  

  late TimeRange _range;
  late List<DateTime> _daysInWeek;

  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';
  Future<Map<String, dynamic>>? _weeklySummaryFuture;

  Future<Map<String, dynamic>> fetchWeeklySummary(String userId, TimeRange dateRange) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int weeklyCalsIn = 0;
    int weeklyCalsOut = 0;
    int weeklyFats = 0;
    int weeklyProtein = 0;
    int weeklyCarbs = 0;

    for (int i = 0; i < 7; i++){
      final DateTime date = dateRange.start.add(Duration(days: i));

      final doc = firestore
        .collection('users')
        .doc(userId)
        .collection('dailyLogs')
        .doc(DateFormat('yyyy-MM-dd').format(date));

      final docSnap = await doc.get();

      if (!docSnap.exists) {
        continue;
      }

      final data = docSnap.data();
      if (data != null) {
        weeklyCalsIn += (data['calories_in'] ?? 0) as int;
        weeklyCarbs += (data['carbs'] ?? 0) as int;
        weeklyFats += (data['fat'] ?? 0) as int;
        weeklyProtein += (data['protein'] ?? 0) as int;
        weeklyCalsOut += (data['calories_out'] ?? 0) as int;
      }
    }

    return {
      'calories_in': weeklyCalsIn,
      'calories_out': weeklyCalsOut,
      'protein': weeklyProtein,
      'carbs': weeklyCarbs,
      'fat': weeklyFats,
    };
  }

  @override
  void initState() {
    _range = TimeRange.week(DateTime.now());
    _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
        .where((day) => !day.isAfter(DateTime.now()))
        .toList();
    _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
  }


  void goToNextWeek() {
    setState(() {
      _range = _range.nextWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
      _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
    });
  }

  void goToPreviousWeek() {
    setState(() {
      _range = _range.previousWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
      _weeklySummaryFuture = fetchWeeklySummary(uid, _range);
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
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton.small(
                    onPressed: goToPreviousWeek,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.black
                    )
                  ),
                  SizedBox( width: 10,),
                  Text(
                    _range.formatRange(),
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox( width: 10,),
                  FloatingActionButton.small(
                    onPressed: goToNextWeek,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.arrow_forward,
                      color: Colors.black
                    )
                  ),
                ],
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: _weeklySummaryFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }

                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  final data = snapshot.data!;

                  return Column(
                    children: [
                      ProgressWidget(title: 'Week Caloric Net', data: weeklyNetCalories(data), unit: 'kcal'),
                      ProgressWidget(title: 'Average Daily Protien', data: avgDailyProtein(data), unit: 'kcal'),
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