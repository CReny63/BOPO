import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:test/services/theme_provider.dart';
import 'package:google_fonts/google_fonts.dart';

class Mission {
  final String title;
  final String description;
  final int goal;
  final int current;
  final int reward;
  final int id;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
    required this.reward,
  });

  factory Mission.fromJson(Map<String, dynamic> json) => Mission(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        current: json['current'],
        goal: json['goal'],
        reward: json['reward'],
      );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filledColor = isDark ? Colors.blueAccent : Colors.green;
    final emptyColor = isDark ? Colors.grey.shade700 : Colors.grey.shade300;

    // 🔁 Use progress bar if there are too many segments
    if (goal > 10) {
      final progress = current / goal;
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          minHeight: 8,
          valueColor: AlwaysStoppedAnimation<Color>(filledColor),
          backgroundColor: emptyColor,
        ),
      );
    }

    // 🔲 Otherwise use segmented dots
    return LayoutBuilder(builder: (context, constraints) {
      final available = constraints.maxWidth;
      double usedSpacing = spacing;
      double rawSegment = (available - spacing * (goal - 1)) / goal;
      if (rawSegment < 0) {
        usedSpacing = 0;
        rawSegment = available / goal;
      }
      final segW = rawSegment.clamp(0.0, double.infinity);
      return Row(
        children: List.generate(goal * 2 - 1, (i) {
          if (i.isEven) {
            final idx = i ~/ 2;
            return Container(
              width: segW,
              height: 8,
              decoration: BoxDecoration(
                color: idx < current ? filledColor : emptyColor,
                borderRadius: BorderRadius.circular(4),
              ),
            );
          } else {
            return SizedBox(width: usedSpacing);
          }
        }),
      );
    });
  }
}


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
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
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
              ? const LinearGradient(colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)])
              : const LinearGradient(colors: [Color(0xFF81D4FA), Color(0xFF00B0FF)]),
          border: Border.all(
            color: isDark ? Colors.black : Colors.white,
            width: size * 0.025,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 6,
              offset: const Offset(2, 3),
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
          Icon(Icons.store, size: size * 0.25, color: isDark ? Colors.white : Colors.black),
          const SizedBox(height: 4),
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
            const SizedBox(height: 4),
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
  // Timer? _visitTimer;
  // bool _visitRegistered = false;
  // final double thresholdMeters = 3.05;
  // Timer? _locationCheckTimer;

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
    // _locationCheckTimer = Timer.periodic(
    //  const Duration(seconds: 5),
    // (_) => _checkLocation(),
    //  );
  }

  @override
  void dispose() {
    // _visitTimer?.cancel();
    // _locationCheckTimer?.cancel();
    super.dispose();
  }

  /// Builds a combined mission list (visits + sticker collections).
  List<Mission> buildAllMissions(int uniqueStoreVisits) {
    // 1) “Visit X Boba Stores” missions
    final visitGoals = [3, 5, 10, 15, 20];
    final List<Mission> visitMissions = [];
    for (var i = 0; i < visitGoals.length; i++) {
      final goal = visitGoals[i];
      final current = min(uniqueStoreVisits, goal);
      visitMissions.add(Mission(
        id: i, // 0 → Visit 3, 1 → Visit 5, 2 → Visit 10, …
        title: 'Visit $goal Boba Stores',
        description: 'Visit $goal different boba stores to unlock reward.',
        current: current,
        goal: goal,
        reward: 5 * (i + 1),
      ));
    }

    // 2) Sticker‐collection missions
    final bronzeCount = _uniqueStickerIds.where((id) => id <= 24).length;
    final silverCount =
        _uniqueStickerIds.where((id) => id <= 35 && id >= 25).length;
    final goldCount = _uniqueStickerIds.where((id) => id >= 36).length;

    final List<Mission> stickerMissions = [
      Mission(
          id: 100,
          title: 'Collect 5 Bronze Stickers',
          /*…*/ current: min(bronzeCount, 5),
          goal: 5,
          reward: 5,
          description: 'Collect 5 unique Bronze-tier stickers!'),
      Mission(
          id: 101,
          title: 'Collect 10 Bronze Stickers',
          /*…*/ current: min(bronzeCount, 10),
          goal: 10,
          reward: 10,
          description: 'Collect 10 unique Bronze-tier stickers!'),
      Mission(
          id: 102,
          title: 'Complete Bronze Collection',
          /*…*/ current: bronzeCount,
          goal: 24,
          reward: 20,
          description: 'Collect All Bronze-tier stickers!'),
      Mission(
          id: 200,
          title: 'Collect 5 Silver Stickers',
          /*…*/ current: min(silverCount, 5),
          goal: 5,
          reward: 10,
          description: 'Collect 5 unique Silver-tier stickers!'),
      Mission(
          id: 201,
          title: 'Collect 10 Silver Stickers',
          /*…*/ current: min(silverCount, 10),
          goal: 10,
          reward: 15,
          description: 'Collect 10 unique Silver-tier stickers!'),
      Mission(
          id: 202,
          title: 'Complete Silver Collection',
          /*…*/ current: silverCount,
          goal: 11,
          reward: 30,
          description: 'Collect All Silver-tier stickers!'),
      Mission(
          id: 300,
          title: 'Collect 5 Gold Stickers',
          /*…*/ current: min(goldCount, 5),
          goal: 5,
          reward: 20,
          description: 'Collect 5 unique Gold-tier stickers!'),
      Mission(
          id: 301,
          title: 'Collect 10 Gold Stickers',
          /*…*/ current: min(goldCount, 10),
          goal: 10,
          reward: 30,
          description: 'Collect 10 unique Gold-tier stickers!'),
      Mission(
          id: 302,
          title: 'Complete Gold Collection',
          /*…*/ current: goldCount,
          goal: 15,
          reward: 50,
          description: 'Collect All Gold-tier stickers!'),
    ];

    return [...visitMissions, ...stickerMissions];
  }

  /// A custom ordering of mission IDs.
  static const List<int> _customOrder = [
    1, // Visit 5 stores
    100, // Collect 5 Bronze
    2, // Visit 10 stores
    101, // Collect 10 Bronze
    3, // Visit 15 stores
    102, // Complete Bronze
    // …add any others you like…
  ];

  /// Only show up to 4 next‐incomplete missions, in the custom interleaved order.
  List<Mission> filterVisibleMissions(List<Mission> allMissions) {
    // 1) Filter incomplete
    final incomplete = allMissions.where((m) => m.current < m.goal).toList();

    // 2) Sort by custom order (unknown IDs sink to the end)
    incomplete.sort((a, b) {
      final ia = _customOrder.indexOf(a.id).clamp(0, _customOrder.length);
      final ib = _customOrder.indexOf(b.id).clamp(0, _customOrder.length);
      return ia.compareTo(ib);
    });

    // 3) Take first four
    return incomplete.take(4).toList();
  }

  /// (Optional) If you still need “active” highlighting:
  bool isMissionActive(int idx, List<Mission> visibleMissions) {
    // active = first in the visible list
    return idx == 0;
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(255, 255, 255, 255),
        appBar: AppBar(
  toolbarHeight: 44,
  backgroundColor: widget.themeProvider.isDarkMode ? Colors.deepPurple : Colors.orange,
  elevation: 1,
  title: Text(
    'Missions',
    style: GoogleFonts.mavenPro(
      fontSize: 26,
     color: widget.themeProvider.isDarkMode ? const Color.fromARGB(255, 0, 0, 0) : const Color.fromARGB(255, 255, 255, 255),

    ),
  ),
  centerTitle: true,
),

        body: (_rewardsLoaded && _stickersLoaded)
            ? StreamBuilder<DatabaseEvent>(
                stream: uniqueRef.onValue,
                builder: (ctx, uniqueSnap) {
                  int uniqueCount = 0;
                  if (uniqueSnap.hasData &&
                      uniqueSnap.data!.snapshot.value != null) {
                    final uniqueMap = uniqueSnap.data!.snapshot.value
                        as Map<dynamic, dynamic>;
                    uniqueCount = uniqueMap.keys.length;
                  }
                  final allMissions = buildAllMissions(uniqueCount);
                  final visible = filterVisibleMissions(allMissions);

                  // Award rewards after build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_rewardsLoaded) _checkAndAwardRewards(allMissions);
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Unique Visits
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Unique Visits: $uniqueCount',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w300,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),

                      // Badges Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Badges',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w200,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: StreamBuilder<DatabaseEvent>(
                          stream: uniqueRef.onValue,
                          builder: (ctx3, badgeSnap) {
                            final badges = <Widget>[];
                            if (badgeSnap.hasData &&
                                badgeSnap.data!.snapshot.value != null) {
                              final uniqueMap = badgeSnap.data!.snapshot.value
                                  as Map<dynamic, dynamic>;
                              uniqueMap.forEach((sid, data) {
                                final ts =
                                    (data as Map)['timestamp'] as String? ?? '';
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              children: badges,
                            );
                          },
                        ),
                      ),

                      // Missions Tabs
                      Expanded(
                        child: TabBarView(
                          children: [
                            // ACTIVE Missions
                            ListView.separated(
                              padding: const EdgeInsets.all(16),
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: visible.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final m = visible[idx];
                                final active = idx == 0;
                                return _buildMissionRow(m, active);
                              },
                            ),

                            // COMPLETED Missions
                            ListView.separated(
                              padding: const EdgeInsets.all(16),
                              shrinkWrap: true,
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemCount: allMissions
                                  .where((m) => m.current >= m.goal)
                                  .length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, idx) {
                                final done = allMissions
                                    .where((m) => m.current >= m.goal)
                                    .toList();
                                return _buildMissionRow(done[idx], false);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            : const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: Container(
  color: widget.themeProvider.isDarkMode ? Colors.black : Colors.white,
  child: TabBar(
    indicatorColor: widget.themeProvider.isDarkMode ? Colors.blueAccent : Colors.deepPurple,
    labelColor: widget.themeProvider.isDarkMode ? Colors.white : Colors.black,
    unselectedLabelColor: widget.themeProvider.isDarkMode ? Colors.white54 : Colors.black54,
    tabs: const [
      Tab(text: 'Active'),
      Tab(text: 'Completed'),
    ],
  ),
),

      ),
    );
  }

  Widget _buildMissionRow(Mission m, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2E004F) : Colors.white;
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey : Colors.grey.shade600);

    // final lockIcon = Icon(Icons.lock,
    //     size: 40, color: isDark ? Colors.black54 : Colors.grey.shade400);
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
          // Positioned.fill(
          //   // child: Container(
          //   //   decoration: BoxDecoration(
          //   //     color: (isDark ? Colors.black : Colors.white).withOpacity(0.6),
          //   //     borderRadius: BorderRadius.circular(12),
          //   //   ),
          //   //   child: Center(child: lockIcon),
          //   // ),
          // ),
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
