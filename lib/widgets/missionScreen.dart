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

/// A custom segmented progress indicator that divides available width equally.
/// It shows a row of segments that fill green as progress is made.
class SegmentedProgressIndicator extends StatelessWidget {
  final int current;
  final int goal;
  final double spacing;

  const SegmentedProgressIndicator({
    Key? key,
    required this.current,
    required this.goal,
    this.spacing = 5.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Total width available.
        double totalWidth = constraints.maxWidth;
        double totalSpacing = spacing * (goal - 1);
        double segmentWidth = (totalWidth - totalSpacing) / goal;
        List<Widget> segments = [];
        for (int i = 0; i < goal; i++) {
          segments.add(Container(
            width: segmentWidth,
            height: 12.0,
            decoration: BoxDecoration(
              color: i < current ? Colors.green : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6.0),
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
      },
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
    required this.storeCity,
    required Set<String> scannedStoreIds,
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

  // Check the user's location relative to the store.
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
      // If in range and no visit registered, start a 30-second timer.
      _visitTimer ??= Timer(const Duration(seconds: 30), () async {
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

  /// Build mission objects based on the unique visit count.
  /// Mission 1: Visit 3 stores, Mission 2: Additional 2 visits (total 5), Mission 3: Additional 5 visits (total 10).
  List<Mission> buildMissions(int uniqueCount) {
    int m1Progress = uniqueCount.clamp(0, 3);
    int m2Progress = uniqueCount >= 3 ? (uniqueCount - 3).clamp(0, 2) : 0;
    int m3Progress = uniqueCount >= 5 ? (uniqueCount - 5).clamp(0, 5) : 0;

    return [
      Mission(
        title: "Visit 3 Boba Stores",
        description: "Visit three different boba stores to unlock your reward!",
        current: m1Progress,
        goal: 3,
      ),
      Mission(
        title: "Visit 5 Boba Stores",
        description: "Visit five different boba stores to unlock your bonus!",
        current: m2Progress,
        goal: 5,
      ),
      Mission(
        title: "Visit 10 Boba Stores",
        description: "Visit ten different boba stores for a major reward!",
        current: m3Progress,
        goal: 10,
      ),
    ];
  }

  /// Build a mission card widget with a curved rectangle.
  /// If locked is true, overlay a semi-transparent lock icon.
  Widget buildMissionCard(Mission mission, bool unlocked) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(unlocked ? 1.0 : 0.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mission.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: unlocked ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            mission.description,
            style: TextStyle(
              fontSize: 18,
              color: unlocked ? Colors.black87 : Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          // Ensure progress bar fits relative to card width.
          LayoutBuilder(
            builder: (context, constraints) {
              return SegmentedProgressIndicator(
                current: mission.current,
                goal: mission.goal,
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            mission.current == mission.goal
                ? "Unlocked!"
                : "${mission.current} / ${mission.goal} completed",
            style: TextStyle(
              fontSize: 18,
              color: unlocked ? Colors.black : Colors.grey,
            ),
          ),
        ],
      ),
    );

    if (!unlocked) {
      return Stack(
        children: [
          cardContent,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(
                child: Icon(Icons.lock, size: 40, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    } else {
      return cardContent;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to the user's visit records from Firebase.
    final DatabaseReference userVisitsRef = FirebaseDatabase.instance
        .ref()
        .child("userVisits")
        .child(widget.userId);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Missions"),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: userVisitsRef.onValue,
        builder: (context, snapshot) {
          int uniqueCount = 0;
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> visitsMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            uniqueCount = visitsMap.keys.length;
          }

          List<Mission> missions = buildMissions(uniqueCount);
          // Determine lock state for each mission:
          // Mission 1 is always unlocked.
          bool m1Unlocked = true;
          // Mission 2 unlocked if mission1 complete (uniqueCount >= 3).
          bool m2Unlocked = uniqueCount >= 3;
          // Mission 3 unlocked if mission2 complete (uniqueCount >= 5).
          bool m3Unlocked = uniqueCount >= 5;

          // Build mission cards.
          Widget card1 = buildMissionCard(missions[0], m1Unlocked);
          Widget card2 = buildMissionCard(missions[1], m2Unlocked);
          Widget card3 = buildMissionCard(missions[2], m3Unlocked);

          // Stack the cards so they overlap like pages in a book.
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                height: 350, // Adjust height as needed.
                child: Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // Bottom card (mission 3) - offset further down.
                    Positioned(
                      top: 80,
                      left: 0,
                      right: 0,
                      child: card3,
                    ),
                    // Middle card (mission 2) - offset a bit.
                    Positioned(
                      top: 40,
                      left: 0,
                      right: 0,
                      child: card2,
                    ),
                    // Top card (mission 1) - active mission.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: card1,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
