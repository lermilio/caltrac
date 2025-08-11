import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/services/date_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MonthlyProgressScreen extends StatefulWidget{

  const MonthlyProgressScreen({
    super.key, 
  });

  @override
  State<MonthlyProgressScreen> createState() => _MonthlyProgressScreenState();
}

class _MonthlyProgressScreenState extends State<MonthlyProgressScreen> {

  late TimeRange _range;
  late List<DateTime> _daysInMonth;
  Future<Map<String, dynamic>>? _monthlySummaryFuture;
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';

  int monthlyNetCalories(Map<String, dynamic> data) => data['calories_in'] - data['calories_out'];  
  int avgDailyProtein(Map<String, dynamic> data) => ((data['protein'] ?? 0) / _daysInMonth.length).round();    
  int avgDailyCarbs(Map<String, dynamic> data) => ((data['carbs'] ?? 0) / _daysInMonth.length).round();  
  int avgDailyFats(Map<String, dynamic> data) => ((data['fat'] ?? 0) / _daysInMonth.length).round();

  Future<Map<String, dynamic>> fetchMonthlySummary(String userId, TimeRange dateRange, List<DateTime> days) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    int weeklyCalsIn = 0;
    int weeklyCalsOut = 0;
    int weeklyFats = 0;
    int weeklyProtein = 0;
    int weeklyCarbs = 0;

    for (int i = 0; i < days.length; i++){
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
    super.initState();
    _range = TimeRange.month(DateTime.now());
    _generateDaysInMonth();
    _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);

  }

  void _generateDaysInMonth() {
    _daysInMonth = List.generate(
      _range.end.difference(_range.start).inDays + 1,
      (i) => _range.start.add(Duration(days: i)),
    ).where((day) => !day.isAfter(DateTime.now())).toList();
  }

  void goToNextMonth() {
    setState(() {
      _range = _range.nextMonth();
      _generateDaysInMonth();
      _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
    });
  }

  void goToPreviousMonth() {
    setState(() {
      _range = _range.previousMonth();
      _generateDaysInMonth();
      _monthlySummaryFuture = fetchMonthlySummary(uid, _range, _daysInMonth);
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
                    onPressed: goToPreviousMonth,
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
                    onPressed: goToNextMonth,
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
                future: _monthlySummaryFuture,
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
                      ProgressWidget(title: 'Monthly Caloric Net', data: monthlyNetCalories(data), unit: 'kcal'),
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