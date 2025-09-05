import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/widgets/view_entries_widget.dart';


// LogScreen allows users to log food items or extra calories for a specific date.
class LogScreen extends StatefulWidget{
  const LogScreen({super.key});
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {

  final GlobalKey<ViewEntriesWidgetState> _entriesKey = GlobalKey<ViewEntriesWidgetState>();

  // Controllers for getting user input.
  final TextEditingController _controllerLog = TextEditingController();
  final TextEditingController _controllerCals = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first, 
  );

  // Dropdown for selecting input type.
  String _selectedOption = 'Enter Item';
  final List<String> _options = [
    'Enter Item',
    'Enter Extra Kcals',
  ];

  // Submit user input to Firebase
  void _submitInput() async {
    final rawKcalInput = _controllerCals.text;
    final rawItemInput = _controllerLog.text;
    final dateString = _dateController.text.trim();
    final currentUserUid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; 

    // Validate inputs
    if ( (rawItemInput.isEmpty && rawKcalInput.isEmpty) || dateString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }
    final parsedDate = dateString.isNotEmpty
        ? DateTime.tryParse(dateString)
        : DateTime.now();
    if (parsedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid date format')),
      );
      return; 
    }

    try {

      // Submitting extra burned calories to Firebase
      if(_selectedOption == 'Enter Extra Kcals'){

        // Validate and parse the input
        final parsedInput = int.tryParse(rawKcalInput);
        if(parsedInput == null){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid integer')),
          );
          return;
        }

        // Log to Firebase
        final confirmed = await _showConfirmExtraCalsDialog(
          context: context,
          calories: parsedInput,
          date: parsedDate,
        );

        if(!confirmed) { return; }

        await logCalsOutToFirebase(
          userId: currentUserUid, 
          date: parsedDate, 
          extraCals: parsedInput
        );
        _entriesKey.currentState?.reloadForDate(parsedDate);

        setState(() {
          _controllerCals.clear(); // Clear the input field after logging
          _dateController.text = DateTime.now().toIso8601String().split('T').first;
        });
      }

      // Submitting a consumed item to Firebase
      else if(_selectedOption == 'Enter Item') {

        // Validate and parse the input
        final parsedData = await NutritionParser().parse(rawItemInput);
        print('Parsed Data from AI: $parsedData');

        final entryData = {
          'input': rawItemInput,
          ...parsedData,
        };

        final confirmed = await _showConfirmDialog(
          context: context,
          entryData: entryData,
          date: parsedDate,
        );

        if (!confirmed) {
          return; // User cancelled the dialog
        }

        await logEntryToFirebase(
          userId: currentUserUid,
          date: parsedDate,
          entryData: entryData,
        );
        _entriesKey.currentState?.reloadForDate(parsedDate);

        setState(() {
          _controllerLog.clear();
          _dateController.text = DateTime.now().toIso8601String().split('T').first;
        });
      }
    }
    catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        return;
    }
  }

  // Ask the user to confirm the extra calories input
  Future<bool> _showConfirmExtraCalsDialog({
    required BuildContext context,
    required int calories,
    required DateTime date,
  }) async {
    return (await showDialog<bool>(
      context: context,
      barrierDismissible: false, // force an explicit choice
      builder: (_) {
        return AlertDialog(
          title: const Text('Confirm Extra Calories'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Extra Calories: $calories kcal'),
              const SizedBox(height: 8),
              Text('Date: ${date.toIso8601String().split("T").first}'),
              const Divider(),
              const Text(
                'Once submitted, this action cannot be undone.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
                Future.delayed(Duration.zero, () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Extra calories logged ✅'),
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
    )) ?? false; // Default to false if dialog is dismissed
  }

  // Ask the user to confirm the food item entry and show its extracted data
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
    false; // Default to false if dialog is dismissed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: DropdownButton<String>(
                  value: _selectedOption,
                  items: _options.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedOption = newValue;
                      });
                    }
                  },
                ),
              ),
              if (_selectedOption == 'Enter Item')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: TextField(
                    controller: _controllerLog,
                    decoration: const InputDecoration(
                      labelText: 'e.g "Chicken Breast, 8.oz, Raw"',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                  ),
                ),

              if (_selectedOption == 'Enter Extra Kcals')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                  child: TextField(
                    controller: _controllerCals,
                    decoration: const InputDecoration(
                      labelText: 'e.g "450"',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: TextField(
                  controller: _dateController,
                  decoration: const InputDecoration(
                    labelText: 'YYYY-MM-DD',
                    border: OutlineInputBorder(),
                    labelStyle: TextStyle(fontSize: 10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: FloatingActionButton.extended(
                  onPressed: _submitInput,
                  backgroundColor: Colors.blue[300],
                  label: const Text('          Add          '),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Divider(),
              ),
              ViewEntriesWidget(key: _entriesKey),
            ],
          ),
        ),
      ),
    );
  }
}