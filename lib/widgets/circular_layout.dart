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
    // First, sort the incoming list by distance from the user.
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

    // Now select the 8 closest stores.
    final int numStoresToShow = min(8, sortedList.length);
    final List<BobaStore> displayStores = sortedList.sublist(0, numStoresToShow);

    final int itemCount = displayStores.length;
    final double angleIncrement = 2 * pi / itemCount;
 final themeProvider = Provider.of<ThemeProvider>(context);
return SizedBox(
  width: radius * 3,
  height: radius * 3,
  child: Stack(
    alignment: Alignment.center,
    children: [
      // Display the user's location (city and state) at the center.
      Text(
        userLocationText,
        style: themeProvider.currentTheme.textTheme.bodyMedium,// Now using the style from ThemeProvider.
        textAlign: TextAlign.center,
      ),
          // Position each store around the circle.
          for (int i = 0; i < itemCount; i++)
            _buildPositionedStore(context, i, angleIncrement, displayStores),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(BuildContext context, int index, double angleIncrement, List<BobaStore> displayStores) {
    final double orbitRadius = radius * 1.2;
    final double angle = angleIncrement * index - pi / 2;
    final double x = orbitRadius * cos(angle);
    final double y = orbitRadius * sin(angle);

    BobaStore store = displayStores[index];
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

    return Transform.translate(
      offset: Offset(x, y),
      // Wrap the store widget in a GestureDetector to handle taps.
      child: GestureDetector(
        onTap: () {
          // Navigate to the details screen when tapped.
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StoreDetailsScreen(
                store: store,
                userPosition: userPosition,
              ),
            ),
          );
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: AssetImage(imagePath),
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
