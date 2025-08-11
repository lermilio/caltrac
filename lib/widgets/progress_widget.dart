import 'package:flutter/material.dart';

// Displays a single progress stat card with a title and value (and optional unit)
class ProgressWidget extends StatelessWidget {
  final String title; // Label for the metric (e.g., "Calories In")
  final int data;     // Value of the metric
  final String? unit; // Optional unit to display next to the value

  const ProgressWidget({
    super.key,
    required this.title,
    required this.data,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Metric title
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),

            // Metric value (with unit if provided)
            Center(
              child: Text(
                unit != null ? '$data ${unit!}' : data.toString(),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
