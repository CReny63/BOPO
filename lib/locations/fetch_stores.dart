// lib/services/store_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'boba_store.dart';
import 'geolocator.dart';

class StoreService {
 final String apiEndpoint = 'https://bopo-f6eeb-default-rtdb.firebaseio.com/stores.json';
  final GeolocationService _geolocationService = GeolocationService();

  Future<Position> determinePosition() async {
    return await _geolocationService.determinePosition();
  }

Future<List<BobaStore>> fetchNearbyStores({
  required double latitude,
  required double longitude,
  double radiusInMeters = 5000,
}) async {
  final url = Uri.parse(apiEndpoint);
  final response = await http.get(url);

  if (response.statusCode == 200) {
    final dynamic decoded = json.decode(response.body);
    List<BobaStore> stores = [];

    if (decoded is Map<String, dynamic>) {
      // The top-level keys are city names.
      decoded.forEach((cityName, cityData) {
        // Make sure cityData is a Map of store records.
        if (cityData is Map<String, dynamic>) {
          // Iterate only over the inner store records.
          cityData.forEach((storeKey, storeData) {
            if (storeData is Map<String, dynamic>) {
              // Inject the city name into the store data if desired.
              storeData['city'] = cityName;

              // Check if the store data contains a nonempty 'imagename'.
              String? imageName = storeData['imagename']?.toString().trim();
              String? name = storeData['name']?.toString().trim();

              if (imageName != null &&
                  imageName.isNotEmpty &&
                  name != null &&
                  name.isNotEmpty) {
                // Process the individual store record.
                stores.add(BobaStore.fromJson(storeKey, storeData));
                print("Added store '$storeKey' in '$cityName' with imagename='$imageName' and name='$name'");
              } else {
                print("Skipping store '$storeKey' in '$cityName' because 'imagename' or 'name' is missing/empty");
              }
            }
          });
          print("City '$cityName' processed.");
        } else {
          print("Skipping city '$cityName' because its data is not a Map<String, dynamic>.");
        }
      });
    } else {
      print("Unexpected data format: decoded data is not a Map<String, dynamic>.");
    }

    print("Total stores parsed: ${stores.length}");
    return stores;
  } else {
    throw Exception('Failed to load nearby stores');
  }
}

}
