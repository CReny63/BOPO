import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'boba_store.dart';
import 'geolocator.dart';

class StoreService {
  static const _apiEndpoint =
      'https://bopo-f6eeb-default-rtdb.firebaseio.com/stores.json';

  final GeolocationService _geo = GeolocationService();
  final http.Client _client;

  StoreService({http.Client? client}) : _client = client ?? http.Client();

  /// Gets the user’s current position.
  Future<Position> determinePosition() => _geo.determinePosition();

  /// Fetches all stores, then returns only those within [radiusInMeters]
  /// of the given [latitude], [longitude].
  Future<List<BobaStore>> fetchNearbyStores({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000,
  }) async {
    final url = Uri.parse(_apiEndpoint);
    final response = await _client.get(url);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stores (HTTP ${response.statusCode})');
    }

    // Offload JSON parsing & distance filtering to a background isolate.
    return await compute<_ParseAndFilterParams, List<BobaStore>>(
      _parseAndFilterStores,
      _ParseAndFilterParams(
        jsonBody: response.body,
        userLat: latitude,
        userLon: longitude,
        radius: radiusInMeters,
      ),
    );
  }
}

/// Params for the isolate worker
class _ParseAndFilterParams {
  final String jsonBody;
  final double userLat, userLon, radius;
  _ParseAndFilterParams({
    required this.jsonBody,
    required this.userLat,
    required this.userLon,
    required this.radius,
  });
}

/// Runs in a background isolate: parses the Firebase JSON and filters by distance.
List<BobaStore> _parseAndFilterStores(_ParseAndFilterParams p) {
  final Map<String, dynamic> root = json.decode(p.jsonBody) as Map<String, dynamic>;
  final List<BobaStore> stores = [];

  root.forEach((cityName, cityData) {
    if (cityData is Map<String, dynamic>) {
      cityData.forEach((storeKey, storeValue) {
        if (storeValue is Map<String, dynamic>) {
          final data = Map<String, dynamic>.from(storeValue)
            ..['city'] = cityName;
          final store = BobaStore.fromJson(storeKey, data);
          final dist = _haversineDistance(
            p.userLat, p.userLon, store.latitude, store.longitude);
          if (dist <= p.radius) {
            stores.add(store);
          }
        }
      });
    }
  });

  return stores;
}

/// Calculates distance in meters between two coords using Haversine formula.
double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2) {
  const R = 6371000; // Earth radius in meters
  final dLat = _toRad(lat2 - lat1);
  final dLon = _toRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

double _toRad(double deg) => deg * pi / 180;
