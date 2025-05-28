import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

/// Screen showing details for a given BobaStore and handling visit detection
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
  bool _timerActive = false;
  int _timeRemaining = 30;
  Timer? _locationTimer;
  Timer? _countdownTimer;
  Position? _currentPosition;
  static const _threshold = 20.0;
  static const _countdownStart = 30;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;
    _locationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProximity(),
    );
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkProximity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      _currentPosition = pos;
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );
      if (dist <= _threshold && !_timerActive && !visitRecorded) {
        _startCountdown();
      } else if (dist > _threshold && _timerActive) {
        _resetCountdown();
      }
    } catch (e) {
      debugPrint('Position error: $e');
    }
  }

  void _startCountdown() {
    setState(() {
      _timerActive = true;
      _timeRemaining = _countdownStart;
    });
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (t) async {
        if (_timeRemaining > 0) {
          setState(() => _timeRemaining--);
        } else {
          t.cancel();
          await _finalizeVisit();
        }
      },
    );
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _timerActive = false;
      _timeRemaining = _countdownStart;
    });
  }

  Future<void> _finalizeVisit() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );
      if (dist <= _threshold) {
        await _recordVisit(pos);
        setState(() {
          visitRecorded = true;
          _timerActive = false;
        });
      } else {
        _resetCountdown();
      }
    } catch (e) {
      debugPrint('Finalize error: $e');
      _resetCountdown();
    }
  }

  Future<void> _recordVisit(Position position) async {
    // Unique visit under userVisits
    final userVisitRef = FirebaseDatabase.instance
        .ref('userVisits/${widget.userId}/${widget.store.id}');
    if ((await userVisitRef.get()).exists) return;

    // 1) add to visits
    await FirebaseDatabase.instance
        .ref('visits/${widget.store.id}/${widget.userId}')
        .set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    // 2) increment store visits
    final storeRef = FirebaseDatabase.instance
        .ref('stores/${widget.store.city}/${widget.store.id}');
    await storeRef.runTransaction((data) {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        map['visits'] = (map['visits'] ?? 0) + 1;
        return Transaction.success(map);
      }
      return Transaction.success(data);
    });

    // 3) mark userVisits
    await userVisitRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': position.latitude,
      'longitude': position.longitude,
    });

    // 4) award one coin
    final coinRef = FirebaseDatabase.instance
        .ref('users/${widget.userId}/coins');
    final coinSnap = await coinRef.get();
    final curr = coinSnap.exists ? coinSnap.value as int : 0;
    await coinRef.set(curr + 1);

    debugPrint('Visit recorded & 1 coin awarded');
  }

  Future<void> _openMaps() async {
    final uri = Uri.https(
      'www.google.com',
      'maps/search/',
      {
        'api': '1',
        'query': '${widget.store.latitude},${widget.store.longitude}'
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = _currentPosition == null
        ? 0
        : Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            widget.store.latitude,
            widget.store.longitude,
          );
    final miles = (dist / 1000) * 0.621371;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 100, color: Colors.grey),
              const SizedBox(height: 24),
              Text('Distance: ${miles.toStringAsFixed(2)} mi',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _openMaps,
                child: Text(
                  '${widget.store.address}\n'
                  '${widget.store.city}, ${widget.store.state} ${widget.store.zip}',
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
                const Text('Visit recorded!',
                    style: TextStyle(fontSize: 16, color: Colors.green))
              else if (_timerActive)
                Text('\$_timeRemaining sec to record visit',
                    style: const TextStyle(fontSize: 16, color: Colors.orange))
              else
                const Text('Move closer to record visit',
                    style: TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}
