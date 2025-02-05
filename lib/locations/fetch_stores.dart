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
    
    // Case 1: The data is a Map (typical if you set your keys manually).
    if (decoded is Map<String, dynamic>) {
      decoded.forEach((key, value) {
        // Expecting value to be a Map<String, dynamic>
        if (value is Map<String, dynamic>) {
          stores.add(BobaStore.fromJson(key, value));
        }
      });
    }
    // Case 2: The data is a List (if data was added as an array)
    else if (decoded is List) {
      for (var item in decoded) {
        if (item is Map<String, dynamic>) {
          // In this case, there's no explicit key.
          stores.add(BobaStore.fromJson('', item));
        }
      }
    }
    
    return stores;
  } else {
    throw Exception('Failed to load nearby stores');
  }

}

}
