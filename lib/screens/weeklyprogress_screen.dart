import 'package:caltrac/date_manager.dart';
import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';


class WeeklyProgressScreen extends StatefulWidget{

  final int calsIn;
  final int calsOut;
  final int protein;
  final int fats;
  final int carbs;

  const WeeklyProgressScreen({
    super.key, 
    required this.calsIn,
    required this.calsOut,
    required this.protein,
    required this.fats,
    required this.carbs,
  });

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {

  int get netCals => widget.calsIn + widget.calsOut;
  double get avgProtein => widget.protein / 7;
  double get avgCarbs => widget.carbs / 7;
  double get avgFats => widget.fats / 7;
  late TimeRange _range;
  late List<DateTime> _daysInWeek;

  @override
  void initState() {
    _range = TimeRange.week(DateTime.now());
    _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
        .where((day) => !day.isAfter(DateTime.now()))
        .toList();
  }

  void goToNextWeek() {
    setState(() {
      _range = _range.nextWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
    });
  }

  void goToPreviousWeek() {
    setState(() {
      _range = _range.previousWeek();
      _daysInWeek = List.generate(7, (i) => _range.start.add(Duration(days: i)))
          .where((day) => !day.isAfter(DateTime.now()))
          .toList();
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
              SizedBox(height: 24),
              ProgressWidget(title: 'Week Caloric Net', data: netCals, unit: 'kcal'),
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