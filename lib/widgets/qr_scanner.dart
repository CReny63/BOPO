import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final Function(String) onScan;

  const QRScannerPage({Key? key, required this.onScan}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // You can stop/start the camera based on app lifecycle if desired:
    if (state == AppLifecycleState.paused) {
      _controller.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Scan QR Code')),
        body: const Center(
          child: Text('QR scanning is not supported on this platform.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (barcodeCapture) {
          for (final barcode in barcodeCapture.barcodes) {
            final String? code = barcode.rawValue;
            if (code != null) {
              widget.onScan(code);
              Navigator.pop(context);
              break;
            }
          }
        },
      ),
    );
  }
}
