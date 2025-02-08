import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:test/locations/boba_store.dart';

class StoreDetailsScreen extends StatelessWidget {
  final BobaStore store;
  final Position userPosition;

  const StoreDetailsScreen({
    Key? key,
    required this.store,
    required this.userPosition,
  }) : super(key: key);

  Future<void> _openMaps(BuildContext context) async {
    final Uri googleMapsUri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: 'maps/search/',
      queryParameters: {
        'api': '1',
        'query': '${store.latitude},${store.longitude}',
      },
    );

    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open maps.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    double distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );
    double distanceKm = distance / 1000;
    double distanceMiles = distanceKm * 0.621371;

    return Scaffold(
      appBar: AppBar(
        title: Text(store.name),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              QrImageView(
                data: store.qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
              const SizedBox(height: 24.0),
              Text(
                "Distance: ${distanceMiles.toStringAsFixed(2)} mi",
                style: const TextStyle(fontSize: 18.0),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16.0),
              GestureDetector(
                onTap: () => _openMaps(context),
                child: Text(
                  "${store.address}\n${store.city}, ${store.state} ${store.zip}",
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
