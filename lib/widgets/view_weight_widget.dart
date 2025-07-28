import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ViewWeightWidget extends StatefulWidget {
  const ViewWeightWidget({super.key});

  @override
  State<ViewWeightWidget> createState() => _ViewWeightWidgetState();
}

class _ViewWeightWidgetState extends State<ViewWeightWidget> {
  List<Map<String, dynamic>> _weightLogs = [];

  @override
  void initState() {
    super.initState();
    _fetchWeightLogs();
  }

  Future<void> _deleteWeightLogFromFirebase(int index) async {
    final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Replace with current user's UID if needed
    final docId = _weightLogs[index]['id'];

    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weightLogs')
        .doc(docId);

    await docRef.delete();

    setState(() {
      _weightLogs.removeAt(index);
    });
  }

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
              Navigator.of(context).pop(); // close dialog
              _deleteWeightLogFromFirebase(index);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  Future<void> _fetchWeightLogs() async {
    final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2'; // Update if needed
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
                      style: const TextStyle(
                        fontSize: 20,
                      )
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontSize: 20,
                          )
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _confirmDeleteMeal(index); 
                          },
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