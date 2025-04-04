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
      debugPrint("User position: $_currentPosition");
    } catch (e) {
      debugPrint("Error fetching user location: $e");
    }
  }

  Future<void> _fetchNearbyStores() async {
    if (_currentPosition == null) return;
    try {
      // Fetch all stores from your service.
      List<BobaStore> stores = await _storeService.fetchNearbyStores(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInMeters: 5000,
      );
      debugPrint("Fetched ${stores.length} stores from service.");

      // Sort stores by distance (closest first).
      stores.sort((a, b) {
        double distanceA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          a.latitude,
          a.longitude,
        );
        double distanceB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          b.latitude,
          b.longitude,
        );
        return distanceA.compareTo(distanceB);
      });

      // First, collect unique stores by 'namefeat'.
      List<BobaStore> uniqueStores = [];
      Set<String> seenFeatured = {};
      for (BobaStore store in stores) {
        String feat = store.namefeat.trim();
        if (feat.isNotEmpty && !seenFeatured.contains(feat)) {
          uniqueStores.add(store);
          seenFeatured.add(feat);
          debugPrint("Added unique store ${store.id} with featured drink: '$feat'");
        }
      }
      debugPrint("Unique featured stores count: ${uniqueStores.length}");

      // If there are fewer than 8 unique items, add additional stores from sorted list.
      if (uniqueStores.length < 8) {
        for (BobaStore store in stores) {
          if (!uniqueStores.contains(store)) {
            uniqueStores.add(store);
            if (uniqueStores.length >= 8) break;
          }
        }
        debugPrint("Filled up to ${uniqueStores.length} stores after adding duplicates.");
      }

      // Limit to exactly 8 items if there are more.
      if (uniqueStores.length > 8) {
        uniqueStores = uniqueStores.sublist(0, 8);
      }

      setState(() {
        _nearbyStores = uniqueStores;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching nearby stores: $e");
    }
  }

  /// Helper function to construct the asset image path.
  String _getAssetPath(String imagefeat) {
    String path = imagefeat;
    debugPrint("Raw imagefeat: '$imagefeat'");
    if (!path.startsWith('assets/')) {
      path = 'assets/$path';
    }
    if (!path.endsWith('.png')) {
      path = '$path.png';
    }
    debugPrint("Computed asset path: '$path'");
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
                    
                    // Debug prints for each store.
                    debugPrint("Building carousel item for store id: ${store.id}");
                    debugPrint("Store imagefeat: '${store.imagefeat}'");
                    debugPrint("Store namefeat: '${store.namefeat}'");
                    
                    // Use the new attribute imagefeat for the image.
                    final imagePath = _getAssetPath(store.imagefeat);
                    
                    // Use the new attribute namefeat for the bottom overlay.
                    final featuredName = store.namefeat;
                    
                    // Use store.name as the top overlay (e.g., drink name).
                    final drinkName = store.name;
                    
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        children: [
                          // Background: Drink image from imagefeat.
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
                          // Bottom overlay: Featured name (namefeat).
                          Positioned(
                            bottom: 10,
                            left: 10,
                            right: 10,
                            child: InkWell(
                              onTap: () {
                                // Optionally, you could launch maps using another attribute.
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                color: Colors.black54,
                                child: Text(
                                  featuredName,
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
