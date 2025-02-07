import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Determines the current position.
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  /// Reverse geocodes the given position and returns a combined string with city and state.
  Future<String> getLocationText(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        // Use administrativeArea for state.
        final String city = placemarks.first.locality ?? 'Unknown City';
        final String state =
            placemarks.first.administrativeArea ?? 'Unknown State';
        return '$city, $state';
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in reverse geocoding: $e');
      }
    }
    return 'Unknown Location';
  }
}
