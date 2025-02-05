import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/geolocator.dart';
import 'package:test/widgets/circular_layout.dart'; // Use the updated circular layout

class NearbyStoresWidget extends StatefulWidget {
  @override
  _NearbyStoresWidgetState createState() => _NearbyStoresWidgetState();
}

class _NearbyStoresWidgetState extends State<NearbyStoresWidget> {
  // Your Realtime Database endpoint (with .json)
  final String apiEndpoint = 'https://bopo-f6eeb-default-rtdb.firebaseio.com/stores.json';
  List<BobaStore> stores = [];
  bool isLoading = true;
  Position? userPosition;
  String userLocationText = 'Your Location'; // Placeholder
  final GeolocationService _geoService = GeolocationService();


  @override
  void initState() {
    super.initState();
    _fetchUserPositionAndStores();
  }

  Future<void> _fetchUserPositionAndStores() async {
    try {
      // First, get the user's current position.
      userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
       // Dynamically fetch the user's location text (city and state).
    userLocationText = await _geoService.getLocationText(userPosition!);

      // Then, fetch the stores from your Realtime Database.
      final url = Uri.parse(apiEndpoint);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<BobaStore> fetchedStores = [];

        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              fetchedStores.add(BobaStore.fromJson(key, value));
            }
          });
        } else if (decoded is List) {
          // Handle case where data is returned as a List.
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              fetchedStores.add(BobaStore.fromJson('', item));
            }
          }
        }
        setState(() {
          stores = fetchedStores;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load stores');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('Error fetching stores from Realtime Database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || userPosition == null) {
      return Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return Center(child: Text('No stores found.'));
    }
    // Use the CircularLayout widget to display the stores.
    return CircularLayout(
      radius: 100, // Adjust the size as needed.
      bobaStores: stores,
      userPosition: userPosition!,
      maxDistanceThreshold: 5000, // e.g., 5000 meters (5 km)
      userLocationText: userLocationText,
    );
  }
}
