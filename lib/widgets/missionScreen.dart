import 'dart:async';
import 'dart:math';

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

    return LayoutBuilder(builder: (context, constraints) {
      final totalWidth = constraints.maxWidth;
      final totalSpacing = spacing * (goal - 1);
      final segmentWidth = (totalWidth - totalSpacing) / goal;
      final segments = <Widget>[];

      for (int i = 0; i < goal; i++) {
        segments.add(Container(
          width: segmentWidth,
          height: 8,
          decoration: BoxDecoration(
            color: i < current ? filledColor : emptyColor,
            borderRadius: BorderRadius.circular(4),
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

/// Splits "Brand_CityName" into { brand, location }.
Map<String, String> getStoreDisplayInfo(String storeId) {
  final parts = storeId.split('_');
  final brand = parts.isNotEmpty ? parts[0] : storeId;
  var location = '';
  if (parts.length >= 2) {
    final raw = parts[1];
    final city = raw.replaceAllMapped(RegExp(r'(?<!^)([A-Z])'), (m) => ' ${m[0]}');
    final stateMap = {'SanMarcos': 'CA', 'Oceanside': 'CA', 'Vista': 'CA'};
    final st = stateMap[parts[1]] ?? '';
    location = '$city, $st';
  }
  return {'brand': brand, 'location': location};
}

class BadgeCoin extends StatefulWidget {
  final String storeId;
  final String timestamp;
  final double size;

  const BadgeCoin({
    Key? key,
    required this.storeId,
    required this.timestamp,
    this.size = 70,
  }) : super(key: key);

  @override
  _BadgeCoinState createState() => _BadgeCoinState();
}

class _BadgeCoinState extends State<BadgeCoin>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _showFront = true;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _anim = Tween<double>(begin: 0, end: pi).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _showFront = !_showFront;
          _ctrl.reset();
        }
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTap() {
    if (!_ctrl.isAnimating) _ctrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = widget.size;

    final info = getStoreDisplayInfo(widget.storeId);
    final date = DateTime.tryParse(widget.timestamp) ?? DateTime.now();
    final formattedDate = '${date.month}/${date.day}/${date.year}';

    Widget buildFace(Widget child) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isDark
              ? LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF6A1B9A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Color(0xFF81D4FA), Color(0xFF00B0FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          border: Border.all(
            color: isDark ? Color(0xFF311B92) : Color(0xFF01579B),
            width: size * 0.05,
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

    final front = buildFace(Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.store,
          size: size * 0.25,
          color: isDark ? Colors.white : Colors.black,
        ),
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
    ));

    final back = buildFace(Transform(
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
              color: isDark
                  ? Color.fromARGB(255, 150, 146, 228)
                  : Color.fromARGB(255, 100, 2, 152),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ));

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) {
          final value = _anim.value;
          final angle = _showFront ? value : value + pi;
          final isFrontVisible = (value <= pi / 2) == _showFront;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateY(angle),
            child: isFrontVisible ? front : back,
          );
        },
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

  @override
  void initState() {
    super.initState();
    _locationCheckTimer =
        Timer.periodic(Duration(seconds: 5), (_) => _checkLocation());
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
      _visitTimer ??= Timer(Duration(seconds: 30), () async {
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
          : i == active
              ? max(0, uniqueCount - prev)
              : 0;
      return Mission(
        title: 'Visit ${goals[i]} Boba Stores',
        description:
            'Visit ${goals[i]} different boba stores to unlock your reward!',
        current: curr,
        goal: goals[i],
      );
    });
  }

  bool isMissionActive(int idx, int count) {
    final goals = [3, 5, 10, 15, 20];
    var active = goals.indexWhere((g) => count < g);
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))
        ],
      ),
    );
  }

  Widget buildMissionRow(Mission m, bool active) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardColor = isDark ? Color(0xFF2E004F) : Colors.white;
    final textColor = active
        ? (isDark ? Colors.white : Colors.black)
        : (isDark ? Colors.grey : Colors.grey.shade600);

    final lockIcon = Icon(
      Icons.lock,
      size: 40,
      color: isDark ? Colors.black : Colors.grey,
    );
    final checkIcon = Icon(
      Icons.check,
      size: 40,
      color: isDark ? Colors.blueAccent : Colors.green,
    );

    Widget row = Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: textColor)),
                  SizedBox(height: 4),
                  Text(m.description,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          color: textColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  SegmentedProgressIndicator(
                      current: m.current, goal: m.goal, spacing: 4),
                  SizedBox(height: 4),
                  Text('${m.current}/${m.goal}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w300,
                          color: textColor)),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (m.current == m.goal) {
      row = Stack(children: [
        row,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color:
                  (isDark ? Colors.black : Colors.white).withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: checkIcon),
          ),
        )
      ]);
    } else if (!active) {
      row = Stack(children: [
        row,
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color:
                  (isDark ? Colors.black : Colors.white).withOpacity(0.6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: lockIcon),
          ),
        )
      ]);
    } else {
      row = InkWell(
        onTap: () => _showInfo(m.title, m.description),
        child: row,
      );
    }

    return row;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitsRef = FirebaseDatabase.instance
        .ref()
        .child('userVisits')
        .child(widget.userId);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: Text('Missions'),
        centerTitle: true,
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: visitsRef.onValue,
        builder: (ctx, snap) {
          var unique = 0;
          var visitsMap = <dynamic, dynamic>{};
          if (snap.hasData && snap.data!.snapshot.value != null) {
            visitsMap = snap.data!.snapshot.value as Map;
            unique = visitsMap.keys.length;
          }
          final missions = buildMissions(unique);

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total Visits: $unique',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w300,
                        color: isDark ? Colors.white : Colors.black)),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Badges',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: isDark ? Colors.white : Colors.black)),
                    IconButton(
                      icon: Icon(Icons.help_outline,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => _showInfo(
                          'Badges',
                          'Tap a badge to flip: front shows store name; back shows date & location.'),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: 78, // badge size (70) + some padding
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: visitsMap.keys.length,
                    separatorBuilder: (_, __) => SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final sid = visitsMap.keys.elementAt(i);
                      final ts = visitsMap[sid]['timestamp'] as String;
                      return BadgeCoin(
                        storeId: sid,
                        timestamp: ts,
                        size: 70, // explicit size
                      );
                    },
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Missions',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w300,
                            color: isDark ? Colors.white : Colors.black)),
                    IconButton(
                      icon: Icon(Icons.help_outline,
                          color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => _showInfo(
                          'Missions',
                          'Only the current mission is active. Complete it to unlock the next.'),
                    ),                ],
                ),
                SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: missions.length,
                  separatorBuilder: (_, __) => SizedBox(height: 10),
                  itemBuilder: (ctx, idx) =>
                      buildMissionRow(missions[idx], isMissionActive(idx, unique)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
