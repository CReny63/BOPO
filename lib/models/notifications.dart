import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http; // For API calls
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
import 'package:test/services/theme_provider.dart'; // Your ThemeProvider
import 'package:test/widgets/app_bar_content.dart';

/// Helper function to fetch accurate coordinates using Google Place ID.
Future<LatLng> fetchAccurateLocation(String placeId) async {
  final url = 'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=$placeId&fields=geometry&key=AIzaSyA31WEvdpAzW1hBlkYYBwQFoUn1NIywCHg';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(response.body);
    final location = jsonResponse['result']['geometry']['location'];
    return LatLng(location['lat'], location['lng']);
  }
  throw Exception('Failed to fetch location');
}

/// Helper function to cache the fetched accurate location (valid for 1 hour).
Future<LatLng> getCachedAccurateLocation(String placeId) async {
  final prefs = await SharedPreferences.getInstance();
  final cacheKey = "accurateLocation_$placeId";
  final cacheTimestampKey = "accurateLocationTimestamp_$placeId";
  final cachedLocation = prefs.getString(cacheKey);
  final cachedTimestamp = prefs.getInt(cacheTimestampKey);

  // Validity period: 1 hour (3600 seconds)
  const int validityPeriod = 3600;
  final currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  if (cachedLocation != null &&
      cachedTimestamp != null &&
      (currentTimestamp - cachedTimestamp) < validityPeriod) {
    final parts = cachedLocation.split(",");
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0]);
      final lng = double.tryParse(parts[1]);
      if (lat != null && lng != null) {
        return LatLng(lat, lng);
      }
    }
  }

  // If no valid cache exists, fetch new data.
  final accurateLocation = await fetchAccurateLocation(placeId);
  await prefs.setString(cacheKey, "${accurateLocation.latitude},${accurateLocation.longitude}");
  await prefs.setInt(cacheTimestampKey, currentTimestamp);
  return accurateLocation;
}

class NotificationsPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const NotificationsPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final StoreService _storeService = StoreService();
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  BitmapDescriptor? bobaMarkerIcon;
  LatLng? _currentLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _getUserLocation().then((_) {
      _fetchStoresUsingAlgorithm();
    });
    // Simulate splash screen delay.
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  /// Loads and resizes a marker asset.
  Future<BitmapDescriptor> getResizedMarker(String assetPath, int width) async {
    ByteData data = await rootBundle.load(assetPath);
    ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    ui.FrameInfo fi = await codec.getNextFrame();
    final ByteData? byteData =
        await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadCustomMarker() async {
    BitmapDescriptor icon = await getResizedMarker('assets/capy_boba.png', 85);
    setState(() {
      bobaMarkerIcon = icon;
    });
  }

  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      if (_mapController != null && _currentLocation != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _currentLocation!, zoom: 14),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error fetching user location: $e");
    }
  }

  Future<void> _fetchStoresUsingAlgorithm() async {
    if (_currentLocation == null) return;
    // Use your algorithm to fetch nearby stores.
    List<BobaStore> stores = await _storeService.fetchNearbyStores(
      latitude: _currentLocation!.latitude,
      longitude: _currentLocation!.longitude,
      radiusInMeters: 5000,
    );
    Set<Marker> newMarkers = {};
    for (BobaStore store in stores) {
      // Start with the approximate coordinates.
      LatLng markerPosition = LatLng(store.latitude, store.longitude);

      // If a valid Google Place ID exists, fetch its accurate coordinate.
      if (store.googlePlaceId.isNotEmpty) {
        try {
          LatLng accurateLocation = await getCachedAccurateLocation(store.googlePlaceId);
          markerPosition = accurateLocation;
          debugPrint("Accurate location for ${store.name}: $markerPosition");
        } catch (e) {
          debugPrint("Error fetching accurate location for ${store.name}: $e");
        }
      }

      newMarkers.add(
        Marker(
          markerId: MarkerId(store.id),
          position: markerPosition,
          infoWindow: InfoWindow(title: store.name),
          icon: bobaMarkerIcon ?? BitmapDescriptor.defaultMarker,
          // Adjust anchor so the bottom center of the marker image aligns with the location.
          anchor: const Offset(0.5, 1.0),
        ),
      );
    }
    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  /// Clears the cached location data and refreshes the markers.
  Future<void> _clearCacheAndRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith("accurateLocation_") || key.startsWith("accurateLocationTimestamp_")) {
        await prefs.remove(key);
      }
    }
    await _fetchStoresUsingAlgorithm();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_currentLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentLocation!, zoom: 14),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtain the theme provider from context.
    final themeProvider = Provider.of<ThemeProvider>(context);

    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: themeProvider.toggleTheme,
            isDarkMode: themeProvider.isDarkMode,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 228, 197, 171),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFF1ECE9),
                Color(0xFFFFFFFF),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/capy_boba.png', width: 100, height: 100),
                const SizedBox(height: 20),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: themeProvider.toggleTheme,
            isDarkMode: themeProvider.isDarkMode,
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 228, 197, 171),
        body: GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _currentLocation ?? const LatLng(37.7749, -122.4194),
            zoom: 12,
          ),
          markers: _markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
        ),
        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.star_outline, size: 21.0),
                tooltip: 'Visits',
                onPressed: () => Navigator.pushNamed(context, '/review'),
              ),
              IconButton(
                icon: const Icon(Icons.emoji_food_beverage_outlined, size: 21.0),
                tooltip: 'Featured',
                onPressed: () => Navigator.pushNamed(context, '/friends'),
              ),
              IconButton(
                icon: const Icon(Icons.home_outlined, size: 21.0),
                tooltip: 'Home',
                onPressed: () => Navigator.pushNamed(context, '/main'),
              ),
              IconButton(
                icon: const Icon(Icons.map_outlined, size: 21.0),
                tooltip: 'Map',
                onPressed: () {}, // Already on this page.
              ),
              IconButton(
                icon: const Icon(Icons.person_outline, size: 21.0),
                tooltip: 'Profile',
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      );
    }
  }
}
