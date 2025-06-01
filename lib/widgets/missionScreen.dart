import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/services/theme_provider.dart';

// ─── Helper to parse storeId into brand & location ───────────────────────────────
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

class Mission {
  final String title;
  final String description;
  final int goal;
  final int current;
  final int reward;

  const Mission({
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
    required this.reward,
  });
}

// ─── Segmented progress bar that never overflows ────────────────────────────────
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
        // Subtract total gap width, then divide equally among all segments:
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
                  color:
                      (segmentIndex < current) ? filledColor : emptyColor,
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

// ─── A flipping badge that shows store & date ────────────────────────────────────
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

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final info = _parseStoreId(widget.storeId);
    final date = DateTime.tryParse(widget.timestamp) ?? DateTime.now();
    final formattedDate = '${date.month}/${date.day}/${date.year}';

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
            transform:
                Matrix4.identity()..setEntry(3, 2, 0.003)..rotateY(angle),
            child: isFront ? front : back,
          );
        },
      ),
    );
  }
}

// ─── The main Missions screen ───────────────────────────────────────────────────
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
  final thresholdMeters = 3.05;
  Timer? _locationCheckTimer;

  late final DatabaseReference _coinsRef;
  late final DatabaseReference _rewardsRef;

  Set<int> _alreadyRewarded = {};
  bool _rewardsLoaded = false;

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
      if (!mounted) return; // avoid setState if disposed
      if (snap.exists) {
        final data = Map<String, dynamic>.from(snap.value as Map);
        setState(() {
          _alreadyRewarded = data.keys
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

    // Start periodic location checks
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

  void _checkLocation() async {
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

  List<Mission> buildMissions(int uniqueCount) {
    final goals = [3, 5, 10, 15, 20];
    var active = goals.indexWhere((g) => uniqueCount < g);
    if (active == -1) active = goals.length;
    return List.generate(goals.length, (i) {
      final prev = i == 0 ? 0 : goals[i - 1];
      final curr = i < active
          ? goals[i]
          : (i == active ? max(0, uniqueCount - prev) : 0);
      return Mission(
        title: 'Visit ${goals[i]} Boba Stores',
        description:
            'Visit ${goals[i]} different boba stores to unlock your reward!',
        current: curr,
        goal: goals[i],
        reward: 5 * (i + 1),
      );
    });
  }

  bool isMissionActive(int idx, int uniqueCount) {
    final goals = [3, 5, 10, 15, 20];
    var active = goals.indexWhere((g) => uniqueCount < g);
    if (active == -1) active = goals.length;
    return idx == active;
  }

  void _showInfo(String title, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
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
      body: StreamBuilder<DatabaseEvent>(
        stream: uniqueRef.onValue,
        builder: (ctx, uniqueSnap) {
          int uniqueCount = 0;
          var uniqueMap = <dynamic, dynamic>{};
          if (uniqueSnap.hasData && uniqueSnap.data!.snapshot.value != null) {
            uniqueMap = uniqueSnap.data!.snapshot.value as Map;
            uniqueCount = uniqueMap.keys.length;
          }
          final missions = buildMissions(uniqueCount);

          return StreamBuilder<DatabaseEvent>(
            stream: totalRef.onValue,
            builder: (ctx2, totalSnap) {
              int totalVisits = 0;
              if (totalSnap.hasData && totalSnap.data!.snapshot.value != null) {
                final totalMap = totalSnap.data!.snapshot.value as Map;
                totalMap.forEach((_, val) {
                  totalVisits += (val as int);
                });
              }

              // Only check rewards once we've loaded existing rewards:
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_rewardsLoaded) {
                  _checkAndAwardRewards(missions);
                }
              });

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Visits: $totalVisits',
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
                    GridView.count(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: uniqueMap.keys.map((sid) {
                        final ts = uniqueMap[sid]['timestamp'] as String? ?? '';
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final badgeSize = min(constraints.maxWidth, 70.0);
                            return BadgeCoin(
                              storeId: sid,
                              timestamp: ts,
                              size: badgeSize,
                            );
                          },
                        );
                      }).toList(),
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
                              color: isDark ? Colors.white70 : Colors.black54),
                          onPressed: () => _showInfo(
                              'Missions', 'Complete missions to earn coins.'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: missions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final m = missions[idx];
                        final active = isMissionActive(idx, uniqueCount);
                        return _buildMissionRow(m, active);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMissionRow(Mission m, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2E004F) : Colors.white;
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey : Colors.grey.shade600);

    final lockIcon = Icon(Icons.lock, size: 40, color: isDark ? Colors.black : Colors.grey);
    final checkIcon = Icon(Icons.check, size: 40, color: isDark ? Colors.blueAccent : Colors.green);

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
                      Image.asset('assets/coin_boba.png', width: 16, height: 16),
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
      row = InkWell(onTap: () => _showInfo(m.title, m.description), child: row);
    }

    return row;
  }

  Future<void> _checkAndAwardRewards(List<Mission> missions) async {
    for (var i = 0; i < missions.length; i++) {
      final m = missions[i];
      if (m.current >= m.goal && !_alreadyRewarded.contains(i)) {
        final reward = m.reward;
        final coinSnap = await _coinsRef.get();
        final currentCoins = (coinSnap.value as int?) ?? 0;
        await _coinsRef.set(currentCoins + reward);
        await _rewardsRef.child(i.toString()).set({
          'reward': reward,
          'timestamp': DateTime.now().toIso8601String(),
        });
        _alreadyRewarded.add(i);
      }
    }
  }
}
