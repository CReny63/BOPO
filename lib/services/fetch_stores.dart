// lib/services/store_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/boba_store.dart';
//import 'geolocation_service.dart';
import 'geolocator.dart';

class StoreService {
  final String apiEndpoint = 'https://yourapi.com/nearbyStores'; // Replace with your API endpoint
  final GeolocationService _geolocationService = GeolocationService();

  Future<Position> determinePosition() async {
    return await _geolocationService.determinePosition();
  }

  Future<List<BobaStore>> fetchNearbyStores({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000,
  }) async {
    final url = Uri.parse('$apiEndpoint?lat=$latitude&lng=$longitude&radius=$radiusInMeters');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> jsonList = json.decode(response.body);
      return jsonList.map((jsonItem) => BobaStore.fromJson(jsonItem)).toList();
    } else {
      throw Exception('Failed to load nearby stores');
    }
  }
}
