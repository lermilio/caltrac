import 'package:caltrac/widgets/view_weight_widget.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:cloud_functions/cloud_functions.dart';

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});
  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  // Controllers for text inputs
  final TextEditingController _controllerWeight = TextEditingController();
  final TextEditingController _controllerDate = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first, // Default to today
  );

  // Submits the entered weight and date to Firebase
  Future<void> _submitInput() async {
    final weightInput = _controllerWeight.text.trim();
    final dateInput = _controllerDate.text.trim();
    final currentUserUid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Hardcoded UID

    // Validate inputs
    if (weightInput.isEmpty || dateInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }

    // Validate date format
    final parsedDate = dateInput.isNotEmpty
        ? DateTime.tryParse(dateInput)
        : DateTime.now();
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format')),
      );
      return;
    }

    // Validate weight format
    if (!isNumeric(weightInput)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Weight must be a number')),
      );
      return;
    }

    // Attempt to log weight
    try {
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

  // Checks if a string is numeric (integer or decimal)
  bool isNumeric(String input) {
    if (input.isEmpty) return false;
    if (int.tryParse(input) != null) return true;
    if (double.tryParse(input) != null) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),

          // Header
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Text(
              'Enter Weight',
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // Weight input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
            child: TextField(
              controller: _controllerWeight,
              decoration: const InputDecoration(
                labelText: 'e.g "160"',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(fontSize: 10),
              ),
            ),
          ),

          // Date input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: TextField(
              controller: _controllerDate,
              decoration: const InputDecoration(
                labelText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
                labelStyle: TextStyle(fontSize: 10),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Submit button
          Center(
            child: FloatingActionButton.extended(
              onPressed: _submitInput,
              backgroundColor: Colors.blue[300],
              label: const Text('          Add          '),
            ),
          ),

          const SizedBox(height: 30),

          // Display list of logged weights
          const Expanded(child: ViewWeightWidget()),
        ],
      ),
    );
  }
}
