import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'package:test/services/theme_provider.dart';

class Mission {
  final String title;
  final String description;
  final int goal;    // The cumulative target (e.g. 3, 5, 10,...)
  final int current; // Current progress for the mission

  const Mission({
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
  });
}

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
        if (i < goal - 1) segments.add(SizedBox(width: spacing));
      }
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: segments,
      );
    });
  }
}

/// Helper: Given a storeId in the form "ShareTea_SanMarcos", this function extracts:
/// - brand: "ShareTea"
/// - location: "San Marcos, CA" (using a simple mapping)
Map<String, String> getStoreDisplayInfo(String storeId) {
  List<String> parts = storeId.split('_');
  String brand = parts.isNotEmpty ? parts[0] : storeId;
  String location = "";
  if (parts.length >= 2) {
    String cityRaw = parts[1];
    // Insert a space before capital letters (e.g., "SanMarcos" -> "San Marcos")
    String formattedCity = cityRaw.replaceAllMapped(RegExp(r'(?<!^)([A-Z])'),
        (Match m) => " ${m.group(0)}");
    // Map for state abbreviations.
    Map<String, String> cityToState = {
      "SanMarcos": "CA",
      "Oceanside": "CA",
      "Vista": "CA",
      // Extend with more mappings as needed.
    };
    String state = cityToState[parts[1]] ?? "";
    location = "$formattedCity, $state";
  }
  return {"brand": brand, "location": location};
}

/// BadgeSticker uses your original light-blue, circular design.
/// It now displays the store brand, location, and the date visited.
class BadgeSticker extends StatelessWidget {
  final String storeId;
  final String timestamp;

  const BadgeSticker({
    Key? key,
    required this.storeId,
    required this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Parse and format the timestamp.
    DateTime visitDate = DateTime.tryParse(timestamp) ?? DateTime.now();
    final formattedDate = "${visitDate.month}/${visitDate.day}/${visitDate.year}";
    final info = getStoreDisplayInfo(storeId);
    String brand = info["brand"]!;
    String location = info["location"]!;

    return Container(
      width: 70,
      height: 90,  // Increased height for the additional date text.
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 0, 164, 240), Color(0xFF81D4FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color.fromARGB(255, 156, 193, 225),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 4,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Transform.rotate(
        angle: 0.05,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store, size: 18, color: Colors.black),
            const SizedBox(height: 2),
            Text(
              brand,
              style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              location,
              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: const TextStyle(fontSize: 7, fontWeight: FontWeight.w300, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// MissionsScreen: Displays badges and missions.
/// Only the active mission (the first incomplete one) updates with progress.
/// All other missions show 0 progress until the previous is complete.
class MissionsScreen extends StatefulWidget {
  final String userId; // UID from FirebaseAuth.
  final String storeId;
  final double storeLatitude;
  final double storeLongitude;
  final String storeCity;
  final Set<String> scannedStoreIds;
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

  void _checkLocationAndRegisterVisit() async {
    Position currentPosition;
    try {
      currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
          updatedPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
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
      await storeRef.runTransaction((currentData) {
        if (currentData != null) {
          Map data = Map.from(currentData as Map);
          int currentVisits = data['visits'] ?? 0;
          data['visits'] = currentVisits + 1;
          return Transaction.success(data);
        }
        return Transaction.success(currentData);
      });
    }
  }

  /// Build missions sequentially using cumulative targets.
  /// Only the current active mission updates with partial progress;
  /// the others remain at 0 until their turn.
  List<Mission> buildMissions(int uniqueCount) {
    List<int> cumulativeGoals = [3, 5, 10, 15, 20];
    // Determine the active mission: first goal where uniqueCount is less than the cumulative goal.
    int activeIndex = cumulativeGoals.indexWhere((goal) => uniqueCount < goal);
    if (activeIndex == -1) activeIndex = cumulativeGoals.length; // All complete.
    List<Mission> missions = [];
    for (int i = 0; i < cumulativeGoals.length; i++) {
      int missionTarget = cumulativeGoals[i];
      int prevTotal = i == 0 ? 0 : cumulativeGoals[i - 1];
      int current = 0;
      if (i < activeIndex) {
        // Mission already completed.
        current = missionTarget;
      } else if (i == activeIndex) {
        // Active mission: update based on visits beyond previous cumulative target.
        current = uniqueCount - prevTotal;
        if (current < 0) current = 0;
      } else {
        // Future missions remain 0.
        current = 0;
      }
      missions.add(Mission(
        title: "Visit $missionTarget Boba Stores",
        description: "Visit $missionTarget different boba stores to unlock your reward!",
        current: current,
        goal: missionTarget,
      ));
    }
    return missions;
  }

  /// Only the active mission is interactive (tappable for details).
  bool isMissionActive(int missionIndex, int uniqueCount) {
    List<int> cumulativeGoals = [3, 5, 10, 15, 20];
    int activeIndex = cumulativeGoals.indexWhere((goal) => uniqueCount < goal);
    if (activeIndex == -1) activeIndex = cumulativeGoals.length;
    return missionIndex == activeIndex;
  }

  void showMissionDetails(Mission mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mission.title, style: const TextStyle(fontWeight: FontWeight.w300)),
        content: Text(
          '${mission.description}\n\nProgress: ${mission.current}/${mission.goal}',
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

  Widget buildMissionRow(Mission mission, bool active) {
    Widget missionRow = Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
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
                      color: active ? Colors.black : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mission.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: active ? Colors.black87 : Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  SegmentedProgressIndicator(
                      current: mission.current, goal: mission.goal, spacing: 4),
                  const SizedBox(height: 4),
                  Text(
                    "${mission.current}/${mission.goal}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: active ? Colors.black : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (mission.current == mission.goal) {
      // Mission complete: overlay a check mark.
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
                child: Icon(Icons.check, size: 40, color: Colors.green),
              ),
            ),
          ),
        ],
      );
    } else if (!active) {
      // Inactive mission: overlay a lock.
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
      // Active mission is tappable.
      missionRow = InkWell(
        onTap: () => showMissionDetails(mission),
        child: missionRow,
      );
    }
    return missionRow;
  }

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
    final DatabaseReference userVisitsRef =
        FirebaseDatabase.instance.ref().child("userVisits").child(widget.userId);
    print("Missions screen: Listening at userVisits/${widget.userId}");
    return Scaffold(
      appBar: AppBar(
        title: const Text("Missions", style: TextStyle(fontWeight: FontWeight.w300)),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: userVisitsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            print("Missions Stream Snapshot: ${snapshot.data!.snapshot.value}");
          } else {
            print("Missions Stream: No data yet.");
          }
          int uniqueCount = 0;
          List<dynamic> visitedStores = [];
          Map<dynamic, dynamic> visitsMap = {};
          if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
            visitsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            uniqueCount = visitsMap.keys.length;
            visitedStores = visitsMap.keys.toList();
            print("Found $uniqueCount visits: $visitedStores");
          }
          List<Mission> missions = buildMissions(uniqueCount);
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Visits: $uniqueCount",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w300)),
                  const SizedBox(height: 16),
                  // Badges header with info button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text("Badges",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            onPressed: () {
                              showInfoDialog("Badges",
                                  "Badges are sticker-like icons that show the store's name, location, and the date you visited.");
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: visitedStores.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        String storeId = visitedStores[index].toString();
                        String timestamp = visitsMap[storeId]["timestamp"] as String? ?? "";
                        return BadgeSticker(
                          storeId: storeId,
                          timestamp: timestamp,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Missions header with info button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text("Missions",
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w300)),
                          IconButton(
                            icon: const Icon(Icons.help_outline, size: 20),
                            onPressed: () {
                              showInfoDialog("Missions",
                                  "Missions track your sequential progress. Only the current active mission updates its progress until it is complete. The remaining missions show the full target (e.g., 5 stores) with 0 progress until activated.");
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
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      bool active = isMissionActive(index, uniqueCount);
                      return buildMissionRow(missions[index], active);
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
