import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/services/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
import 'package:test/widgets/app_bar_content.dart';
//import 'package:test/themeprovide.dart'; // your ThemeProvider file

class FeaturedPage extends StatefulWidget {
  const FeaturedPage({Key? key}) : super(key: key);

  @override
  _FeaturedPageState createState() => _FeaturedPageState();
}

class _FeaturedPageState extends State<FeaturedPage> {
  final StoreService _storeService = StoreService();
  List<BobaStore> _nearbyStores = [];
  Position? _currentPosition;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _getUserLocation().then((_) {
      _fetchNearbyStores();
    });
  }

  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentPosition = pos;
      });
    } catch (e) {
      debugPrint("Error fetching user location: $e");
    }
  }

  Future<void> _fetchNearbyStores() async {
    if (_currentPosition == null) return;
    // Fetch nearby stores using your custom service.
    List<BobaStore> stores = await _storeService.fetchNearbyStores(
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      radiusInMeters: 5000,
    );
    setState(() {
      _nearbyStores = stores;
      _isLoading = false;
    });
  }

  // Future<void> _refreshStores() async {
  //   setState(() {
  //     _isLoading = true;
  //   });
  //   await _getUserLocation();
  //   await _fetchNearbyStores();
  // }

  /// Helper function to construct the asset image path.
  String _getAssetPath(String imageName) {
    String path = imageName;
    if (!path.startsWith('assets/')) {
      path = 'assets/$path';
    }
    if (!path.endsWith('.png')) {
      path = '$path.png';
    }
    return path;
  }

  /// Launches Google Maps for the given address.
  Future<void> _launchMaps(String address) async {
    final query = Uri.encodeComponent(address);
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      debugPrint("Could not launch Maps for address: $address");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Obtain the theme values from ThemeProvider.
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      // Use your original AppBarContent with the three-line menu and light/dark toggle.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: themeProvider.toggleTheme,
          isDarkMode: themeProvider.isDarkMode,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.brown),
              ),
            )
          : _nearbyStores.isEmpty
              ? Center(child: Text("No nearby stores found."))
              : CarouselSlider.builder(
                  itemCount: _nearbyStores.length,
                  itemBuilder: (context, index, realIndex) {
                    final store = _nearbyStores[index];
                    // Build the asset image path for the drink image.
                    final imagePath = _getAssetPath(store.imageName);
                    // Construct the store address.
                    final address =
                        "${store.address}, ${store.city}, ${store.state}";
                    // Use store.name as a placeholder for the drink name.
                    final drinkName = store.name;
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Background: Drink image.
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              imagePath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          ),
                          // Top overlay: Drink Name in larger font.
                          Positioned(
                            top: 10,
                            left: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              color: Colors.black54,
                              child: Text(
                                drinkName,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Bottom overlay: Store Address (clickable to open Maps).
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: InkWell(
                              onTap: () => _launchMaps(address),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black54,
                                child: Text(
                                  address,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(color: Colors.white),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  options: CarouselOptions(
                    height: MediaQuery.of(context).size.height * 0.75,
                    enlargeCenterPage: true,
                    enableInfiniteScroll: false,
                    autoPlay: true,
                  ),
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
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
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
