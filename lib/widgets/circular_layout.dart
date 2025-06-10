import 'dart:math';
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
  final String uid; // Add the UID property

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
    List<BobaStore> sortedList = List<BobaStore>.from(bobaStores);
    sortedList.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        a.latitude,
        a.longitude,
      );
      double distanceB = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        b.latitude,
        b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedList.sublist(0, min(8, sortedList.length));
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final List<BobaStore> displayStores = _getSortedStores();
    final int itemCount = displayStores.length;
    final double angleIncrement = 2 * pi / itemCount;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            userLocationText,
            style: themeProvider.currentTheme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          for (int i = 0; i < itemCount; i++)
            _buildPositionedStore(context, i, angleIncrement, displayStores),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(
      BuildContext context,
      int index,
      double angleIncrement,
      List<BobaStore> displayStores,
  ) {
    final double orbitRadius = radius * 1.2;
    final double angle = angleIncrement * index - pi / 2;
    final double x = orbitRadius * cos(angle);
    final double y = orbitRadius * sin(angle);

    final store = displayStores[index];
    final distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );
    final withinReach = distance <= maxDistanceThreshold;
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Transform.translate(
      offset: Offset(x, y),
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
              customBorder: const CircleBorder(),
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
                    // boba-ball image
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/boba_ball.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),

                    // store name label
                    Center(
                      child: Text(
                        store.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              offset: Offset(1, 1),
                              blurRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // grey overlay if out-of-reach
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
