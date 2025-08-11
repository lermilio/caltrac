import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Widget to display and manage a list of logged weights from Firestore
class ViewWeightWidget extends StatefulWidget {
  const ViewWeightWidget({super.key});

  @override
  State<ViewWeightWidget> createState() => _ViewWeightWidgetState();
}

class _ViewWeightWidgetState extends State<ViewWeightWidget> {
  List<Map<String, dynamic>> _weightLogs = []; // Local list of weight logs
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; 

  @override
  void initState() {
    super.initState();
    _fetchWeightLogs(); // Load weight logs on init
  }

  // Deletes a weight log from Firestore and local list
  Future<void> _deleteWeightLogFromFirebase(int index) async {
    final docId = _weightLogs[index]['id'];

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weightLogs')
        .doc(docId);

    await docRef.delete();
    setState(() => _weightLogs.removeAt(index));
  }

  // Shows confirmation dialog before deleting weight log
  void _confirmDeleteMeal(int index) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete weight from "${_weightLogs[index]['id']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteWeightLogFromFirebase(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Fetches weight logs from Firestore and stores them in local list
  Future<void> _fetchWeightLogs() async {
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weightLogs')
        .orderBy('date')
        .get();

    setState(() {
      _weightLogs = docRef.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Logs'),
        backgroundColor: Colors.grey[300],
      ),
      body: _weightLogs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _weightLogs.length,
              itemBuilder: (context, index) {
                final log = _weightLogs[index];
                final date = (log['date'] as Timestamp).toDate();
                final formattedDate = DateFormat('MMMM d, y').format(date);
                final weight = log['weight'];

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                  child: ListTile(
                    title: Text(
                      "$weight lbs",
                      style: const TextStyle(fontSize: 20),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteMeal(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
