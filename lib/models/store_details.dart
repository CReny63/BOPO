import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId; // This should be the real Firebase UID

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
  final double thresholdMeters = 20.05;
  Timer? _locationMonitorTimer;
  Timer? _countdownTimer;
  int _timeRemaining = 30;
  bool _timerActive = false;
  Position? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    _currentUserPosition = widget.userPosition;
    _locationMonitorTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _checkAndStartCountdown();
    });
  }

  @override
  void dispose() {
    _locationMonitorTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndStartCountdown() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentUserPosition = currentPosition;
      });
    } catch (e) {
      print("Error obtaining position: $e");
      return;
    }

    double distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );

    if (distance <= thresholdMeters && !_timerActive && !visitRecorded) {
      _startCountdown();
    } else if (distance > thresholdMeters && _timerActive) {
      _cancelCountdown();
    }
  }

  void _startCountdown() {
    setState(() {
      _timerActive = true;
      _timeRemaining = 30;
    });
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) async {
      setState(() {
        _timeRemaining--;
      });
      if (_timeRemaining <= 0) {
        timer.cancel();
        Position updatedPosition;
        try {
          updatedPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high);
        } catch (e) {
          print("Error obtaining updated position: $e");
          _cancelCountdown();
          return;
        }
        double updatedDistance = Geolocator.distanceBetween(
          updatedPosition.latitude,
          updatedPosition.longitude,
          widget.store.latitude,
          widget.store.longitude,
        );
        if (updatedDistance <= thresholdMeters) {
          await _recordVisit(updatedPosition);
          setState(() {
            visitRecorded = true;
            _timerActive = false;
          });
        } else {
          _cancelCountdown();
        }
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    setState(() {
      _timerActive = false;
      _timeRemaining = 30;
    });
  }

  Future<void> _recordVisit(Position position) async {
    // Write visit details under /visits/<storeId>/<userId>
    final DatabaseReference visitsRef = FirebaseDatabase.instance
        .ref()
        .child('visits')
        .child(widget.store.id);
    final DataSnapshot snapshot = await visitsRef.child(widget.userId).get();

    if (!snapshot.exists) {
      // Write detailed visit information.
      await visitsRef.child(widget.userId).set({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      // Update the store's overall visit count.
      final DatabaseReference storeRef = FirebaseDatabase.instance
          .ref()
          .child('stores')
          .child(widget.store.city)
          .child(widget.store.id);

      await storeRef.runTransaction((currentData) {
        if (currentData != null) {
          Map data = Map.from(currentData as Map);
          int currentVisits = data['visits'] ?? 0;
          data['visits'] = currentVisits + 1;
          return Transaction.success(data);
        }
        return Transaction.success(currentData);
      });

      // Record the unique visit for missions under /userVisits/<userId>/<storeId>
      await FirebaseDatabase.instance
          .ref()
          .child("userVisits")
          .child(widget.userId)
          .child(widget.store.id)
          .set({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });
      print("Visit registered for store ${widget.store.id} with uid ${widget.userId}");
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
    double distance = 0;
    if (_currentUserPosition != null) {
      distance = Geolocator.distanceBetween(
        _currentUserPosition!.latitude,
        _currentUserPosition!.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );
    }
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
              const Icon(Icons.store, size: 100, color: Colors.grey),
              const SizedBox(height: 24.0),
              Text("Distance: ${distanceMiles.toStringAsFixed(2)} mi",
                  style: const TextStyle(fontSize: 18.0)),
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
              if (visitRecorded)
                const Text("Visit recorded!",
                    style: TextStyle(fontSize: 16, color: Colors.green))
              else if (_timerActive)
                Text("$_timeRemaining sec to record visit",
                    style: const TextStyle(fontSize: 16, color: Colors.orange))
              else
                const Text("Move closer to record visit",
                    style: TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}
