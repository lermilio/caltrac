import 'package:flutter/material.dart';

// This widget represents the bottom navigation bar for the app.
class BottomBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.today),
          label: 'Daily',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.date_range),
          label: 'Weekly',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: 'Monthly',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.restaurant_menu),
          label: 'Log',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.scale),
          label: 'Weight',
        ),
      ],
    );
  }
}