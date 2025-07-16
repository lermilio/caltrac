import 'package:flutter/material.dart';

class RemoveEntryWidget extends StatelessWidget {
  const RemoveEntryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Text(
                'Recent Entries',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              // Add your list of items here
            ],
          ),
        );
      },
    );
  }
}