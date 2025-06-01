import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/services/theme_provider.dart';

/// A “coin‐stop” spinner with a 3D circle showing the store name.
/// When in a 20m geofence, users can spin to log a visit and animate coins appearing.
/// For testing: allows multiple spins by commenting out lockout logic.
class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId;

  const StoreDetailsScreen({
    Key? key,
    required this.store,
    required this.userPosition,
    required this.userId,
  }) : super(key: key);

  @override
  _StoreDetailsScreenState createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen>
    with TickerProviderStateMixin {
  static const double _proximityThreshold = 20.0;

  Position? _currentPosition;
  bool _withinGeofence = false;
  bool _isSpinning = false;
  // For testing: always allow spin. Remove _hasSpun.

  late final AnimationController _spinController;
  late final AnimationController _coinAnimController;
  late final Animation<double> _coinScale;
  late final Animation<double> _coinOpacity;

  late final DatabaseReference _coinsRef;
  late final DatabaseReference _userVisitRef;

  Timer? _proximityTimer;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;

    // Firebase references
    _coinsRef = FirebaseDatabase.instance.ref('users/${widget.userId}/coins');
    _userVisitRef = FirebaseDatabase.instance
        .ref('userVisits/${widget.userId}/${widget.store.id}');

    // Comment out lockout logic so multiple visits allowed:
    // _userVisitRef.get().then((snapshot) {
    //   if (snapshot.exists) {
    //     setState(() => _hasSpun = true);
    //   }
    // });

    // Animation for spinning
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Animation for coins appearing (scale + fade over 3 seconds)
    _coinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _coinScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _coinAnimController,
        curve: Curves.elasticOut,
      ),
    );
    _coinOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _coinAnimController,
        curve: Curves.easeOut,
      ),
    );

    _startProximityMonitoring();
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    _spinController.dispose();
    _coinAnimController.dispose();
    super.dispose();
  }

  void _startProximityMonitoring() {
    _proximityTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkProximity(),
    );
  }

  Future<void> _checkProximity() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = pos;

      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        widget.store.latitude,
        widget.store.longitude,
      );
      final nowWithin = distance <= _proximityThreshold;
      if (nowWithin != _withinGeofence) {
        setState(() {
          _withinGeofence = nowWithin;
        });
      }
    } catch (e) {
      debugPrint('Proximity error: $e');
    }
  }

     Future<void> _onCircleTap() async {
     if (!_withinGeofence || _isSpinning) return;

     setState(() => _isSpinning = true);
     await _spinController.forward(from: 0);

     final extra = Random().nextInt(3);
     final totalReward = 5 + extra;

     // --- ALWAYS record a new visit (even if this store was visited before) ---
     // 1) record in “visits/<storeId>/<userId>”
     await FirebaseDatabase.instance
         .ref('visits/${widget.store.id}/${widget.userId}')
         .set({
       'timestamp': DateTime.now().toIso8601String(),
       'latitude': _currentPosition!.latitude,
       'longitude': _currentPosition!.longitude,
     });

     // 2) increment “stores/<city>/<storeId>/visits”
     final storeRef = FirebaseDatabase.instance
         .ref('stores/${widget.store.city}/${widget.store.id}');
     await storeRef.runTransaction((data) {
       if (data != null) {
         final map = Map<String, dynamic>.from(data as Map);
         map['visits'] = (map['visits'] ?? 0) + 1;
         return Transaction.success(map);
       }
       return Transaction.success(data);
     });

     // 3) mark “userVisits/<userId>/<storeId>” (this no longer gates uniqueness,
     //    it simply records one “timestamp” per store, if you still need it.)
     await _userVisitRef.set({
       'timestamp': DateTime.now().toIso8601String(),
       'latitude': _currentPosition!.latitude,
       'longitude': _currentPosition!.longitude,
     });

   // 4) INCREMENT “userStoreVisits/<userId>/<storeId>” to track repeated visits:
 final userStoreVisitsRef = FirebaseDatabase.instance
       .ref('userStoreVisits/${widget.userId}/${widget.store.id}');
  await userStoreVisitsRef.runTransaction((data) {
   final prev = (data as int?) ?? 0;
   return Transaction.success(prev + 1);
});

     // 5) credit coins
     final coinSnap = await _coinsRef.get();
     final currentCoins = (coinSnap.value as int?) ?? 0;
     await _coinsRef.set(currentCoins + totalReward);

     setState(() {
       _isSpinning = false;
     });

     // Trigger coin animation
     _coinAnimController.forward(from: 0);

     // (No lockout logic here—so you can tap multiple times.)
   }


  Future<void> _launchMaps() async {
    final uri = Uri.https(
      'www.google.com',
      'maps/search/',
      {
        'api': '1',
        'query': '${widget.store.latitude},${widget.store.longitude}',
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final distance = _currentPosition != null
        ? Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            widget.store.latitude,
            widget.store.longitude,
          )
        : 0.0;
    final miles = (distance / 1000) * 0.621371;

    // Determine circle color: light-black→orange or white→purple
    Color circleColor;
    if (_withinGeofence) {
      circleColor = theme.isDarkMode ? Colors.purpleAccent : Colors.orangeAccent;
    } else {
      circleColor = theme.isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.2);
    }

    // Determine status text
    String statusText;
    if (_withinGeofence) {
      statusText = 'Tap circle to spin and collect coins';
    } else {
      statusText = 'Move closer to spin the circle';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1) Store icon & distance
            Row(
              children: [
                Icon(Icons.store,
                    size: 80,
                    color: theme.isDarkMode
                        ? Colors.white
                        : Theme.of(context).primaryColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    '${miles.toStringAsFixed(2)} mi away',
                    style: theme.isDarkMode
                        ? Theme.of(context)
                            .textTheme
                            .titleLarge!
                            .copyWith(color: Colors.white)
                        : Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 2) Address card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: _launchMaps,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.store.address,
                          style: theme.isDarkMode
                              ? const TextStyle(color: Colors.white)
                              : const TextStyle(color: Colors.black)),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.store.city}, ${widget.store.state} ${widget.store.zip}',
                        style: const TextStyle(
                          color: Colors.blue,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.launch,
                            size: 20, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 3) Big 3D circle spinner with ring and coin animation overlay
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.isDarkMode ? Colors.purple : Colors.orange,
                          width: 4,
                        ),
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _spinController,
                      builder: (_, __) {
                        final angle = _isSpinning
                            ? _spinController.value * 2 * pi
                            : 0.0;
                        return Transform.rotate(
                          angle: angle,
                          child: GestureDetector(
                            onTap: _onCircleTap,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    circleColor,
                                    circleColor.withOpacity(0.9),
                                  ],
                                  center: Alignment(-0.2, -0.2),
                                  radius: 0.8,
                                ),
                                border: Border.all(
                                  color: circleColor.withOpacity(0.6),
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.isDarkMode
                                        ? Colors.black54
                                        : Colors.grey.shade400,
                                    blurRadius: 10,
                                    offset: const Offset(4, 4),
                                  ),
                                  BoxShadow(
                                    color: theme.isDarkMode
                                        ? Colors.grey.shade800
                                        : Colors.white70,
                                    blurRadius: 5,
                                    offset: const Offset(-4, -4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  widget.store.name,
                                  textAlign: TextAlign.center,
                                  style: theme.isDarkMode
                                      ? const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)
                                      : const TextStyle(
                                          color: Colors.black,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Coin animation
                    Positioned(
                      top: 0,
                      child: FadeTransition(
                        opacity: _coinOpacity,
                        child: ScaleTransition(
                          scale: _coinScale,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/coin_boba.png',
                                width: 40,
                                height: 40,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '+${Random().nextInt(3) + 5}',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: theme.isDarkMode
                                      ? Colors.amberAccent
                                      : Colors.yellowAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 4) Instruction / status text
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: theme.isDarkMode
                  ? const TextStyle(color: Colors.white70, fontSize: 16)
                  : TextStyle(color: Colors.grey.shade800, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
