// lib/services/geolocation_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';  // Import geocoding package

class GeolocationService {
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

  Future<String> getCityFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        // Return the locality (city) from the first Placemark
        return placemarks.first.locality ?? 'Unknown City';
      }
    } catch (e) {
      print('Error in reverse geocoding: $e');
    }
    return 'Unknown City';
  }
}
