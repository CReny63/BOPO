import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';

/// Production-ready redesign of the store details screen, preserving all existing components.
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
  static const double _proximityThreshold = 20.0;
  static const int _countdownStart = 30;

  bool _visitRecorded = false;
  bool _isCountingDown = false;
  int _secondsLeft = _countdownStart;

  Timer? _proximityTimer;
  Timer? _countdownTimer;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;
    _startProximityMonitoring();
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startProximityMonitoring() {
    _proximityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProximityAndUpdate(),
    );
  }

  Future<void> _checkProximityAndUpdate() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = pos;
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );

      if (distance <= _proximityThreshold && !_isCountingDown && !_visitRecorded) {
        _startCountdown();
      } else if (distance > _proximityThreshold && _isCountingDown) {
        _resetCountdown();
      }
    } catch (e) {
      debugPrint('Proximity error: $e');
    }
  }

  void _startCountdown() {
    setState(() {
      _isCountingDown = true;
      _secondsLeft = _countdownStart;
    });

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (_secondsLeft > 0) {
          setState(() => _secondsLeft--);
        } else {
          timer.cancel();
          _finalizeVisit();
        }
      },
    );
  }

  void _resetCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _isCountingDown = false;
      _secondsLeft = _countdownStart;
    });
  }

  Future<void> _finalizeVisit() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );
      if (distance <= _proximityThreshold) {
        await _recordVisit(pos);
        setState(() {
          _visitRecorded = true;
          _isCountingDown = false;
        });
      } else {
        _resetCountdown();
      }
    } catch (e) {
      debugPrint('Finalize error: $e');
      _resetCountdown();
    }
  }

  Future<void> _recordVisit(Position pos) async {
    final userVisitRef = FirebaseDatabase.instance
        .ref('userVisits/${widget.userId}/${widget.store.id}');
    if ((await userVisitRef.get()).exists) return;

    // 1) add global visit
    await FirebaseDatabase.instance
        .ref('visits/${widget.store.id}/${widget.userId}')
        .set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });

    // 2) increment store's visits counter
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

    // 3) mark user visit
    await userVisitRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });

    // 4) award a coin
    final coinRef = FirebaseDatabase.instance
        .ref('users/${widget.userId}/coins');
    final coinSnap = await coinRef.get();
    final current = (coinSnap.value as int?) ?? 0;
    await coinRef.set(current + 1);

    debugPrint('Visit recorded & 1 coin awarded');
  }

  Future<void> _launchMaps() async {
    final uri = Uri.https(
      'www.google.com',
      'maps/search/',
      {
        'api': '1',
        'query':
            '${widget.store.latitude},${widget.store.longitude}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            widget.store.latitude,
            widget.store.longitude,
          )
        : 0.0;
    final miles = (distance / 1000) * 0.621371;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Store icon & distance row
            Row(
              children: [
                Icon(Icons.store, size: 80, color: Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${miles.toStringAsFixed(2)} mi away',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Address card with tappable maps link
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: _launchMaps,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.store.address, style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.store.city}, ${widget.store.state} ${widget.store.zip}',
                        style: TextStyle(color: Colors.blue),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.launch, size: 20, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Proximity / countdown / done indicator
            Center(
              child: _visitRecorded
                  ? Chip(
                      label: const Text('Visit Recorded'),
                      backgroundColor: Colors.green.shade600,
                      labelStyle: const TextStyle(color: Colors.white),
                    )
                  : _isCountingDown
                      ? Column(
                          children: [
                            Text(
                              'Recording in $_secondsLeft s...',
                              style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.orange.shade800),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: (_countdownStart - _secondsLeft) /
                                  _countdownStart,
                            ),
                          ],
                        )
                      : Text(
                          'Move closer to record visit',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, color: Colors.red.shade600),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
