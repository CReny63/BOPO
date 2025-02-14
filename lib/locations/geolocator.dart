import 'dart:async';
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
  // Assume this method uses reverse geocoding to get a Placemark.
  final placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
  if (placemarks.isNotEmpty) {
    final placemark = placemarks.first;
    // Map full state names to abbreviations.
    final stateAbbr = _stateAbbreviation(placemark.administrativeArea);
    return "${placemark.locality}, $stateAbbr";
  }
  return "Unknown Location";
}

String _stateAbbreviation(String? state) {
  // Simple example mapping. Expand as needed.
  final mapping = {
    "California": "CA",
    "Arizona": "AZ",
    // ... add other mappings here ...
  };
  return mapping[state] ?? state ?? "";
}

}
