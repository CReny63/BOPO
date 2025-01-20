import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../locations/boba_store.dart';

class BobaStoreQRCodePage extends StatelessWidget {
  final BobaStore bobaStore;

  const BobaStoreQRCodePage({Key? key, required this.bobaStore}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String qrData = bobaStore.qrData;

    return Scaffold(
      appBar: AppBar(title: Text('${bobaStore.name} QR Code')),
      body: Center(
        child: QrImageView(
          data: qrData,
          version: QrVersions.auto,
          size: 200.0,
        ),
      ),
    );
  }
}
