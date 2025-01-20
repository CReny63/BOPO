import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class GeolocationService {
  // ...existing determinePosition()...

  Future<String> getCityFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String city = place.locality ?? 'Unknown City';
        String state = place.administrativeArea ?? '';
        return '$city, $state';  // Combine city and state abbreviation
      }
    } catch (e) {
      print('Error reverse geocoding: $e');
    }
    return 'Unknown City';
  }
}
