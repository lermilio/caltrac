import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewEntriesWidget extends StatefulWidget {
  const ViewEntriesWidget({super.key});

  @override
  State<ViewEntriesWidget> createState() => _ViewEntriesWidgetState();
}

class _ViewEntriesWidgetState extends State<ViewEntriesWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _meals = [];

  @override
  void initState() {
    super.initState();
    _fetchMealsForDate(_selectedDay);
  }

  Future<void> _fetchMealsForDate(DateTime date) async {
    final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Update if app has other users

    final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateKey);

    final doc = await docRef.get();

    if (doc.exists) {
      final data = doc.data();
      final meals = data?['meals'] as List<dynamic>? ?? [];

      setState(() {
        _meals = meals.cast<Map<String, dynamic>>();
      });
    } else {
      setState(() {
        _meals = [];
      });
    }
  }

  Future<void> _deleteMealFromFirebase(Map<String, dynamic> mealToDelete) async {

    final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Update if app has other users
    final dateKey = "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateKey);

    final doc = await docRef.get();

    if (!doc.exists) return;

    final meals = List<Map<String, dynamic>>.from(doc['meals'] ?? []);

    meals.removeWhere((meal) =>
      meal['input'] == mealToDelete['input'] &&
      meal['calories'] == mealToDelete['calories'] &&
      meal['protein'] == mealToDelete['protein'] &&
      meal['carbs'] == mealToDelete['carbs'] &&
      meal['fat'] == mealToDelete['fat']
    );

    await docRef.update({'meals': meals});

    setState(() {
      _meals = meals;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry deleted')),
    );
}

  void _confirmDeleteMeal(Map<String, dynamic> meal) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete "${meal['input']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              _deleteMealFromFirebase(meal);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  CalendarFormat _calendarFormat = CalendarFormat.week;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('View Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat, 
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _fetchMealsForDate(selected);
            },
          ),
          const SizedBox(height: 12),
          if (_meals.isEmpty)
            const Text("No meals logged for this date."),
          ..._meals.map((meal) => Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  title: Text(meal['input'] ?? 'Unknown Item'),
                  subtitle: Text(
                    'Calories: ${meal['calories']}, Protein: ${meal['protein']}g, Fat: ${meal['fat']}g, Carbs: ${meal['carbs']}g',
                  ),
                  trailing: IconButton(
                    onPressed: () => _confirmDeleteMeal(meal), 
                    icon: const Icon(Icons.delete, color: Colors.red),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
