import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:test/services/theme_provider.dart';

/// Represents a single mission.
class Mission {
  final String title;
  final String description;
  final int goal;
  final int current;
  final int reward;
  final int id; // Unique mission ID for tracking

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
    required this.reward,
  });
}

/// A segmented progress bar that never overflows.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filledColor = isDark ? Colors.blueAccent : Colors.green;
    final emptyColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpacing = spacing * (goal - 1);
        final segmentWidth = (constraints.maxWidth - totalSpacing) / goal;

        return Row(
          children: List.generate(goal * 2 - 1, (index) {
            if (index.isEven) {
              final segmentIndex = index ~/ 2;
              final w = segmentWidth.clamp(0.0, double.infinity);
              return Container(
                width: w,
                height: 8,
                decoration: BoxDecoration(
                  color: (segmentIndex < current) ? filledColor : emptyColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            } else {
              return SizedBox(width: spacing);
            }
          }),
        );
      },
    );
  }
}

/// A flipping badge for historic visits (unchanged from before).
class BadgeCoin extends StatefulWidget {
  final String storeId;
  final String timestamp;
  final double size;

  const BadgeCoin({
    Key? key,
    required this.storeId,
    required this.timestamp,
    this.size = 60,
  }) : super(key: key);

  @override
  _BadgeCoinState createState() => _BadgeCoinState();
}

class _BadgeCoinState extends State<BadgeCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: Duration(milliseconds: 800));
    _animation = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _showFront = !_showFront;
          _controller.reset();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_controller.isAnimating) _controller.forward();
  }

  Map<String, String> _parseStoreId(String storeId) {
    final parts = storeId.split('_');
    final brand = parts.isNotEmpty ? parts[0] : storeId;
    var location = '';
    if (parts.length >= 2) {
      final rawCity = parts[1];
      final city =
          rawCity.replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => ' ${m[0]}');
      final stateMap = {'SanMarcos': 'CA', 'Oceanside': 'CA', 'Vista': 'CA'};
      final state = stateMap[rawCity] ?? '';
      location = '$city, $state';
    }
    return {'brand': brand, 'location': location};
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = _parseStoreId(widget.storeId);
    final date = DateTime.tryParse(widget.timestamp) ?? DateTime.now();
    final formattedDate = DateFormat('MM/dd/yyyy').format(date);

    Widget _buildFace(Widget child) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDark
              ? LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)])
              : LinearGradient(colors: [Color(0xFF81D4FA), Color(0xFF00B0FF)]),
          border: Border.all(
            color: isDark ? Colors.black : Colors.white,
            width: size * 0.025,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 6,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: child,
      );
    }

    final front = _buildFace(
      Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.store,
              size: size * 0.25, color: isDark ? Colors.white : Colors.black),
          SizedBox(height: 4),
          Text(
            info['brand']!,
            style: TextStyle(
              fontSize: size * 0.12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );

    final back = _buildFace(
      Transform(
        alignment: Alignment.center,
        transform: Matrix4.rotationY(pi),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: size * 0.12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 4),
            Text(
              info['location']!,
              style: TextStyle(
                fontSize: size * 0.10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (_, __) {
          final angle = _showFront ? _animation.value : _animation.value + pi;
          final isFront = (_animation.value <= pi / 2) == _showFront;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateY(angle),
            child: isFront ? front : back,
          );
        },
      ),
    );
  }
}

/// The main Missions screen.
class MissionsScreen extends StatefulWidget {
  final String userId;
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
  final double thresholdMeters = 3.05;
  Timer? _locationCheckTimer;

  late final DatabaseReference _coinsRef;
  late final DatabaseReference _rewardsRef;

  Set<int> _alreadyRewarded = {};
  bool _rewardsLoaded = false;

  // We need to know how many **unique** stickers of each tier the user has:
  Set<int> _uniqueStickerIds = {};
  bool _stickersLoaded = false;

  @override
  void initState() {
    super.initState();

    _coinsRef = FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.userId)
        .child('coins');
    _rewardsRef = FirebaseDatabase.instance
        .ref()
        .child('userMissionRewards')
        .child(widget.userId);

    // ─── Load existing mission rewards first ─────────────────────────────
    _rewardsRef.get().then((snap) {
  if (!mounted) return;
  if (snap.exists) {
    final raw = snap.value;
    final Map<String, dynamic> dataMap = {};
    if (raw is Map) {
      dataMap.addAll(Map<String, dynamic>.from(raw));
    } else if (raw is List) {
      // If snap.value came back as a List<dynamic>, convert it into a Map by index
      for (int i = 0; i < raw.length; i++) {
        final element = raw[i];
        if (element is Map) {
          dataMap['$i'] = Map<String, dynamic>.from(element);
        }
      }
    }
    setState(() {
      _alreadyRewarded = dataMap.keys
          .map((k) => int.tryParse(k) ?? -1)
          .where((i) => i >= 0)
          .toSet();
      _rewardsLoaded = true;
    });
  } else {
    setState(() {
      _rewardsLoaded = true;
    });
  }
});


    // ─── Load all unique sticker IDs for this user ─────────────────────────
    FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(widget.userId)
        .child('stickers')
        .get()
        .then((snap) {
      if (!mounted) return;
      final ids = <int>{};
      final raw = snap.value;

      if (raw is Map) {
        // Typical “Map<String, dynamic>” case:
        final dataMap = Map<String, dynamic>.from(raw);
        for (var entry in dataMap.values) {
          if (entry is Map) {
            final asset = entry['asset'] as String?;
            if (asset != null) {
              final m = RegExp(r'sticker(\d+)\.png').firstMatch(asset);
              if (m != null) {
                ids.add(int.parse(m.group(1)!));
              }
            }
          }
        }
      } else if (raw is List) {
        // When Firebase returned a List<dynamic> instead of a Map:
        for (var element in raw) {
          if (element is Map) {
            final asset = element['asset'] as String?;
            if (asset != null) {
              final m = RegExp(r'sticker(\d+)\.png').firstMatch(asset);
              if (m != null) {
                ids.add(int.parse(m.group(1)!));
              }
            }
          }
        }
      }
      setState(() {
        _uniqueStickerIds = ids;
        _stickersLoaded = true;
      });
    });

    // ─── Start periodic location checks ─────────────────────────────
    _locationCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkLocation(),
    );
  }

  @override
  void dispose() {
    _visitTimer?.cancel();
    _locationCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocation() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return;
    }
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.storeLatitude,
      widget.storeLongitude,
    );

    if (dist <= thresholdMeters && !_visitRegistered) {
      _visitTimer ??= Timer(const Duration(seconds: 30), () async {
        final updated = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        final updatedDist = Geolocator.distanceBetween(
          updated.latitude,
          updated.longitude,
          widget.storeLatitude,
          widget.storeLongitude,
        );
        if (updatedDist <= thresholdMeters) {
          await _registerVisit(updated);
          setState(() => _visitRegistered = true);
        }
        _visitTimer = null;
      });
    } else {
      _visitTimer?.cancel();
      _visitTimer = null;
    }
  }

  Future<void> _registerVisit(Position pos) async {
    final visitsRef = FirebaseDatabase.instance
        .ref()
        .child('userVisits')
        .child(widget.userId)
        .child(widget.storeId);
    final snap = await visitsRef.get();
    if (!snap.exists) {
      await visitsRef.set({
        'timestamp': DateTime.now().toIso8601String(),
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      });
      final storeRef = FirebaseDatabase.instance
          .ref()
          .child('stores')
          .child(widget.storeCity)
          .child(widget.storeId);
      await storeRef.runTransaction((data) {
        if (data != null) {
          final map = Map<String, dynamic>.from(data as Map);
          map['visits'] = (map['visits'] ?? 0) + 1;
          return Transaction.success(map);
        }
        return Transaction.success(data);
      });
    }
  }

  /// Builds a combined mission list (visits + sticker collections).
  List<Mission> buildAllMissions(int uniqueStoreVisits) {
    // 1) “Visit X Boba Stores” missions (same as before):
    final visitGoals = [3, 5, 10, 15, 20];
    final List<Mission> visitMissions = [];
    for (var i = 0; i < visitGoals.length; i++) {
      final goal = visitGoals[i];
      final current =
          min(uniqueStoreVisits, goal); // cap at goal for progress bar
      visitMissions.add(Mission(
        id: i, // 0..4
        title: 'Visit $goal Boba Stores',
        description: 'Visit $goal different boba stores to unlock reward.',
        current: current,
        goal: goal,
        reward: 5 * (i + 1),
      ));
    }

    // 2) Sticker‐collection missions:
    //    bronze IDs: 1–24, silver: 25–35, gold: 36–50.
    final bronzeIds =
        _uniqueStickerIds.where((id) => id >= 1 && id <= 24).toSet();
    final silverIds =
        _uniqueStickerIds.where((id) => id >= 25 && id <= 35).toSet();
    final goldIds =
        _uniqueStickerIds.where((id) => id >= 36 && id <= 50).toSet();

    final bronzeCount = bronzeIds.length;
    final silverCount = silverIds.length;
    final goldCount = goldIds.length;

    final List<Mission> stickerMissions = [
      // Bronze:
      Mission(
        id: 100,
        title: 'Collect 5 Bronze Stickers',
        description: 'Collect 5 distinct bronze‐tier stickers (IDs 1–24).',
        current: min(bronzeCount, 5),
        goal: 5,
        reward: 5,
      ),
      Mission(
        id: 101,
        title: 'Collect 10 Bronze Stickers',
        description: 'Collect 10 distinct bronze‐tier stickers (IDs 1–24).',
        current: min(bronzeCount, 10),
        goal: 10,
        reward: 10,
      ),
      Mission(
        id: 102,
        title: 'Complete Bronze Collection',
        description:
            'Collect all 24 bronze‐tier stickers (IDs 1–24) to fully complete.',
        current: bronzeCount,
        goal: 24,
        reward: 20,
      ),

      // Silver:
      Mission(
        id: 200,
        title: 'Collect 5 Silver Stickers',
        description: 'Collect 5 distinct silver‐tier stickers (IDs 25–35).',
        current: min(silverCount, 5),
        goal: 5,
        reward: 10,
      ),
      Mission(
        id: 201,
        title: 'Collect 10 Silver Stickers',
        description: 'Collect 10 distinct silver‐tier stickers (IDs 25–35).',
        current: min(silverCount, 10),
        goal: 10,
        reward: 15,
      ),
      Mission(
        id: 202,
        title: 'Complete Silver Collection',
        description:
            'Collect all 11 silver‐tier stickers (IDs 25–35) to fully complete.',
        current: silverCount,
        goal: 11,
        reward: 30,
      ),

      // Gold:
      Mission(
        id: 300,
        title: 'Collect 5 Gold Stickers',
        description: 'Collect 5 distinct gold‐tier stickers (IDs 36–50).',
        current: min(goldCount, 5),
        goal: 5,
        reward: 20,
      ),
      Mission(
        id: 301,
        title: 'Collect 10 Gold Stickers',
        description: 'Collect 10 distinct gold‐tier stickers (IDs 36–50).',
        current: min(goldCount, 10),
        goal: 10,
        reward: 30,
      ),
      Mission(
        id: 302,
        title: 'Complete Gold Collection',
        description:
            'Collect all 15 gold‐tier stickers (IDs 36–50) to fully complete.',
        current: goldCount,
        goal: 15,
        reward: 50,
      ),
    ];

    // Combine visits + all sticker missions:
    return [...visitMissions, ...stickerMissions];
  }

  /// Returns true if the mission at index [idx] is the “active next” mission.
  /// We treat “active” as the first mission (in list order) that is not yet fully completed.
  bool isMissionActive(int idx, List<Mission> allMissions) {
    // Find first incomplete mission:
    final firstIncompleteIndex =
        allMissions.indexWhere((m) => m.current < m.goal);
    if (firstIncompleteIndex == -1) return false; // all done
    return idx == firstIncompleteIndex;
  }

  /// Only show up to 4 missions: any that are “completed” or the next “active” mission.
  List<Mission> filterVisibleMissions(List<Mission> allMissions) {
    final visible = <Mission>[];

    // 1) Include all already‐completed missions (so user sees their checks) → up to 4
    for (var m in allMissions) {
      if (m.current >= m.goal && visible.length < 4) {
        visible.add(m);
      }
    }

    // 2) If fewer than 4, add the next “active” mission
    if (visible.length < 4) {
      final firstIncompleteIndex =
          allMissions.indexWhere((m) => m.current < m.goal);
      if (firstIncompleteIndex != -1) {
        visible.add(allMissions[firstIncompleteIndex]);
      }
    }

    // 3) If still fewer than 4, fill up with subsequent incomplete missions
    var idx = allMissions.indexWhere((m) => m.current < m.goal) + 1;
    while (visible.length < 4 && idx < allMissions.length) {
      visible.add(allMissions[idx]);
      idx++;
    }

    return visible;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uniqueRef = FirebaseDatabase.instance
        .ref()
        .child('userVisits')
        .child(widget.userId);
    final totalRef = FirebaseDatabase.instance
        .ref()
        .child('userStoreVisits')
        .child(widget.userId);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Missions'),
        centerTitle: true,
      ),
      body: (_rewardsLoaded && _stickersLoaded)
          ? StreamBuilder<DatabaseEvent>(
              stream: uniqueRef.onValue,
              builder: (ctx, uniqueSnap) {
                int uniqueCount = 0;
                if (uniqueSnap.hasData &&
                    uniqueSnap.data!.snapshot.value != null) {
                  final uniqueMap =
                      uniqueSnap.data!.snapshot.value as Map<dynamic, dynamic>;
                  uniqueCount = uniqueMap.keys.length;
                }
                // Build the full mission list:
                final allMissions = buildAllMissions(uniqueCount);
                // Determine which are visible:
                final visibleMissions = filterVisibleMissions(allMissions);

                return StreamBuilder<DatabaseEvent>(
                  stream: totalRef.onValue,
                  builder: (ctx2, totalSnap) {
                    // We don’t actually need total visits here; we already used uniqueCount.
                    // But keep this builder so we trigger checks & rewards.
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_rewardsLoaded) {
                        _checkAndAwardRewards(allMissions);
                      }
                    });

                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unique Visits: $uniqueCount',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w300,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Badges',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w200,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Show all earned “visit” badges:
                          StreamBuilder<DatabaseEvent>(
                            stream: uniqueRef.onValue,
                            builder: (ctx3, badgeSnap) {
                              final badges = <Widget>[];
                              if (badgeSnap.hasData &&
                                  badgeSnap.data!.snapshot.value != null) {
                                final uniqueMap = badgeSnap.data!.snapshot.value
                                    as Map<dynamic, dynamic>;
                                uniqueMap.forEach((sid, data) {
                                  final ts =
                                      (data as Map)['timestamp'] as String? ??
                                          '';
                                  badges.add(BadgeCoin(
                                    storeId: sid.toString(),
                                    timestamp: ts,
                                    size: 60,
                                  ));
                                });
                              }
                              return GridView.count(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                children: badges,
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Missions',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w300,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.help_outline,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black54),
                                onPressed: () => _showInfo('Missions',
                                    'Complete the tasks below to earn coins.\nOnly up to four appear at once.'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleMissions.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (ctx, idx) {
                              final m = visibleMissions[idx];
                              final indexInAll = buildAllMissions(uniqueCount)
                                  .indexWhere((x) => x.id == m.id);
                              final active = isMissionActive(
                                  indexInAll, buildAllMissions(uniqueCount));
                              return _buildMissionRow(m, active);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildMissionRow(Mission m, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2E004F) : Colors.white;
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey : Colors.grey.shade600);

    final lockIcon = Icon(Icons.lock,
        size: 40, color: isDark ? Colors.black54 : Colors.grey.shade400);
    final checkIcon = Icon(Icons.check,
        size: 40, color: isDark ? Colors.blueAccent : Colors.green);

    Widget row = Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Image.asset('assets/coin_boba.png',
                          width: 16, height: 16),
                      const SizedBox(width: 4),
                      Text(
                        '+${m.reward}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    m.description,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w300,
                      color: textColor,
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
                    current: m.current,
                    goal: m.goal,
                    spacing: 4,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${m.current}/${m.goal}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (m.current >= m.goal) {
      row = Stack(
        children: [
          row,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: checkIcon),
            ),
          ),
        ],
      );
    } else if (!active) {
      row = Stack(
        children: [
          row,
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(child: lockIcon),
            ),
          ),
        ],
      );
    } else {
      row = InkWell(
        onTap: () => _showInfo(m.title, m.description),
        child: row,
      );
    }

    return row;
  }

  void _showInfo(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          )
        ],
      ),
    );
  }

  /// Award rewards for any newly‐completed missions.
  Future<void> _checkAndAwardRewards(List<Mission> allMissions) async {
    for (var m in allMissions) {
      if (m.current >= m.goal && !_alreadyRewarded.contains(m.id)) {
        final reward = m.reward;
        final coinSnap = await _coinsRef.get();
        final currentCoins = (coinSnap.value as int?) ?? 0;
        await _coinsRef.set(currentCoins + reward);
        await _rewardsRef.child(m.id.toString()).set({
          'reward': reward,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _alreadyRewarded.add(m.id);
      }
    }
  }
}
