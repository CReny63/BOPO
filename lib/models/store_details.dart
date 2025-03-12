import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId; // Unique identifier for the current user

  const StoreDetailsScreen({
    Key? key,
    required this.store,
    required this.userPosition,
    required this.userId,
  }) : super(key: key);

  @override
  _StoreDetailsScreenState createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  bool visitRecorded = false;
  final double thresholdMeters = 3.05; // Approximately 10 feet

  @override
  void initState() {
    super.initState();
    _checkAndRecordVisit();
  }

  Future<void> _checkAndRecordVisit() async {
    // Basic spoofing prevention: check that location accuracy is good
    // and that the timestamp is recent. (For full spoofing prevention, consider
    // additional server-side verification.)
    if (widget.userPosition.accuracy > 20.0) {
      print("Location accuracy too low: ${widget.userPosition.accuracy}");
      return;
    }
    if (DateTime.now().difference(widget.userPosition.timestamp!) > Duration(minutes: 5)) {
      print("Location data is stale.");
      return;
    }

    double distance = Geolocator.distanceBetween(
      widget.userPosition.latitude,
      widget.userPosition.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    if (distance <= thresholdMeters && !visitRecorded) {
      await _recordVisit();
      setState(() {
        visitRecorded = true;
      });
    }
  }

Future<void> _recordVisit() async {
  // Save the visit under a dedicated node using the store ID and user ID.
  final DatabaseReference visitsRef = FirebaseDatabase.instance
      .ref()
      .child('visits')
      .child(widget.store.id);
  final DataSnapshot snapshot = await visitsRef.child(widget.userId).get();

  if (!snapshot.exists) {
    await visitsRef.child(widget.userId).set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': widget.userPosition.latitude,
      'longitude': widget.userPosition.longitude,
    });

    // Update the store's total visit count using a transaction.
    final DatabaseReference storeRef = FirebaseDatabase.instance
        .ref()
        .child('stores')
        .child(widget.store.city)
        .child(widget.store.id);

    await storeRef.runTransaction((mutableData) async {
      if (mutableData.value != null) {
        Map data = Map.from(mutableData.value as Map);
        int currentVisits = data['visits'] != null ? data['visits'] as int : 0;
        data['visits'] = currentVisits + 1;
        mutableData.value = data;
      }
      return Transaction.success(mutableData);
    } as TransactionHandler);

    // Record the unique visit for missions.
    await FirebaseDatabase.instance
        .ref()
        .child("userVisits")
        .child(widget.userId)
        .child(widget.store.id)
        .set(true);
  }
}





  Future<void> _openMaps(BuildContext context) async {
    final Uri googleMapsUri = Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: 'maps/search/',
      queryParameters: {
        'api': '1',
        'query': '${widget.store.latitude},${widget.store.longitude}',
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
      widget.userPosition.latitude,
      widget.userPosition.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    double distanceKm = distance / 1000;
    double distanceMiles = distanceKm * 0.621371;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replace the QR code display with a store icon or other visual.
              Icon(
                Icons.store,
                size: 100,
                color: Colors.grey,
              ),
              const SizedBox(height: 24.0),
              Text(
                "Distance: ${distanceMiles.toStringAsFixed(2)} mi",
                style: const TextStyle(fontSize: 18.0),
              ),
              const SizedBox(height: 16.0),
              GestureDetector(
                onTap: () => _openMaps(context),
                child: Text(
                  "${widget.store.address}\n${widget.store.city}, ${widget.store.state} ${widget.store.zip}",
                  style: const TextStyle(
                    fontSize: 16.0,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24.0),
              // Inform the user whether a visit was recorded.
              if (visitRecorded)
                const Text(
                  "Visit recorded!",
                  style: TextStyle(fontSize: 16, color: Colors.green),
                )
              else
                const Text(
                  "You are not close enough to record a visit.",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
