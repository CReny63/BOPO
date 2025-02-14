import 'dart:convert'; // Needed for jsonEncode
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../locations/boba_store.dart';

class BobaStoreQRCodePage extends StatelessWidget {
  final BobaStore bobaStore;

  const BobaStoreQRCodePage({Key? key, required this.bobaStore}) : super(key: key);

  /// Generates the QR data payload as a JSON string.
  String generateQRData() {
    final Map<String, dynamic> payload = {
      'storeId': bobaStore.id, // Unique identifier for the store
      'name': bobaStore.name,
      'latitude': bobaStore.latitude,
      'longitude': bobaStore.longitude,
      'version': 1,
    };
    return jsonEncode(payload);
  }

  @override
  Widget build(BuildContext context) {
    final String qrData = generateQRData();

    // Determine if the app is in dark mode.
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
              // In dark mode, set the QR code (data modules and eyes) to white
              // and the background to a dark color (like black).
              eyeStyle: QrEyeStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              dataModuleStyle: QrDataModuleStyle(
                color: isDark ? Colors.white : Colors.black,
              ),
              backgroundColor: isDark ? Colors.black : Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              bobaStore.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              bobaStore.address,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
