import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/widgets/remove_entry_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:caltrac/services/firebase_functions.dart';
import 'package:cloud_functions/cloud_functions.dart';


class LogScreen extends StatefulWidget{
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {

  final TextEditingController _controllerLog = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first, 
  );

  void _submitInput() async {
    final rawInput = _controllerLog.text;
    final dateString = _dateController.text.trim();
    final parsedDate = dateString.isNotEmpty
        ? DateTime.tryParse(dateString)
        : DateTime.now();

    final currentUserUid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Update if app has other users

    if (currentUserUid == null) {
      print('User not signed in!');
      return;
    }

    if (parsedDate == null) {
      print('Invalid date format');
      return;
    }

    try {
      final parsedData = await extractNutrition(rawInput);
      print('Parsed Data from AI: $parsedData');

      final entryData = {
        'input': rawInput,
        ...parsedData,
      };

      await logEntryToFirebase(
        userId: currentUserUid,
        date: parsedDate,
        entryData: entryData,
      );

      setState(() {
        _controllerLog.clear();
        _dateController.text = DateTime.now().toIso8601String().split('T').first;
      });

    } catch (e) {
      print('Error logging entry: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Center(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => RemoveEntryWidget(),
                  );
                },
                child: Text(
                  'View entries',
                  style: TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
                ),
              ),
            ),
            SizedBox(
              height: 100
            ),
            Text(
              'Enter Item:',
              style: TextStyle(
                fontSize: 25
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: TextField(
                controller: _controllerLog,
                decoration: InputDecoration(
                  labelText: 'e.g "Chicken Breast, 8.oz, Raw"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    fontSize: 10
                  )
                ),
              ),
            ),
            Text(
              'Enter date:',
              style: TextStyle(
                fontSize: 25
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
              child: TextField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'E.g. "2025-07-18"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    fontSize: 10
                  )
                ),
              ),
            ),
            FloatingActionButton.extended(
              onPressed: _submitInput,
              backgroundColor: Colors.blue[300],
              label: Text(
                '          Add          ',
              ),
            ),
            SizedBox(
              height: 10,
            ),
          ],
        ),
      )
    );
  }
}