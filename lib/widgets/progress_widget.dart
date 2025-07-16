import 'package:flutter/material.dart';

class ProgressWidget extends StatelessWidget {

  final String title;
  final int data;
  final String ?unit;

  const ProgressWidget({super.key, 
    required this.title, 
    required this.data, 
    this.unit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
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
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[700],
              ),
            ),
            SizedBox(height: 8),
            Center(
              child: Text(
                unit != null 
                  ? '$data ${unit!}'
                  : data.toString(),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
            SizedBox(height: 16),
            //FloatingActionButton(onPressed: onPressed)
          ],
        ),
      ),
    );
  }
}