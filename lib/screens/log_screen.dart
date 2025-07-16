import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/widgets/remove_entry_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class LogScreen extends StatefulWidget{
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
final TextEditingController _controllerLog = TextEditingController();
final TextEditingController _controllerDate = TextEditingController();
String _userDate = '';
String _userLog = '';

  void _submitInput() async {
    final rawInput = _controllerLog.text;
    final date = _controllerDate.text;

    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserUid == null) {
      print('User not signed in!');
      return;
    }

    try {
      final parsedData = await extractNutrition(rawInput);

      await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserUid) // Replace with your auth UID
        .collection('Logs')
        .add({
          'input': rawInput,
          'date': date,
          ...parsedData,
        });

      setState(() {
        _userLog = rawInput;
        _userDate = date;
      });
    } catch (e) {
      print('AI Parsing or Firebase Error: $e');
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
                controller: _controllerDate,
                decoration: InputDecoration(
                  labelText: 'e.g "04/27/2005"',
                  border: OutlineInputBorder(),
                  labelStyle: TextStyle(
                    fontSize: 10
                  )
                ),
              ),
            ),
            FloatingActionButton.extended(
              onPressed: () { _submitInput(); },
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