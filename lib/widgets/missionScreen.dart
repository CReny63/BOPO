import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class Mission {
  final String title;
  final String description;
  final int goal;
  final int current;

  const Mission({
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
  });
}

/// A custom segmented progress indicator that displays a row of segments.
/// Each segment fills (green) if the corresponding visit has been recorded.
class SegmentedProgressIndicator extends StatelessWidget {
  final int current;
  final int goal;
  final double segmentWidth;
  final double segmentHeight;
  final double spacing;

  const SegmentedProgressIndicator({
    Key? key,
    required this.current,
    required this.goal,
    this.segmentWidth = 30.0,
    this.segmentHeight = 10.0,
    this.spacing = 4.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<Widget> segments = [];
    for (int i = 0; i < goal; i++) {
      segments.add(Container(
        width: segmentWidth,
        height: segmentHeight,
        decoration: BoxDecoration(
          color: i < current ? Colors.green : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4.0),
        ),
      ));
      if (i < goal - 1) {
        segments.add(SizedBox(width: spacing));
      }
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: segments,
    );
  }
}

class MissionsScreen extends StatefulWidget {
  final String userId;
  final String storeId;
  final double storeLatitude;
  final double storeLongitude;
  final String storeCity;

  const MissionsScreen({
    Key? key,
    required this.userId,
    required this.storeId,
    required this.storeLatitude,
    required this.storeLongitude,
    required this.storeCity, required Set<String> scannedStoreIds,
  }) : super(key: key);

  @override
  _MissionsScreenState createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> {
  Timer? _visitTimer;
  bool _visitRegistered = false;
  final double thresholdMeters = 3.05; // ~10 feet
  Timer? _locationCheckTimer;

  @override
  void initState() {
    super.initState();
    // Check location periodically (every 5 seconds)
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkLocationAndRegisterVisit();
    });
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  // Check the user's current location relative to the store.
  void _checkLocationAndRegisterVisit() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      print("Error obtaining position: $e");
      return;
    }

    double distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      widget.storeLatitude,
      widget.storeLongitude,
    );

    if (distance <= thresholdMeters && !_visitRegistered) {
      // User is in range and no visit registered yet.
      if (_visitTimer == null) {
        _visitTimer = Timer(const Duration(seconds: 30), () async {
          // After 30 seconds, check again.
          Position updatedPosition;
          try {
            updatedPosition = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high);
          } catch (e) {
            print("Error obtaining updated position: $e");
            _visitTimer = null;
            return;
          }
          double updatedDistance = Geolocator.distanceBetween(
            updatedPosition.latitude,
            updatedPosition.longitude,
            widget.storeLatitude,
            widget.storeLongitude,
          );
          if (updatedDistance <= thresholdMeters) {
            // Still in range after 30 seconds: register the visit.
            await _registerVisit(updatedPosition);
            setState(() {
              _visitRegistered = true;
            });
          }
          _visitTimer = null;
        });
      }
    } else {
      // If user moves out of range, cancel any pending timer.
      if (_visitTimer != null) {
        _visitTimer!.cancel();
        _visitTimer = null;
      }
    }
  }

  // Register the visit in Firebase.
  Future<void> _registerVisit(Position position) async {
    final DatabaseReference visitsRef = FirebaseDatabase.instance
        .ref()
        .child('userVisits')
        .child(widget.userId)
        .child(widget.storeId);

    final DataSnapshot snapshot = await visitsRef.get();
    if (!snapshot.exists) {
      await visitsRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': position.latitude,
        'longitude': position.longitude,
      });

      // Optionally update the store's overall visit count.
      final DatabaseReference storeRef = FirebaseDatabase.instance
          .ref()
          .child('stores')
          .child(widget.storeCity)
          .child(widget.storeId);
      await storeRef.runTransaction((mutableData) async {
        if (mutableData.value != null) {
          Map data = Map.from(mutableData.value as Map);
          int currentVisits = data['visits'] ?? 0;
          data['visits'] = currentVisits + 1;
          mutableData.value = data;
        }
        return mutableData;
      } as TransactionHandler);
      print("Visit registered for store ${widget.storeId}");
    }
  }

  // We only show the first mission: "Visit 3 Boba Stores"
  List<Mission> getMissions(int uniqueCount) {
    return [
      Mission(
        title: "Visit 3 Boba Stores",
        description: "Visit three different boba stores to unlock your reward!",
        current: uniqueCount >= 3 ? 3 : uniqueCount,
        goal: 3,
      )
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Listen to visit records from Firebase.
    final DatabaseReference userVisitsRef =
        FirebaseDatabase.instance.ref().child("userVisits").child(widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Missions"),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: userVisitsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
            return const Center(child: Text("No visits recorded yet."));
          }
          final Map<dynamic, dynamic> visitsMap =
              snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final int uniqueCount = visitsMap.keys.length;
          final missions = getMissions(uniqueCount);
          // For our UI, we only have one mission.
          final Mission mission = missions.first;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  mission.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  mission.description,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                // Display the segmented progress indicator
                SegmentedProgressIndicator(
                  current: mission.current,
                  goal: mission.goal,
                ),
                const SizedBox(height: 10),
                Text(
                  mission.current == mission.goal
                      ? "Unlocked!"
                      : "${mission.current} / ${mission.goal} visited",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
