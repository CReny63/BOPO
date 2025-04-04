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

  // Helper method to sort stores by distance and return the closest 8.
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
    // Obtain themeProvider from context.
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
          // Display the user's location (city and state) at the center.
          Text(
            userLocationText,
            style: themeProvider.currentTheme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          // Position each store around the circle.
          for (int i = 0; i < itemCount; i++)
            _buildPositionedStore(context, i, angleIncrement, displayStores),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(BuildContext context, int index,
      double angleIncrement, List<BobaStore> displayStores) {
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

    // Access the theme provider.
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Transform.translate(
      offset: Offset(x, y),
      child: Semantics(
        // Providing a semantic label for accessibility even though the store name is removed.
        label:
            '${store.name} store, ${withinReach ? "within reach" : "not within reach"}',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(30),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoreDetailsScreen(
                    store: store,
                    userPosition: userPosition,
                    userId: '',
                  ),
                ),
              );
            },
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, scale, child) {
                return Transform.scale(
                  scale: scale,
                  child: child,
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // The thin bordered circular container with the store image.
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: themeProvider.isDarkMode
                            ? Colors.white70
                            : Colors.black54,
                        width: 1.0,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit
                            .cover, // or BoxFit.contain, if you prefer letterboxing
                        alignment: Alignment.center,
                      ),
                    ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
