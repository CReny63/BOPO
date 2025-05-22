import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';

class VisitMonitor {
  static final VisitMonitor _instance = VisitMonitor._();
  factory VisitMonitor() => _instance;
  VisitMonitor._();

  late String _userId;
  late DatabaseReference _userRef;
  final StoreService _storeService = StoreService();

  // track active countdown per store
  final Map<String, Timer> _countdowns = {};
  static const _thresholdMeters = 20.0;
  static const _waitSeconds = 30;

  StreamSubscription<Position>? _positionSub;

  /// Start monitoring location and visit logic for [userId]
  void start(String userId) {
    _userId = userId;
    _userRef = FirebaseDatabase.instance.ref('users/$_userId');

    // Create a settings object for position stream
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(_onPositionUpdate);
  }

  /// Stop monitoring
  void stop() {
    _positionSub?.cancel();
    for (var timer in _countdowns.values) {
      timer.cancel();
    }
    _countdowns.clear();
  }

  Future<void> _onPositionUpdate(Position pos) async {
    // fetch nearby stores
    final stores = await _storeService.fetchNearbyStores(
      latitude: pos.latitude,
      longitude: pos.longitude,
      radiusInMeters: 5000,
    );

    for (var store in stores) {
      final dist = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        store.latitude,
        store.longitude,
      );

      if (dist <= _thresholdMeters) {
        // start countdown if not running
        if (!_countdowns.containsKey(store.id)) {
          _countdowns[store.id] = Timer(
            Duration(seconds: _waitSeconds),
            () => _completeVisit(store, pos),
          );
        }
      } else {
        // outside range, cancel any pending timer
        _countdowns.remove(store.id)?.cancel();
      }
    }
  }

  Future<void> _completeVisit(BobaStore store, Position pos) async {
    _countdowns.remove(store.id);

    final userVisitRef = FirebaseDatabase.instance
        .ref('userVisits/$_userId/${store.id}');
    final already = await userVisitRef.get();
    if (already.exists) return;

    await FirebaseDatabase.instance
        .ref('visits/${store.id}/$_userId')
        .set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });

    await FirebaseDatabase.instance
        .ref('stores/${store.city}/${store.id}')
        .runTransaction((data) {
      if (data != null) {
        final map = Map<String, dynamic>.from(data as Map);
        map['visits'] = (map['visits'] ?? 0) + 1;
        return Transaction.success(map);
      }
      return Transaction.success(data);
    });

    await userVisitRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });

    _awardCoin();
  }

  Future<void> _awardCoin() async {
    final snap = await _userRef.child('coins').get();
    final current = snap.exists ? snap.value as int : 0;
    await _userRef.update({'coins': current + 1});
  }
}
