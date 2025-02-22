import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class QrCodeDisplay extends StatelessWidget {
  final Future<String> qrCodeFuture;

  const QrCodeDisplay({Key? key, required this.qrCodeFuture}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: qrCodeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else {
          // If the QR code string has a prefix like "data:image/png;base64,"
          // we remove that part.
          Uint8List imageBytes = base64Decode(snapshot.data!.split(',').last);
          return Image.memory(imageBytes);
        }
      },
    );
  }
}
