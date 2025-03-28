import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId;

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
  // Increased threshold to 13.05 meters.
  final double thresholdMeters = 20.05; 

  Timer? _locationMonitorTimer;
  Timer? _countdownTimer;
  int _timeRemaining = 30;
  bool _timerActive = false;

  // State variable to store the most recent user position.
  Position? _currentUserPosition;

  @override
  void initState() {
    super.initState();
    // Initially set _currentUserPosition to the passed userPosition.
    _currentUserPosition = widget.userPosition;
    // Monitor the user's location every second.
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
      // Update the state with the latest position.
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

    // If within range and no countdown is active and the visit is not recorded, start countdown.
    if (distance <= thresholdMeters && !_timerActive && !visitRecorded) {
      _startCountdown();
    } else if (distance > thresholdMeters && _timerActive) {
      // Cancel the countdown if the user moves out of range.
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
        // Verify the user is still in range.
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
    final DatabaseReference visitsRef = FirebaseDatabase.instance
        .ref()
        .child('visits')
        .child(widget.store.id);
    final DataSnapshot snapshot = await visitsRef.child(widget.userId).get();

    if (!snapshot.exists) {
      await visitsRef.child(widget.userId).set({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

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
      print("Visit registered for store ${widget.store.id}");
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
    // Use the updated _currentUserPosition to calculate the distance.
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
              const Icon(
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
              if (visitRecorded)
                const Text(
                  "Visit recorded!",
                  style: TextStyle(fontSize: 16, color: Colors.green),
                )
              else if (_timerActive)
                Text(
                  "Hold for $_timeRemaining sec to record visit",
                  style: const TextStyle(fontSize: 16, color: Colors.orange),
                )
              else
                const Text(
                  "Move closer to record visit",
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
