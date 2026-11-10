import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Widget to display and manage a list of logged weights from Firestore
class ViewWeightWidget extends StatefulWidget {
  const ViewWeightWidget({super.key, this.loadWeights, this.deleteWeight});

  // Defaults use Firestore; tests supply local callbacks.
  final Future<List<Map<String, dynamic>>> Function()? loadWeights;
  final Future<void> Function(String id)? deleteWeight;

  @override
  State<ViewWeightWidget> createState() => ViewWeightWidgetState();
}

class ViewWeightWidgetState extends State<ViewWeightWidget> {
  List<Map<String, dynamic>> _weightLogs = []; // Local list of weight logs
  bool _isLoading = true;
  String? _loadError;
  final Set<String> _deletingIds = {};
  int _loadRequest = 0;
  final uid = 'e2aPNbtabDSQZVcoRyCIS549reh2';

  Future<void> reloadForDate(DateTime date) async {
    await _fetchWeightLogs();
  }

  @override
  void initState() {
    super.initState();
    _fetchWeightLogs(); // Load weight logs on init
  }

  // Deletes a weight log from Firestore and local list
  Future<void> _deleteWeightLog(String docId) async {
    if (_deletingIds.contains(docId)) return;
    setState(() => _deletingIds.add(docId));
    try {
      await (widget.deleteWeight?.call(docId) ??
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('weightLogs')
              .doc(docId)
              .delete());
      if (!mounted) return;
      setState(() => _weightLogs.removeWhere((log) => log['id'] == docId));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete weight entry. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingIds.remove(docId));
    }
  }

  // Shows confirmation dialog before deleting weight log
  void _confirmDeleteWeight(String docId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: Text('Are you sure you want to delete weight from "$docId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteWeightLog(docId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _readWeightLogsFromFirebase() async {
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('weightLogs')
        .orderBy('date')
        .get();

    return docRef.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList();
  }

  // Loading and an empty result are separate states.
  Future<void> _fetchWeightLogs() async {
    final request = ++_loadRequest;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final logs =
          await (widget.loadWeights?.call() ?? _readWeightLogsFromFirebase());
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _weightLogs = List.of(logs);
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _loadRequest) return;
      setState(() {
        _loadError = 'Could not load weight logs. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Logs'),
        backgroundColor: Colors.grey[300],
      ),
      body: _buildWeightLogs(),
    );
  }

  Widget _buildWeightLogs() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_loadError!),
            TextButton(onPressed: _fetchWeightLogs, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_weightLogs.isEmpty) {
      return const Center(child: Text('No weight entries yet.'));
    }
    return ListView.builder(
      itemCount: _weightLogs.length,
      itemBuilder: (context, index) {
        final log = _weightLogs[index];
        final dayKey = log['id'] as String; // "yyyy-MM-dd"
        final localDate = DateTime.parse(
          dayKey,
        ); // local midnight of that calendar day
        final formattedDate = DateFormat('MMMM d, y').format(localDate);
        final weight = log['weight'];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: ListTile(
            title: Text("$weight lbs", style: const TextStyle(fontSize: 20)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formattedDate, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                IconButton(
                  icon: _deletingIds.contains(dayKey)
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(),
                        )
                      : const Icon(Icons.delete, color: Colors.red),
                  onPressed: _deletingIds.contains(dayKey)
                      ? null
                      : () => _confirmDeleteWeight(dayKey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
