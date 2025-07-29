import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/date_manager.dart';

class MonthlyProgressScreen extends StatefulWidget{

  final int calsIn;
  final int calsOut;
  final int protein;
  final int fats;
  final int carbs;

  const MonthlyProgressScreen({
    super.key, 
    required this.calsIn,
    required this.calsOut,
    required this.protein,
    required this.fats,
    required this.carbs,
  });

  @override
  State<MonthlyProgressScreen> createState() => _MonthlyProgressScreenState();
}

class _MonthlyProgressScreenState extends State<MonthlyProgressScreen> {

  int get netCals => widget.calsIn + widget.calsOut;

  late TimeRange _range;
  late List<DateTime> _daysInMonth;

  @override
  void initState() {
    super.initState();
    _range = TimeRange.month(DateTime.now());
    _generateDaysInMonth();
  }

  void _generateDaysInMonth() {
    _daysInMonth = List.generate(
      _range.end.difference(_range.start).inDays + 1,
      (i) => _range.start.add(Duration(days: i)),
    ).where((day) => !day.isAfter(DateTime.now())).toList();
  }

  double get avgProtein => widget.protein / _daysInMonth.length; // Make sure this is correct
  double get avgCarbs => widget.carbs / _daysInMonth.length;
  double get avgFats => widget.fats / _daysInMonth.length;

  void goToNextMonth() {
    setState(() {
      _range = _range.nextMonth();
      _generateDaysInMonth();
    });
  }

  void goToPreviousMonth() {
    setState(() {
      _range = _range.previousMonth();
      _generateDaysInMonth();
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
              ProgressWidget(title: 'Monthly Caloric Net', data: netCals, unit: 'kcal'),
              ProgressWidget(title: 'Average Daily Protein', data: avgProtein.toInt(), unit: 'g'),
              ProgressWidget(title: 'Average Daily Carbs', data: avgCarbs.toInt(), unit: 'g'),
              ProgressWidget(title: 'Average Daily Fats', data: avgFats.toInt(), unit: 'g'),

            ],
          ),
        ),
      ),
    );
  }
}