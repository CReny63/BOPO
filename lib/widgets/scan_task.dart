// lib/widgets/scan_task_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart'; // Adjust path as necessary

class ScanTaskWidget extends StatelessWidget {
  final String description;

  const ScanTaskWidget({Key? key, required this.description}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Obtain the current text theme
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: 120,
      height: 120,
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.5), // Transparent gray
        borderRadius: BorderRadius.circular(16.0), // Rounded corners
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Keyhole shape
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2), // Transparent dark circle
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Text at the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  backgroundColor: Colors.black.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
