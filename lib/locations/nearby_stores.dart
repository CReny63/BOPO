import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/geolocator.dart';
import 'package:test/widgets/circular_layout.dart'; // Use the updated circular layout

class NearbyStoresWidget extends StatefulWidget {
  const NearbyStoresWidget({super.key, required List<BobaStore> stores, required Position userPosition, required String userLocationText});

  @override
  _NearbyStoresWidgetState createState() => _NearbyStoresWidgetState();
}

class _NearbyStoresWidgetState extends State<NearbyStoresWidget> {
  final String apiEndpoint = 'https://bopo-f6eeb-default-rtdb.firebaseio.com/stores.json';//Realtime Database endpoint (with .json)
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
      // Get the user's current position.
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

        // Iterate over the structure:
        // Top-level: cities. Under each city: stores.
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((cityName, cityData) {
            if (cityData is Map<String, dynamic>) {
              cityData.forEach((storeKey, storeData) {
                if (storeData is Map<String, dynamic>) {
                  // Inject the city name into the store data.
                  storeData['city'] = cityName;
                  // You can also perform additional validations here if needed.
                  fetchedStores.add(BobaStore.fromJson(storeKey, storeData));
                 // print("Added store '$storeKey' in '$cityName' with " "imagename='${storeData['imagename']}', name='${storeData['name']}'");
                }
              });
              //print("City '$cityName' processed.");
            } else {
              //print("Skipping city '$cityName' because its data is not a Map.");
            }
          });
        } else if (decoded is List) {
          // Handle the case where data is returned as a List (if applicable).
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              fetchedStores.add(BobaStore.fromJson('', item));
            }
          }
        }
        print("Total stores parsed: ${fetchedStores.length}");
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
      return const Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return const Center(child: Text('No stores found.'));
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
