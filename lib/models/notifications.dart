import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
//import 'package:test/services/store_service.dart';
import 'package:test/widgets/app_bar_content.dart';
//import 'package:test/models/boba_store.dart'; // Ensure this matches your file structure

class NotificationsPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const NotificationsPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  _NotificationsPageState createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final StoreService _storeService = StoreService();
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  BitmapDescriptor? bobaMarkerIcon;
  String? _mapStyle;
  LatLng? _currentLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _loadMapStyle();
    _getUserLocation().then((_) {
      _fetchStoresUsingAlgorithm();
    });
    // Simulate splash screen delay
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
      });
    });
  }

  Future<void> _loadCustomMarker() async {
    // Load your custom boba-themed marker image.
    BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(15, 15)),
      'assets/capy_boba.png',
    ).then((icon) {
      setState(() {
        bobaMarkerIcon = icon;
      });
    });
  }

  Future<void> _loadMapStyle() async {
    // Optionally load a custom map style (e.g., from assets/map_style.json).
    // String style = await DefaultAssetBundle.of(context)
    //     .loadString('assets/map_style.json');
    // setState(() {
    //   _mapStyle = style;
    // });
  }

  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
      });
      // If the map is already created, move the camera.
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
      // Assume BobaStore has double fields: latitude, longitude, and a string id and name.
      double lat = store.latitude;
      double lng = store.longitude;
      newMarkers.add(
        Marker(
          markerId: MarkerId(store.id),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(title: store.name),
          icon: bobaMarkerIcon ?? BitmapDescriptor.defaultMarker,
        ),
      );
    }
    setState(() {
      _markers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_mapStyle != null) {
      _mapController!.setMapStyle(_mapStyle);
    }
    // Center the map on the user's location if available.
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
    // While loading, display only your splash screen.
    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: const AppBarContent(),
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
                // Display only your splash logo.
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
      // Once loading is complete, show the interactive map.
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: const AppBarContent(),
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
                tooltip: 'Reviews',
                onPressed: () => Navigator.pushNamed(context, '/review'),
              ),
              IconButton(
                icon: const Icon(Icons.people_alt_outlined, size: 21.0),
                tooltip: 'QR Code',
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.home_outlined, size: 21.0),
                tooltip: 'Home',
                onPressed: () => Navigator.pushNamed(context, '/main'),
              ),
              IconButton(
                icon: const Icon(Icons.discount_outlined, size: 21.0),
                tooltip: 'Notifications',
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
