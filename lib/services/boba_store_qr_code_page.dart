import 'dart:convert'; // Needed for jsonEncode
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../locations/boba_store.dart';

class BobaStoreQRCodePage extends StatelessWidget {
  final BobaStore bobaStore;

  const BobaStoreQRCodePage({Key? key, required this.bobaStore}) : super(key: key);

  /// Generates the QR data payload as a JSON string.
  /// You can add additional fields (like a timestamp or digital signature) if required.
  String generateQRData() {
    final Map<String, dynamic> payload = {
      'storeId': bobaStore.id, // Unique identifier for the store
      'name': bobaStore.name,
      'latitude': bobaStore.latitude,   // Assumes bobaStore has a latitude field
      'longitude': bobaStore.longitude, // Assumes bobaStore has a longitude field
      'version': 1, // You can use a version number to track payload changes over time
    };

    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final String qrData = generateQRData();

    return Scaffold(
      appBar: AppBar(title: Text('${bobaStore.name} QR Code')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 250.0,
              // Optionally, you can configure error correction level here:
              // errorCorrectionLevel: QrErrorCorrectLevel.H,
            ),
            const SizedBox(height: 20),
            Text(
              bobaStore.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              bobaStore.address, // Assumes bobaStore has an address field
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
