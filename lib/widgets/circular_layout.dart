// lib/widgets/circular_layout.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';

class CircularLayout extends StatelessWidget {
  final double radius;
  final Widget centralWidget;
  final List<BobaStore> bobaStores;
  final Position userPosition;          // New parameter for user's position
  final double maxDistanceThreshold;    // New parameter for distance threshold

  const CircularLayout({
    Key? key,
    required this.radius,
    required this.centralWidget,
    required this.bobaStores,
    required this.userPosition,
    required this.maxDistanceThreshold,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int itemCount = bobaStores.length;
    final double angleIncrement = 2 * pi / itemCount;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          centralWidget,
          for (int i = 0; i < itemCount; i++)
            _buildPositionedStore(context, i, angleIncrement),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(BuildContext context, int index, double angleIncrement) {
    final double orbitRadius = radius * 1.5;
    final double angle = angleIncrement * index - pi / 2;
    final double x = orbitRadius * cos(angle);
    final double y = orbitRadius * sin(angle);

    BobaStore store = bobaStores[index];
    double distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );

    // Determine if store is within reach
    bool withinReach = distance <= maxDistanceThreshold;

    return Transform.translate(
      offset: Offset(x, y),
      child: Tooltip(
        message: withinReach 
            ? '${store.name} (${store.city})\nDistance: ${(distance/1000).toStringAsFixed(2)} km'
            : 'Not within location reach',
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage('assets/${store.imageName}.png'),
              backgroundColor: Colors.transparent,
            ),
            // If not within reach, overlay transparent gray layer
            if (!withinReach) 
              Container(
                width: 60, // diameter = radius * 2
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.5), // transparent gray overlay
                ),
              ),
          ],
        ),
      ),
    );
  }
}
