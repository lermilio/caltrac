import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Widget for viewing and deleting logged meal entries by date
class ViewEntriesWidget extends StatefulWidget {
  const ViewEntriesWidget({super.key});

  @override
  State<ViewEntriesWidget> createState() => ViewEntriesWidgetState();
}

class ViewEntriesWidgetState extends State<ViewEntriesWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  List<Map<String, dynamic>> _meals = [];
  int? _extraCals;
  CalendarFormat _calendarFormat = CalendarFormat.week; // Default to week view
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';

  Future<void> reloadForDate(DateTime date) async {
    setState(() {
      _selectedDay = date;
      _focusedDay = date;
    });
    await _fetchMealsForDate(date);
    await _fetchCalsForDate(date);
  }

  @override
  void initState() {
    super.initState();
    _fetchMealsForDate(_selectedDay);
    _fetchCalsForDate(_selectedDay);
  }

   // Fetches extraCals from Firestore for the given date
  Future<void> _fetchCalsForDate(DateTime date) async {
    final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateKey);

    final doc = await docRef.get();

    if (doc.exists) {
      final num? ec = doc.data()?['extra_cals'] as num?;
      setState(() => _extraCals = ec?.toInt());
    } else {
      setState(() => _extraCals = 0);
    }
  }

  // Fetches meals from Firestore for the given date
  Future<void> _fetchMealsForDate(DateTime date) async {
    final dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('dailyLogs')
        .doc(dateKey);

    final doc = await docRef.get();

    if (doc.exists) {
      final meals = (doc.data()?['meals'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      setState(() => _meals = meals);
    } else {
      setState(() => _meals = []);
    }
  }

  int _asInt(dynamic v) => v is int ? v : (v is num ? v.round() : 0);

  Future<void> _deleteMealFromFirebase(Map<String, dynamic> mealToDelete) async {
    final dateKey =
        "${_selectedDay.year}-${_selectedDay.month.toString().padLeft(2, '0')}-${_selectedDay.day.toString().padLeft(2, '0')}";

    final docRef = FirebaseFirestore.instance
        .collection('users').doc(uid)
        .collection('dailyLogs').doc(dateKey);

    final snap = await docRef.get();
    if (!snap.exists) return;

    final meals = List<Map<String, dynamic>>.from(
      (snap.data()?['meals'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map)),
    );

    // Your existing matcher
    meals.removeWhere((meal) =>
        meal['input']   == mealToDelete['input']   &&
        (meal['calories'] ?? 0) == (mealToDelete['calories'] ?? 0) &&
        (meal['protein']  ?? 0) == (mealToDelete['protein']  ?? 0) &&
        (meal['carbs']    ?? 0) == (mealToDelete['carbs']    ?? 0) &&
        (meal['fat']      ?? 0) == (mealToDelete['fat']      ?? 0));

    // Update the array AND decrement the rollups in ONE write
    await docRef.update({
      'meals': meals,
      'calories_in': FieldValue.increment(-_asInt(mealToDelete['calories'])),
      'carbs':       FieldValue.increment(-_asInt(mealToDelete['carbs'])),
      'fat':         FieldValue.increment(-_asInt(mealToDelete['fat'])),
      'protein':     FieldValue.increment(-_asInt(mealToDelete['protein'])),
    });

    setState(() => _meals = meals);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry deleted')),
    );
  }

  // Shows confirmation dialog before deleting a meal
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
              Navigator.of(context).pop(); // Close dialog
              _deleteMealFromFirebase(meal);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('View Entries', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // Calendar for selecting date
          TableCalendar(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            onFormatChanged: (format) => setState(() => _calendarFormat = format),
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
              _fetchMealsForDate(selected);
              _fetchCalsForDate(selected);
            },
          ),

          const SizedBox(height: 12),

          // Show meals or placeholder text
          if (_meals.isEmpty && (_extraCals == null || _extraCals == 0))
            const Text("No entries logged for this date."),

          // Render meal cards
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
          
          // Render extra calorie cards
          if (_extraCals != null && _extraCals != 0)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                title: const Text('Extra Calories'),
                subtitle: Text('$_extraCals kcal'),
              ),
            ),
        ],
      ),
    );
  }
}
