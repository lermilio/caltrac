import 'package:flutter/material.dart';

// Displays saved totals first, then replaces them after a WHOOP refresh.
class RefreshingSummary extends StatefulWidget {
  const RefreshingSummary({
    super.key,
    required this.period,
    required this.loadSummary,
    required this.refreshWhoop,
    required this.builder,
  });

  final DateTime period;
  final Future<Map<String, dynamic>> Function() loadSummary;
  final Future<void> Function() refreshWhoop;
  final Widget Function(Map<String, dynamic>) builder;

  @override
  State<RefreshingSummary> createState() => _RefreshingSummaryState();
}

class _RefreshingSummaryState extends State<RefreshingSummary> {
  Map<String, dynamic>? _data;
  bool _loadingSaved = true;
  bool _refreshing = false;
  String? _warning;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _startLoad(clearData: true);
  }

  @override
  void didUpdateWidget(covariant RefreshingSummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) _startLoad(clearData: true);
  }

  void _startLoad({required bool clearData}) {
    if (clearData) _data = null;
    _loadingSaved = true;
    _refreshing = false;
    _warning = null;
    // Capture these callbacks before any await: they belong to this period.
    _load(++_request, widget.loadSummary, widget.refreshWhoop);
  }

  bool _isCurrent(int request) => mounted && request == _request;

  Future<void> _load(
    int request,
    Future<Map<String, dynamic>> Function() loadSummary,
    Future<void> Function() refreshWhoop,
  ) async {
    try {
      final saved = await loadSummary();
      if (!_isCurrent(request)) return;
      setState(() => _data = saved);
    } catch (_) {
      // Still try refreshing: the next summary read may recover.
    }
    if (!_isCurrent(request)) return;
    setState(() {
      _loadingSaved = false;
      _refreshing = true;
    });

    var refreshFailed = false;
    try {
      await refreshWhoop();
    } catch (_) {
      refreshFailed = true;
    }
    if (!_isCurrent(request)) return;

    // Reread even after partial refresh failure: some days may have updated.
    var readFailed = false;
    try {
      final updated = await loadSummary();
      if (!_isCurrent(request)) return;
      setState(() => _data = updated);
    } catch (_) {
      readFailed = true;
    }
    if (!_isCurrent(request)) return;
    setState(() {
      _refreshing = false;
      if (refreshFailed) {
        _warning = 'WHOOP could not be fully updated.';
      } else if (readFailed) {
        _warning = 'Could not reload updated totals.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_refreshing) ...[
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            _data == null
                ? 'Updating WHOOP…'
                : 'Updating WHOOP… Showing saved totals.',
          ),
        ] else if (_warning != null) ...[
          Text(_data == null ? _warning! : '$_warning Showing saved totals.'),
          TextButton(
            onPressed: () => setState(() => _startLoad(clearData: false)),
            child: const Text('Retry'),
          ),
        ] else if (!_loadingSaved)
          const Text('Refresh complete.'),
        if (_data != null)
          widget.builder(_data!)
        else if (_loadingSaved)
          const CircularProgressIndicator()
        else
          const Text('Could not load this summary.'),
      ],
    );
  }
}
