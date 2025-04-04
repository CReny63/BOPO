import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/services/theme_provider.dart';

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

/// A segmented progress indicator that fills segments as progress is made.
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
          height: 8.0,
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
    });
  }
}

/// A badge sticker widget for displaying a visited store.
class BadgeSticker extends StatelessWidget {
  final String storeId;

  const BadgeSticker({Key? key, required this.storeId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store, size: 32, color: Theme.of(context).primaryColor),
          const SizedBox(height: 4),
          Text(
            storeId.length >= 4 ? storeId.substring(0, 4) : storeId,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w300),
          ),
          const Text(
            "Visited",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w300),
          ),
        ],
      ),
    );
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
    return [
      Mission(
        title: "Visit 3 Boba Stores",
        description: "Visit three different boba stores to unlock your reward!",
        current: uniqueCount.clamp(0, 3),
        goal: 3,
      ),
      Mission(
        title: "Visit 5 Boba Stores",
        description: "Visit five different boba stores to unlock your bonus!",
        current: uniqueCount.clamp(0, 5),
        goal: 5,
      ),
      Mission(
        title: "Visit 10 Boba Stores",
        description: "Visit ten different boba stores for a major reward!",
        current: uniqueCount.clamp(0, 10),
        goal: 10,
      ),
      Mission(
        title: "Visit 15 Boba Stores",
        description: "Visit fifteen boba stores to unlock an even bigger bonus!",
        current: uniqueCount.clamp(0, 15),
        goal: 15,
      ),
      Mission(
        title: "Visit 20 Boba Stores",
        description: "Visit twenty boba stores for the ultimate reward!",
        current: uniqueCount.clamp(0, 20),
        goal: 20,
      ),
    ];
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

  /// Shows mission details in a dialog.
  void showMissionDetails(Mission mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          mission.title,
          style: const TextStyle(fontWeight: FontWeight.w300),
        ),
        content: Text(
          mission.description +
              "\n\nProgress: ${mission.current}/${mission.goal}",
          style: const TextStyle(fontWeight: FontWeight.w300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  /// Build a mission row widget with a clean, modern look.
  Widget buildMissionRow(Mission mission, bool unlocked) {
    Widget missionRow = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: unlocked ? Colors.white : Colors.grey.shade200,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Mission details.
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: unlocked ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: unlocked ? Colors.black87 : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Progress indicator.
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  SegmentedProgressIndicator(
                    current: mission.current,
                    goal: mission.goal,
                    spacing: 4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${mission.current}/${mission.goal}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: unlocked ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // If mission is locked, overlay a lock icon.
    if (!unlocked) {
      missionRow = Stack(
        children: [
          missionRow,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.lock, size: 40, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    } else {
      // If unlocked, allow tap for more details.
      missionRow = InkWell(
        onTap: () => showMissionDetails(mission),
        child: missionRow,
      );
    }
    return missionRow;
  }

  /// Show informational dialog for Badges or Missions.
  void showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w300)),
        content: Text(content, style: const TextStyle(fontWeight: FontWeight.w300)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Got it"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final DatabaseReference userVisitsRef = FirebaseDatabase.instance
        .ref()
        .child("userVisits")
        .child(widget.userId);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Missions", style: TextStyle(fontWeight: FontWeight.w300)),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: userVisitsRef.onValue,
        builder: (context, snapshot) {
          int uniqueCount = 0;
          List<dynamic> visitedStores = [];
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            final Map<dynamic, dynamic> visitsMap =
                snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            uniqueCount = visitsMap.keys.length;
            visitedStores = visitsMap.keys.toList();
          }
          List<Mission> missions = buildMissions(uniqueCount);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Total Visits Count.
                  Text(
                    "Total Visits: $uniqueCount",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Badges section header with info button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Badges",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            onPressed: () {
                              showInfoDialog("Badges", "Badges are sticker-like icons that show each store you’ve visited.");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visitedStores.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        String storeId = visitedStores[index].toString();
                        return BadgeSticker(storeId: storeId);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Missions section header with info button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Missions",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            onPressed: () {
                              showInfoDialog("Missions", "Missions track your progress in visiting different stores. Tap on an active mission to see full details.");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: missions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      bool unlocked = isMissionUnlocked(index, uniqueCount);
                      return buildMissionRow(missions[index], unlocked);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
