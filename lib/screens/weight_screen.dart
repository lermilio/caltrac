import 'package:caltrac/widgets/view_weight_widget.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:cloud_functions/cloud_functions.dart';

class WeightScreen extends StatefulWidget{
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  final TextEditingController _controllerWeight = TextEditingController();
  final TextEditingController _controllerDate = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first, 
  );

  Future<void> _submitInput() async {
    final weightInput = _controllerWeight.text.trim();
    final dateInput = _controllerDate.text.trim();
    final currentUserUid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Update if app has other users

    if (weightInput.isEmpty || dateInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    final parsedDate = dateInput.isNotEmpty
        ? DateTime.tryParse(dateInput)
        : DateTime.now();
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format')),
      );
      return; 
    }

    if (!isNumeric(weightInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be a number')),
      );
      return;
    }

    if (currentUserUid == null) {
      print('User not signed in!');
      return;
    }

    try{
      await logWeightToFirebase(
        userId: currentUserUid,
        date: parsedDate,
        weight: double.parse(weightInput),
      );
      setState(() {
        _controllerWeight.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight logged successfully ✅')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'already-exists') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⚠️ Weight already logged for that date')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  bool isNumeric(String input) {
    if (input.isEmpty) return false;
    if (int.tryParse(input) != null) return true;
    if (double.tryParse(input) != null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Enter Weight',
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
              controller: _controllerWeight,
              decoration: InputDecoration(
                labelText: 'e.g "160"',
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
              controller: _controllerDate,
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
            height: 30,
          ),
          Expanded(child: ViewWeightWidget()),
        ],
      )
    );
  }
}