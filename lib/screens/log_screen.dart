import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/widgets/view_entries_widget.dart';
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

      final confirmed = await _showConfirmDialog(
        context: context,
        entryData: entryData,
        date: parsedDate,
      );
      
      if(!confirmed) {
        print('User cancelled the entry submission');
        return;
      }

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

  Future<bool> _showConfirmDialog({
  required BuildContext context,
  required Map<String, dynamic> entryData,
  required DateTime date,
  }) async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false, // force an explicit choice
          builder: (_) {
            return AlertDialog(
              title: const Text('Confirm Entry'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Item: ${entryData['input']}'),
                  const SizedBox(height: 8),
                  Text('Calories: ${entryData['calories']} kcal'),
                  Text('Protein: ${entryData['protein']} g'),
                  Text('Carbs: ${entryData['carbs']} g'),
                  Text('Fat: ${entryData['fat']} g'),
                  const Divider(),
                  Text('Date: ${date.toIso8601String().split("T").first}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(true); // dismisses the dialog
                    Future.delayed(Duration.zero, () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Entry saved ✅'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    });
                  },
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        )) ??
        false; // default to false on null
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30),
                child: Text(
                  'Enter Item',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Text(
                  'Enter Date',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _dateController,
                  decoration: InputDecoration(
                    labelText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(
                      fontSize: 10
                    )
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: FloatingActionButton.extended(
                  onPressed: _submitInput,
                  backgroundColor: Colors.blue[300],
                  label: Text(
                    '          Add          ',
                  ),
                ),
              ),
              SizedBox(
                height: 20,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: const Divider(
                ),
              ),
              const ViewEntriesWidget()
            ],
          ),
        ),
      )
    );
  }
}