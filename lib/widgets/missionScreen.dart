import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
// Import ThemeProvider (if needed for theme colors in badges)
import 'package:test/services/theme_provider.dart';

class Mission {
  final String title;
  final String description;
  final int goal;    // Target progress for this mission stage
  final int current; // Current progress for this mission stage

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

/// Helper function to convert a store ID (assumed "City_storeX") 
/// into a friendly "City, StateAbbr" string.
/// The maps can be extended as needed.
String shortenStoreName(String storeId) {
  // Extract the city name from the ID.
  String city = storeId.split("_")[0];
  String lowerCity = city.toLowerCase();

  // Map from city (lowercase) to full state.
  Map<String, String> cityToState = {
    "oceanside": "california",
    "sanmarcos": "california",
    "vista": "california",
    // Add more mappings as needed.
  };

  // Map from full state (lowercase) to abbreviation.
  Map<String, String> stateAbbreviations = {
    "california": "CA",
    "arizona": "AZ",
    // Add more states as needed.
  };

  String stateFull = cityToState[lowerCity] ?? "";
  String stateAbbr = stateAbbreviations[stateFull.toLowerCase()] ?? "";
  return "$city, $stateAbbr";
}

/// Updated BadgeSticker with a light-blue, sticker-like design.
/// Uses ThemeProvider colors if needed.
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
    // Parse the timestamp.
    DateTime visitDate = DateTime.tryParse(timestamp) ?? DateTime.now();
    // Format as month/day/year.
    final formattedDate = "${visitDate.month}/${visitDate.day}/${visitDate.year}";
    // Convert the storeId to a friendly label.
    final displayName = shortenStoreName(storeId);

    // Optionally, you can pull colors from the ThemeProvider.
    // For example:
    // final themeProvider = Provider.of<ThemeProvider>(context);
    // Use themeProvider.someColor if defined.

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Light-blue gradient background.
        gradient: const LinearGradient(
          colors: [Color.fromARGB(255, 0, 164, 240), Color(0xFF81D4FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        // Thinner border (adjust as needed) with a light color.
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
            Icon(
              Icons.store,
              size: 18,
              color: Colors.black,
            ),
            const SizedBox(height: 2),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              formattedDate,
              style: const TextStyle(
                fontSize: 7,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// MissionsScreen shows mission progress sequentially.
/// Only the active mission updates (others remain either fully complete or zero).
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

  // Confetti is currently commented out.
  // late ConfettiController _confettiController;
  // bool _hasPlayedConfetti = false;

  @override
  void initState() {
    super.initState();
    // _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _locationCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkLocationAndRegisterVisit();
    });
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    _locationCheckTimer?.cancel();
    // _confettiController.dispose();
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
  List<Mission> buildMissions(int uniqueCount) {
    final List<int> cumulativeGoals = [3, 5, 10, 15, 20];
    List<Mission> missions = [];
    // Determine active mission index: the first goal where uniqueCount < goal.
    int activeIndex = cumulativeGoals.indexWhere((goal) => uniqueCount < goal);
    if (activeIndex == -1) activeIndex = cumulativeGoals.length; // All complete.
    for (int i = 0; i < cumulativeGoals.length; i++) {
      int missionGoal;
      int current;
      if (i == 0) {
        missionGoal = cumulativeGoals[0];
        if (uniqueCount >= cumulativeGoals[0]) {
          current = cumulativeGoals[0];
        } else if (i == activeIndex) {
          current = uniqueCount;
        } else {
          current = 0;
        }
      } else {
        missionGoal = cumulativeGoals[i] - cumulativeGoals[i - 1];
        if (uniqueCount >= cumulativeGoals[i]) {
          current = missionGoal;
        } else if (i == activeIndex) {
          current = uniqueCount - cumulativeGoals[i - 1];
          if (current > missionGoal) current = missionGoal;
        } else {
          current = 0;
        }
      }
      missions.add(Mission(
        title: "Visit ${cumulativeGoals[i]} Boba Stores",
        description: "Visit ${cumulativeGoals[i]} different boba stores to unlock your reward!",
        current: current,
        goal: missionGoal,
      ));
    }
    return missions;
  }

  /// Only the active mission is interactive.
  bool isMissionActive(int missionIndex, int uniqueCount) {
    final List<int> cumulativeGoals = [3, 5, 10, 15, 20];
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
      // Mission is fully complete; overlay a check mark.
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
      // Not active, show lock overlay.
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
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w300)),
        content:
            Text(content, style: const TextStyle(fontWeight: FontWeight.w300)),
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
    print("Missions screen: Listening at userVisits/${widget.userId}");
    return Scaffold(
      appBar: AppBar(
        title:
            const Text("Missions", style: TextStyle(fontWeight: FontWeight.w300)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          StreamBuilder<DatabaseEvent>(
            stream: userVisitsRef.onValue,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                print(
                    "Missions Stream Snapshot: ${snapshot.data!.snapshot.value}");
              } else {
                print("Missions Stream: No data yet.");
              }
              int uniqueCount = 0;
              List<dynamic> visitedStores = [];
              Map<dynamic, dynamic> visitsMap = {};
              if (snapshot.hasData &&
                  snapshot.data!.snapshot.value != null) {
                visitsMap =
                    snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                uniqueCount = visitsMap.keys.length;
                visitedStores = visitsMap.keys.toList();
                print("Found $uniqueCount visits: $visitedStores");
                // Comment out confetti for now:
                // final cumulativeGoals = [3, 5, 10, 15, 20];
                // if (cumulativeGoals.contains(uniqueCount) && !_hasPlayedConfetti) {
                //   _confettiController.play();
                //   _hasPlayedConfetti = true;
                // }
              }
              List<Mission> missions = buildMissions(uniqueCount);
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Visits: $uniqueCount",
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w300)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text("Badges",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w300)),
                              IconButton(
                                icon: const Icon(Icons.help_outline, size: 20),
                                onPressed: () {
                                  showInfoDialog("Badges",
                                      "Badges are sticker-like icons that show the store's city, state, and the date the badge was obtained.");
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 80, // Adjusted for smaller badge size.
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: visitedStores.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            String storeId =
                                visitedStores[index].toString();
                            String timestamp =
                                visitsMap[storeId]["timestamp"] as String? ?? "";
                            return BadgeSticker(
                              storeId: storeId,
                              timestamp: timestamp,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text("Missions",
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w300)),
                              IconButton(
                                icon: const Icon(Icons.help_outline, size: 20),
                                onPressed: () {
                                  showInfoDialog("Missions",
                                      "Missions track your progress in visiting stores sequentially. Only the active mission updates until fully complete; completed missions show a check mark.");
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
          // Commenting out the confetti widget for now.
          // Align(
          //   alignment: Alignment.topCenter,
          //   child: ConfettiWidget(
          //     confettiController: _confettiController,
          //     blastDirectionality: BlastDirectionality.explosive,
          //     shouldLoop: false,
          //     colors: const [
          //       Colors.pink,
          //       Colors.blue,
          //       Colors.orange,
          //       Colors.purple,
          //       Colors.green,
          //     ],
          //   ),
          // ),
        ],
      ),
    );
  }
}
