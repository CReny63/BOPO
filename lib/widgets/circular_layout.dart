import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';

class CircularLayout extends StatelessWidget {
  final double radius;
  final List<BobaStore> bobaStores;
  final Position userPosition;
  final double maxDistanceThreshold;
  final String userLocationText; // e.g. "San Marcos, CA"

  const CircularLayout({
    Key? key,
    required this.radius,
    required this.bobaStores,
    required this.userPosition,
    required this.maxDistanceThreshold,
    required this.userLocationText,
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
          // Display the user's location (city and state) at the center.
          Text(
            userLocationText,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          // Position each store around the circle.
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
  bool withinReach = distance <= maxDistanceThreshold;

  // Compute the image path with fallback.
  String imagePath = store.imageName.isNotEmpty
      ? 'assets/${store.imageName}.png'
      : 'assets/default_image.png';
print("Displaying store: name=${store.name}, imageName=${store.imageName}");

  return Transform.translate(
    
    offset: Offset(x, y),
    child: Tooltip(
      message: withinReach 
          ? '${store.name} (${store.city}, ${store.state})\nDistance: ${(distance / 1000).toStringAsFixed(2)} km'
          : 'Not within location reach',
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: AssetImage(imagePath), // Use imagePath here!
            backgroundColor: Colors.transparent,
          ),
          if (!withinReach)
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.withOpacity(0.5),
              ),
            ),
          // Overlay the store's name on top of the circle.
          Text(
            store.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Colors.black,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
 }
}
