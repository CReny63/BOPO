import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId; // Firebase UID

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
    _locationMonitorTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkAndStartCountdown(),
    );
  }

  @override
  void dispose() {
    _locationMonitorTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndStartCountdown() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _currentUserPosition = pos;
    } catch (_) {
      return;
    }

    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );

    if (dist <= thresholdMeters && !_timerActive && !visitRecorded) {
      _startCountdown();
    } else if (dist > thresholdMeters && _timerActive) {
      _cancelCountdown();
    }
  }

  void _startCountdown() {
    setState(() {
      _timerActive = true;
      _timeRemaining = 30;
    });
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) async {
        setState(() => _timeRemaining--);
        if (_timeRemaining <= 0) {
          timer.cancel();
          await _verifyAndRecordVisit();
        }
      },
    );
  }

  Future<void> _verifyAndRecordVisit() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      _cancelCountdown();
      return;
    }
    final updatedDist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    if (updatedDist <= thresholdMeters) {
      await _recordVisit(pos);
      setState(() {
        visitRecorded = true;
        _timerActive = false;
      });
    } else {
      _cancelCountdown();
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _timerActive = false;
      _timeRemaining = 30;
    });
  }

  Future<void> _recordVisit(Position position) async {
    final userVisitsRef = FirebaseDatabase.instance
        .ref()
        .child('userVisits')
        .child(widget.userId)
        .child(widget.store.id);
    final snap = await userVisitsRef.get();
    if (snap.exists) return;

    // 1) Record in visits
    await FirebaseDatabase.instance
        .ref()
        .child('visits')
        .child(widget.store.id)
        .child(widget.userId)
        .set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    // 2) Increment store total visits
    final storeRef = FirebaseDatabase.instance
        .ref()
        .child('stores')
        .child(widget.store.city)
        .child(widget.store.id);
    await storeRef.runTransaction((data) {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        map['visits'] = (map['visits'] ?? 0) + 1;
        return Transaction.success(map);
      }
      return Transaction.success(data);
    });

    // 3) Mark unique visit
    await userVisitsRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    // 4) Award 1 coin to user
    final coinRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.userId)
        .child('coins');
    final coinSnap = await coinRef.get();
    final current = coinSnap.exists ? coinSnap.value as int : 0;
    await coinRef.set(current + 1);

    print('Visit registered and 1 coin awarded for store ${widget.store.id}');
  }

  Future<void> _openMaps() async {
    final uri = Uri.https(
      'www.google.com',
      'maps/search/',
      {'api': '1', 'query': '${widget.store.latitude},${widget.store.longitude}'},
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = _currentUserPosition == null
        ? 0.0
        : Geolocator.distanceBetween(
            _currentUserPosition!.latitude,
            _currentUserPosition!.longitude,
            widget.store.latitude,
            widget.store.longitude,
          );
    final miles = (dist / 1000) * 0.621371;

    return Scaffold(
      appBar: AppBar(title: Text(widget.store.name), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              Text('Distance: ${miles.toStringAsFixed(2)} mi', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _openMaps,
                child: Text(
                  '${widget.store.address}\n${widget.store.city}, ${widget.store.state} ${widget.store.zip}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (visitRecorded)
                const Text('Visit recorded!', style: TextStyle(fontSize: 16, color: Colors.green))
              else if (_timerActive)
                Text('$_timeRemaining sec to record visit', style: const TextStyle(fontSize: 16, color: Colors.orange))
              else
                const Text('Move closer to record visit', style: TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}
