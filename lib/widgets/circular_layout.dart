import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/models/store_details.dart';
import 'package:test/services/theme_provider.dart';

class CircularLayout extends StatelessWidget {
  final double radius;
  final List<BobaStore> bobaStores;
  final Position userPosition;
  final double maxDistanceThreshold;
  final String userLocationText; // e.g. "San Marcos, CA"
  final String uid;

  const CircularLayout({
    Key? key,
    required this.radius,
    required this.bobaStores,
    required this.userPosition,
    required this.maxDistanceThreshold,
    required this.userLocationText,
    required this.uid,
  }) : super(key: key);

  List<BobaStore> _getSortedStores() {
    final sorted = List<BobaStore>.from(bobaStores);
    sorted.sort((a, b) {
      final da = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        a.latitude,
        a.longitude,
      );
      final db = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        b.latitude,
        b.longitude,
      );
      return da.compareTo(db);
    });
    return sorted.sublist(0, min(8, sorted.length));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final stores = _getSortedStores();
    final count = stores.length;
    final angleStep = 2 * pi / count;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // User location at center
          Text(
            userLocationText,
            style: themeProvider.currentTheme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          for (int i = 0; i < count; i++)
            _buildPositionedStore(context, i, angleStep, stores),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(
    BuildContext context,
    int index,
    double angleIncrement,
    List<BobaStore> stores,
  ) {
    final orbit = radius * 1.2;
    final angle = angleIncrement * index - pi / 2;
    final dx = orbit * cos(angle);
    final dy = orbit * sin(angle);

    final store = stores[index];
    final distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );
    final withinReach = distance <= maxDistanceThreshold;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;

    return Transform.translate(
      offset: Offset(dx, dy),
      child: Semantics(
        label:
            '${store.name} store, ${withinReach ? "within reach" : "not within reach"}',
        button: true,
        child: SizedBox(
          width: 60,
          height: 60,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoreDetailsScreen(
                      store: store,
                      userPosition: userPosition,
                      userId: uid,
                    ),
                  ),
                );
              },
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (ctx, scale, child) => Transform.scale(
                  scale: scale,
                  child: child,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 1) Frosted-glass outer shell (more transparent)
                    ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.1)
                                : Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.white.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 2) Inner gradient with transparent center, colored edges
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: Alignment(-0.4, -0.4),
                          radius: 0.8,
                          stops: [0.0, 0.7, 1.0],
                          colors: isDark
                              ? [
                                  Colors.transparent,
                                  Color(0xFF3B1052).withOpacity(0.6),
                                  Color(0xFF5A189A).withOpacity(0.6),
                                ]
                              : [
                                  Colors.transparent,
                                  Color(0xFFB8E1FF).withOpacity(0.6),
                                  Color.fromARGB(255, 199, 115, 147).withOpacity(0.6),
                                ],
                        ),
                      ),
                    ),
                    // 3) Store name label
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        store.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(0, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 4) Grey overlay if out-of-reach
                    if (!withinReach)
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
