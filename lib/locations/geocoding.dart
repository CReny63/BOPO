import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  String? _lastCity;
  double? _lastLat;
  double? _lastLng;

  /// Gets the city for [position], but
  ///  • returns a cached result if coords are effectively the same
  ///  • otherwise spins up a background isolate for the lookup
  Future<String> getCityFromPosition(Position position) async {
    // Simple “cache” if the coordinates haven’t changed more than ~100m:
    if (_lastLat != null &&
        _lastLng != null &&
        _distanceInMeters(_lastLat!, _lastLng!,
                position.latitude, position.longitude) <
            100 &&
        _lastCity != null) {
      return _lastCity!;
    }

    try {
      final city = await compute<_ReverseGeocodeParams, String>(
        _reverseGeocodeWorker,
        _ReverseGeocodeParams(
          lat: position.latitude,
          lng: position.longitude,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Reverse geocoding timed out');
        },
      );

      // Cache for next time
      _lastLat = position.latitude;
      _lastLng = position.longitude;
      _lastCity = city;
      return city;
    } on TimeoutException catch (e) {
      if (kDebugMode) print('Geocode timeout: $e');
    } catch (e) {
      if (kDebugMode) print('Geocode error: $e');
    }

    return 'Unknown City';
  }

  /// Haversine formula for rough distance in meters
  double _distanceInMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth radius in meters
    double dLat = _toRad(lat2 - lat1);
    double dLon = _toRad(lon2 - lon1);
    double a = 
      sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _toRad(double deg) => deg * (pi / 180);
}

/// Parameters for the background isolate
class _ReverseGeocodeParams {
  final double lat, lng;
  _ReverseGeocodeParams({required this.lat, required this.lng});
}

/// Runs in a separate isolate
Future<String> _reverseGeocodeWorker(_ReverseGeocodeParams p) async {
  final placemarks = await placemarkFromCoordinates(p.lat, p.lng);
  if (placemarks.isNotEmpty) {
    return placemarks.first.locality ?? 'Unknown City';
  }
  return 'Unknown City';
}
