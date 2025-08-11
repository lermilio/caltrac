import 'package:flutter/material.dart';
import 'package:caltrac/screens/dailyprogress_screen.dart';
import 'package:caltrac/screens/weeklyprogress_screen.dart';
import 'package:caltrac/screens/monthlyprogress_screen.dart';
import 'package:caltrac/screens/log_screen.dart';
import 'package:caltrac/screens/weight_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// App entry: load .env, init Firebase, then run the app.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const CalTracApp());
}

class CalTracApp extends StatefulWidget {
  const CalTracApp({super.key});

  @override
  State<CalTracApp> createState() => _CalTracAppState();
}

class _CalTracAppState extends State<CalTracApp> {
  int _currentIndex = 0;

  // List of screens and titles for the bottom navigation bar.
  final List<Widget> _screens = [
    DailyProgressScreen(),
    WeeklyProgressScreen(),
    MonthlyProgressScreen(),
    LogScreen(),
    WeightScreen(),
  ];

  final List<String> _titles = [
    'Daily Summary',
    'Weekly Summary',
    'Monthly Summary',
    'Calorie Log',
    'Weight Tracker',
  ];

  @override
Widget build(BuildContext context) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'BebasNeue',
      useMaterial3: true,
    ),
    home: Scaffold(
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: Colors.black,
        title: Text(
          // Display the title based on the current index.
          _titles[_currentIndex],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'BebasNeue',
            fontSize: 50.0,
          ),
        ),
      ),
      // Display the current screen based on the selected index.
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.grey[600],
        unselectedItemColor: Colors.black,
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        // Define the bottom navigation bar items with icons and labels.
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.today), label: 'Daily'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_view_week), label: 'Weekly'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Monthly'),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Add'),
          BottomNavigationBarItem(icon: Icon(Icons.monitor_weight), label: 'Weight'),
        ],
      ),
    ),
  );
}
}


