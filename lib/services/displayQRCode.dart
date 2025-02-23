import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class QrCodeDisplay extends StatelessWidget {
  final Future<String> qrCodeFuture;

  const QrCodeDisplay({super.key, required this.qrCodeFuture});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: qrCodeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          // Remove any prefix like "data:image/png;base64," if necessary.
          Uint8List imageBytes = base64Decode(snapshot.data!.split(',').last);
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
            ),
          );
        }
      },
    );
  }
}
