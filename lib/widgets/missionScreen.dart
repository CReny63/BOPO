import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/services/theme_provider.dart'; // Your ThemeProvider

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
    return LayoutBuilder(builder: (context, constraints) {
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
    });
  }
}

class MissionsScreen extends StatefulWidget {
  final String userId;
  final String storeId;
  final double storeLatitude;
  final double storeLongitude;
  final String storeCity;
  final Set<String> scannedStoreIds; // if needed
  final ThemeProvider themeProvider;

  const MissionsScreen({
    Key? key,
    required this.userId,
    required this.storeId,
    required this.storeLatitude,
    required this.storeLongitude,
    required this.storeCity,
    required this.scannedStoreIds,
    required this.themeProvider,
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
    // Check location every 5 seconds.
    _locationCheckTimer =
        Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkLocationAndRegisterVisit();
    });
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

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
          await _registerVisit(updatedPosition);
          setState(() {
            _visitRegistered = true;
          });
        }
        _visitTimer = null;
      });
    } else {
      if (_visitTimer != null) {
        _visitTimer!.cancel();
        _visitTimer = null;
      }
    }
  }

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

  /// Build five mission objects with cumulative thresholds.
  List<Mission> buildMissions(int uniqueCount) {
    Mission m1 = Mission(
      title: "Visit 3 Boba Stores",
      description:
          "Visit three different boba stores to unlock your reward!",
      current: uniqueCount.clamp(0, 3),
      goal: 3,
    );
    Mission m2 = Mission(
      title: "Visit 5 Boba Stores",
      description:
          "Visit five different boba stores to unlock your bonus!",
      current: uniqueCount.clamp(0, 5),
      goal: 5,
    );
    Mission m3 = Mission(
      title: "Visit 10 Boba Stores",
      description:
          "Visit ten different boba stores for a major reward!",
      current: uniqueCount.clamp(0, 10),
      goal: 10,
    );
    Mission m4 = Mission(
      title: "Visit 15 Boba Stores",
      description:
          "Visit fifteen boba stores to unlock an even bigger bonus!",
      current: uniqueCount.clamp(0, 15),
      goal: 15,
    );
    Mission m5 = Mission(
      title: "Visit 20 Boba Stores",
      description:
          "Visit twenty boba stores for the ultimate reward!",
      current: uniqueCount.clamp(0, 20),
      goal: 20,
    );
    return [m1, m2, m3, m4, m5];
  }

  /// Determines if a mission is unlocked.
  bool isMissionUnlocked(int missionIndex, int uniqueCount) {
    if (missionIndex == 0) return true;
    if (missionIndex == 1) return uniqueCount >= 3;
    if (missionIndex == 2) return uniqueCount >= 5;
    if (missionIndex == 3) return uniqueCount >= 10;
    if (missionIndex == 4) return uniqueCount >= 15;
    return false;
  }

  /// Build a mission card widget with a curved rectangle.
  /// If locked, overlay a semi-transparent lock icon.
  Widget buildMissionCard(Mission mission, bool unlocked) {
    TextStyle titleStyle = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: unlocked
          ? Theme.of(context).textTheme.titleLarge?.color ?? Colors.black
          : Colors.grey,
    );
    TextStyle descStyle = TextStyle(
      fontSize: 18,
      color: unlocked
          ? Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black87
          : Colors.grey,
    );
    TextStyle progressStyle = TextStyle(
      fontSize: 18,
      color: unlocked
          ? Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black
          : Colors.grey,
    );
    Widget cardContent = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: unlocked
            ? Theme.of(context).cardColor
            : Theme.of(context).cardColor.withOpacity(0.5),
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
          Text(mission.title, style: titleStyle),
          const SizedBox(height: 12),
          Text(mission.description,
              style: descStyle, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          SegmentedProgressIndicator(
            current: mission.current,
            goal: mission.goal,
          ),
          const SizedBox(height: 16),
          Text(
            mission.current == mission.goal
                ? "Unlocked!"
                : "${mission.current} / ${mission.goal} completed",
            style: progressStyle,
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
          if (snapshot.hasData &&
              snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> visitsMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            uniqueCount = visitsMap.keys.length;
          }
          List<Mission> missions = buildMissions(uniqueCount);
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: missions.length,
            itemBuilder: (context, i) {
              bool unlocked = isMissionUnlocked(i, uniqueCount);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: buildMissionCard(missions[i], unlocked),
              );
            },
          );
        },
      ),
    );
  }
}
