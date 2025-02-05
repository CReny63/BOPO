import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';

class CircularLayout extends StatelessWidget {
  final double radius;
  final Widget centralWidget;
  final List<BobaStore> bobaStores;
  final Position userPosition;          // User's current position
  final double maxDistanceThreshold;    // Maximum distance (in meters) to consider a store "within reach"

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
    // Determine how many store items to display and calculate the angle increment.
    final int itemCount = bobaStores.length;
    final double angleIncrement = 2 * pi / itemCount;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The widget at the center (for example, a logo or main indicator)
          centralWidget,
          // Place each store item around the circle
          for (int i = 0; i < itemCount; i++)
            _buildPositionedStore(context, i, angleIncrement),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(BuildContext context, int index, double angleIncrement) {
    // Set the orbit radius relative to the given radius.
    final double orbitRadius = radius * 1.5;
    // Calculate the angle for the current item (offset by -pi/2 so that the first item is at the top).
    final double angle = angleIncrement * index - pi / 2;
    // Calculate the (x,y) offset from the center.
    final double x = orbitRadius * cos(angle);
    final double y = orbitRadius * sin(angle);

    BobaStore store = bobaStores[index];
    // Calculate the distance from the user's position to the store.
    double distance = Geolocator.distanceBetween(
      userPosition.latitude,
      userPosition.longitude,
      store.latitude,
      store.longitude,
    );

    // Determine if the store is within the specified distance threshold.
    bool withinReach = distance <= maxDistanceThreshold;

    return Transform.translate(
      offset: Offset(x, y),
      child: Tooltip(
        // Display store name, city, and distance if within reach; otherwise, indicate it's out of reach.
        message: withinReach 
            ? '${store.name} (${store.city})\nDistance: ${(distance / 1000).toStringAsFixed(2)} km'
            : 'Not within location reach',
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Display the store image inside a circular avatar.
            CircleAvatar(
              radius: 30, // Adjust as needed
              backgroundImage: AssetImage('assets/${store.imageName}.png'),
              backgroundColor: Colors.transparent,
            ),
            // If the store is not within reach, overlay a semi-transparent gray layer.
            if (!withinReach)
              Container(
                width: 60, // Diameter (2 * radius)
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.withOpacity(0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
