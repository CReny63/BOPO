import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/services/theme_provider.dart';

/// StoreDetailsScreen with interactive, popping bubbles for coins & sticker.
///
/// When spun, 1–5 coin bubbles float up (random horizontal offsets), each tappable
/// to “pop” them. 1/5 spins also award one sticker bubble, tappable to pop.
/// Underlying rewards (coins/sticker) are already credited in Firebase.
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

  // How many coins were awarded in the last spin
  int _lastCoinCount = 0;

  // Random horizontal offsets for each coin bubble (in pixels)
  List<double> _coinXOffsets = [];

  // Tracks whether each coin bubble is still “alive” (not popped)
  List<bool> _coinAlive = [];

  // If a sticker was awarded, its ID (1–30). Otherwise null.
  int? _awardedSticker;

  // Whether that sticker bubble is still “alive” (not popped)
  bool _stickerAlive = false;

  // Animation controllers:
  late final AnimationController _spinController;
  late final AnimationController _coinAnimController;
  late final Animation<double> _spinAnimation;
  late final Animation<double> _coinScale;
  late final Animation<double> _coinOpacity;
  late final Animation<double> _coinOffset;

  late final AnimationController _stickerAnimController;
  late final Animation<double> _stickerScale;
  late final Animation<double> _stickerOpacity;
  late final Animation<double> _stickerOffset;

  late final DatabaseReference _coinsRef;
  late final DatabaseReference _userVisitRef;
  late final DatabaseReference _stickersRef;

  Timer? _proximityTimer;

  @override
  void initState() {
    super.initState();
    _currentPosition = widget.userPosition;

    _coinsRef = FirebaseDatabase.instance.ref('users/${widget.userId}/coins');
    _userVisitRef = FirebaseDatabase.instance
        .ref('userVisits/${widget.userId}/${widget.store.id}');
    _stickersRef =
        FirebaseDatabase.instance.ref('users/${widget.userId}/stickers');

    // 1) Spinner rotation controller (800ms)
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _spinAnimation = Tween<double>(begin: 0, end: 2 * 2 * pi).animate(
      CurvedAnimation(parent: _spinController, curve: Curves.easeInOut),
    );

    // 2) Coin bubbles controller (4s total)
    _coinAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _coinScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _coinAnimController, curve: Curves.elasticOut),
    );
    _coinOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _coinAnimController, curve: Curves.easeInOut),
    );
    _coinOffset = Tween<double>(begin: 0.0, end: -120.0).animate(
      CurvedAnimation(parent: _coinAnimController, curve: Curves.easeInOut),
    );

    // 3) Sticker bubble controller (4s total)
    _stickerAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _stickerScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stickerAnimController, curve: Curves.elasticOut),
    );
    _stickerOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _stickerAnimController, curve: Curves.easeInOut),
    );
    _stickerOffset = Tween<double>(begin: 0.0, end: -150.0).animate(
      CurvedAnimation(parent: _stickerAnimController, curve: Curves.easeInOut),
    );

    _startProximityMonitoring();
  }

  @override
  void dispose() {
    _proximityTimer?.cancel();
    _spinController.dispose();
    _coinAnimController.dispose();
    _stickerAnimController.dispose();
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
        setState(() => _withinGeofence = nowWithin);
      }
    } catch (e) {
      debugPrint('Proximity error: $e');
    }
  }

  Future<void> _onCircleTap() async {
    if (!_withinGeofence || _isSpinning) return;

    setState(() {
      _isSpinning = true;
      _awardedSticker = null;
      // Reset coin bubbles for new spin
      _lastCoinCount = 0;
      _coinXOffsets = [];
      _coinAlive = [];
      _stickerAlive = false;
    });

    // 1) Spinner animation
    await _spinController.forward(from: 0);

    // 2) Decide # of coins to award (1–5)
    final awardedCoins = Random().nextInt(5) + 1;
    _lastCoinCount = awardedCoins;

    // Generate random horizontal offsets in [-60..+60]
    _coinXOffsets = List<double>.generate(
      awardedCoins,
      (_) => (Random().nextDouble() * 120) - 60,
    );
    _coinAlive = List<bool>.filled(awardedCoins, true);

    // 3) Record visit under “visits/<storeId>/<userId>”
    await FirebaseDatabase.instance
        .ref('visits/${widget.store.id}/${widget.userId}')
        .set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    });

    // 4) Increment global store visits
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

    // 5) Mark “userVisits/<userId>/<storeId>”
    await _userVisitRef.set({
      'timestamp': DateTime.now().toIso8601String(),
      'latitude': _currentPosition!.latitude,
      'longitude': _currentPosition!.longitude,
    });

    // 6) Increment “userStoreVisits/<userId>/<storeId>”
    final userStoreVisitsRef = FirebaseDatabase.instance
        .ref('userStoreVisits/${widget.userId}/${widget.store.id}');
    await userStoreVisitsRef.runTransaction((data) {
      final prev = (data as int?) ?? 0;
      return Transaction.success(prev + 1);
    });

    // 7) Credit coins in database
    final coinSnap = await _coinsRef.get();
    final currentCoins = (coinSnap.value as int?) ?? 0;
    await _coinsRef.set(currentCoins + awardedCoins);

    // 8) 1/5 chance to award sticker:
    if (Random().nextInt(5) == 0) {
      _awardedSticker = Random().nextInt(30) + 1; // 1..30
      _stickerAlive = true;
      // Immediately write a placeholder to the user’s sticker collection
      final stickerAsset = 'assets/sticker$_awardedSticker.png';
      await _stickersRef.push().set({'asset': stickerAsset});
    }

    setState(() => _isSpinning = false);

    // Start coin bubble animation
    _coinAnimController.forward(from: 0);

    // If a sticker was awarded, start its animation after 500ms
    if (_awardedSticker != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _stickerAnimController.forward(from: 0);
      });
    }
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

    final ringColor = _withinGeofence
        ? (theme.isDarkMode
            ? const Color.fromARGB(255, 212, 0, 250)
            : const Color.fromARGB(255, 0, 255, 13))
        : (theme.isDarkMode
            ? Colors.white.withOpacity(0.2)
            : Colors.black.withOpacity(0.2));

    final statusText = _withinGeofence
        ? 'Tap to spin and record a visit!'
        : 'Move closer to spin the coin';
    final statusColor = _withinGeofence ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store.name),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── 1) Store icon & distance ───────────────────────────────
            Row(
              children: [
                Icon(
                  Icons.store,
                  size: 80,
                  color: theme.isDarkMode
                      ? Colors.white
                      : Theme.of(context).primaryColor,
                ),
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
            // ── 2) Address card ───────────────────────────────────────
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
                      Text(
                        widget.store.address,
                        style: theme.isDarkMode
                            ? const TextStyle(color: Colors.white)
                            : const TextStyle(color: Colors.black),
                      ),
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
                        child: Icon(Icons.launch, size: 20, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            // ── 3) 3D coin spinner + floating bubbles ────────────────
            Expanded(
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer ring
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: ringColor, width: 6),
                      ),
                    ),

                    // Rotating coin (spinner)
                    AnimatedBuilder(
                      animation: _spinAnimation,
                      // coinWidget is provided as the `child` so we don’t rebuild its subtree every frame
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: theme.isDarkMode
                                ? [Colors.grey.shade700, Colors.grey.shade900]
                                : [
                                    Colors.yellow.shade300,
                                    Colors.orange.shade700
                                  ],
                            center: const Alignment(-0.3, -0.3),
                            radius: 0.8,
                          ),
                          border: Border.all(
                            color: theme.isDarkMode
                                ? Colors.grey.shade800
                                : Colors.brown.shade700,
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
                                    fontWeight: FontWeight.bold,
                                  )
                                : const TextStyle(
                                    color: Colors.black,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                          ),
                        ),
                      ),
                      builder: (context, coinWidget) {
                        final angle = _isSpinning ? _spinAnimation.value : 0.0;
                        final matrix = Matrix4.identity()
                          ..setEntry(3, 2, 0.005)
                          ..rotateY(angle);
                        return Transform(
                          transform: matrix,
                          alignment: Alignment.center,
                          child: GestureDetector(
                            onTap: _onCircleTap,
                            child: coinWidget,
                          ),
                        );
                      },
                    ),

                    // ── Coin bubbles: random dx, float upward ────────
                    AnimatedBuilder(
                      animation: _coinAnimController,
                      builder: (context, _) {
                        if (_lastCoinCount == 0) return const SizedBox.shrink();
                        return Transform.translate(
                          offset: Offset(0, _coinOffset.value),
                          child: Opacity(
                            opacity: _coinOpacity.value,
                            child: Transform.scale(
                              scale: _coinScale.value,
                              child: Stack(
                                alignment: Alignment.center,
                                children: List.generate(_lastCoinCount, (i) {
                                  return AnimatedScale(
                                    scale: _coinAlive[i] ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOut,
                                    child: Opacity(
                                      opacity: _coinAlive[i] ? 1.0 : 0.0,
                                      child: Transform.translate(
                                        offset: Offset(_coinXOffsets[i], 0),
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _coinAlive[i] = false;
                                            });
                                          },
                                          child: _buildBubble(
                                            context,
                                            child: Center(
                                              child: Image.asset(
                                                'assets/coin_boba.png',
                                                width: 36,
                                                height: 36,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // ── Sticker bubble (if awarded): float upward ─────
                    if (_awardedSticker != null && _stickerAlive)
                      AnimatedBuilder(
                        animation: _stickerAnimController,
                        builder: (context, _) {
                          return Transform.translate(
                            offset: Offset(0, _stickerOffset.value),
                            child: Opacity(
                              opacity: _stickerOpacity.value,
                              child: Transform.scale(
                                scale: _stickerScale.value,
                                child: AnimatedScale(
                                  scale: _stickerAlive ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeOut,
                                  child: Opacity(
                                    opacity: _stickerAlive ? 1.0 : 0.0,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _stickerAlive = false;
                                        });
                                      },
                                      child: _buildBubble(
                                        context,
                                        child: Center(
                                          child: Image.asset(
                                            'assets/sticker$_awardedSticker.png',
                                            width: 48,
                                            height: 48,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ── 4) Instruction / status text ──────────────────────────
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: statusColor),
            ),
          ],
        ),
      ),
    );
  }

  /// Draws a 64×64 “sphere‐like bubble” around [child].
  Widget _buildBubble(BuildContext context, {required Widget child}) {
    final theme = Provider.of<ThemeProvider>(context);
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withOpacity(theme.isDarkMode ? 0.10 : 0.20),
            Colors.white.withOpacity(theme.isDarkMode ? 0.05 : 0.10),
          ],
          center: const Alignment(-0.3, -0.3),
          radius: 0.8,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 2,
            offset: const Offset(-2, -2),
          ),
        ],
      ),
      child: ClipOval(child: child),
    );
  }
}
