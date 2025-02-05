import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  /// Reverse geocode to obtain the city from a given position.
  Future<String> getCityFromPosition(Position position) async {
    try {
      // Increase the timeout duration to 10 seconds (or adjust as needed).
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          // You can throw a TimeoutException or simply return an empty list.
          throw TimeoutException('Reverse geocoding timed out');
        },
      );
      
      if (placemarks.isNotEmpty) {
        // Return the locality (city) or default to 'Unknown City'
        return placemarks.first.locality ?? 'Unknown City';
      }
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('Reverse geocoding timed out: $e');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error in reverse geocoding: $e');
      }
    }
    return 'Unknown City';
  }
}
