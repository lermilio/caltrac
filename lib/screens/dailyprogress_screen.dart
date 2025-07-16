import 'package:caltrac/widgets/progress_widget.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyProgressScreen extends StatefulWidget{ 

  final int calsIn;
  final int calsOut;
  final int protien;

  const DailyProgressScreen({
    super.key, 
    required this.calsIn,
    required this.calsOut,
    required this.protien,
  });

  @override
  State<DailyProgressScreen> createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen> {

  int get netCals => widget.calsIn + widget.calsOut;
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = DateTime.now();
  }

  void goToNextDay() {
    setState(() {
      _currentDate = _currentDate.add(Duration(days: 1));
    });
  }

  void goToPreviousDay() {
    setState(() {
      _currentDate = _currentDate.subtract(Duration(days: 1));
    });
  }

  String get formattedDate {
    return DateFormat('MMM d').format(_currentDate); // e.g., "Jun 30"
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
              ProgressWidget(title: 'Calories In', data: widget.calsIn, unit: 'kcal'),
              ProgressWidget(title: 'Calories Out', data: widget.calsOut, unit: 'kcal'),
              ProgressWidget(title: 'Protien Total', data: widget.protien, unit: 'g'),
              ProgressWidget(title: 'Net Calories', data: netCals, unit: 'kcal'),
            ],
          ),
        ),
      ),
    );
  }
}