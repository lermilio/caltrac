import 'dart:math';

import 'package:caltrac/services/calorie_log_parser.dart';
import 'package:caltrac/services/firebase_functions.dart';
import 'package:flutter/material.dart';
import 'package:caltrac/widgets/view_entries_widget.dart';

typedef FoodEntrySaver =
    Future<void> Function({
      required String userId,
      required DateTime date,
      required Map<String, dynamic> entryData,
    });

typedef ExtraCaloriesSaver =
    Future<void> Function({
      required String userId,
      required DateTime date,
      required int extraCals,
    });

// LogScreen allows users to log food items or extra calories for a specific date.
class LogScreen extends StatefulWidget {
  const LogScreen({
    super.key,
    this.parseNutrition,
    this.saveEntry = logEntryToFirebase,
    this.saveExtraCalories = logCalsOutToFirebase,
    this.entriesWidget,
  });

  // Defaults use the real services; tests can supply local substitutes.
  final Future<Map<String, int>> Function(String)? parseNutrition;
  final FoodEntrySaver saveEntry;
  final ExtraCaloriesSaver saveExtraCalories;
  final Widget? entriesWidget;
  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  final GlobalKey<ViewEntriesWidgetState> _entriesKey =
      GlobalKey<ViewEntriesWidgetState>();

  // Controllers for getting user input.
  final TextEditingController _controllerLog = TextEditingController();
  final TextEditingController _controllerCals = TextEditingController();
  final TextEditingController _dateController = TextEditingController(
    text: DateTime.now().toIso8601String().split('T').first,
  );

  // Dropdown for selecting input type.
  bool _isSubmitting = false;
  Map<String, dynamic>? _pendingFoodEntry;
  DateTime? _pendingFoodDate;
  String _selectedOption = 'Enter Item';
  final List<String> _options = ['Enter Item', 'Enter Extra Kcals'];

  // Submit user input to Firebase
  Future<void> _submitInput() async {
    if (_isSubmitting) return;
    final rawKcalInput = _controllerCals.text;
    final rawItemInput = _controllerLog.text;
    final dateString = _dateController.text.trim();
    final currentUserUid = 'e2aPNbtabDSQZVcoRyCIS549reh2';

    // Validate inputs
    if ((rawItemInput.isEmpty && rawKcalInput.isEmpty) || dateString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in both fields')),
      );
      return;
    }
    final parsedDate = dateString.isNotEmpty
        ? DateTime.tryParse(dateString)
        : DateTime.now();
    if (parsedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid date format')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // Submitting extra burned calories to Firebase
      if (_selectedOption == 'Enter Extra Kcals') {
        // Validate and parse the input
        final parsedInput = int.tryParse(rawKcalInput);
        if (parsedInput == null) {
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

        if (!mounted || !confirmed) return;

        await widget.saveExtraCalories(
          userId: currentUserUid,
          date: parsedDate,
          extraCals: parsedInput,
        );
        if (!mounted) return;
        _entriesKey.currentState?.reloadForDate(parsedDate);

        setState(() {
          _controllerCals.clear(); // Clear the input field after logging
          _dateController.text = DateTime.now()
              .toIso8601String()
              .split('T')
              .first;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra calories logged ✅')),
        );
      }
      // Submitting a consumed item to Firebase
      else if (_selectedOption == 'Enter Item') {
        // Keep the same ID and estimate when retrying an unchanged failed save.
        var entryData = _pendingFoodEntry;
        if (entryData == null ||
            entryData['input'] != rawItemInput ||
            _pendingFoodDate != parsedDate) {
          _pendingFoodEntry = null;
          final parsedData =
              await (widget.parseNutrition ?? NutritionParser().parse)(
                rawItemInput,
              );
          if (!mounted) return;

          final random = Random.secure();
          final id = List.generate(
            16,
            (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
          ).join();
          entryData = {'input': rawItemInput, ...parsedData, 'id': id};
          _pendingFoodEntry = entryData;
          _pendingFoodDate = parsedDate;
        }

        final confirmed = await _showConfirmDialog(
          context: context,
          entryData: entryData,
          date: parsedDate,
        );

        if (!mounted || !confirmed) {
          return; // User cancelled the dialog
        }

        await widget.saveEntry(
          userId: currentUserUid,
          date: parsedDate,
          entryData: entryData,
        );
        if (!mounted) return;
        _entriesKey.currentState?.reloadForDate(parsedDate);

        setState(() {
          _controllerLog.clear();
          _pendingFoodEntry = null;
          _pendingFoodDate = null;
          _dateController.text = DateTime.now()
              .toIso8601String()
              .split('T')
              .first;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Entry saved ✅')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _controllerLog.dispose();
    _controllerCals.dispose();
    _dateController.dispose();
    super.dispose();
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
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Submit'),
                ),
              ],
            );
          },
        )) ??
        false; // Default to false if dialog is dismissed
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
                  onPressed: () => Navigator.of(context).pop(true),
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
                  onChanged: _isSubmitting
                      ? null
                      : (String? newValue) {
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: _controllerLog,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'e.g "Chicken Breast, 8.oz, Raw"',
                      border: OutlineInputBorder(),
                      labelStyle: TextStyle(fontSize: 10),
                    ),
                  ),
                ),

              if (_selectedOption == 'Enter Extra Kcals')
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 10,
                  ),
                  child: TextField(
                    controller: _controllerCals,
                    enabled: !_isSubmitting,
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
                  enabled: !_isSubmitting,
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
                  onPressed: _isSubmitting ? null : _submitInput,
                  backgroundColor: Colors.blue[300],
                  label: const Text('          Add          '),
                ),
              ),
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Divider(),
              ),
              widget.entriesWidget ?? ViewEntriesWidget(key: _entriesKey),
            ],
          ),
        ),
      ),
    );
  }
}
