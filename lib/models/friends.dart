import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

class FeaturedPage extends StatefulWidget {
  const FeaturedPage({Key? key}) : super(key: key);
  @override
  _FeaturedPageState createState() => _FeaturedPageState();
}

class _FeaturedPageState extends State<FeaturedPage> {
  final StoreService _storeService = StoreService();
  Position? _currentPosition;
  List<BobaStore> _nearbyStores = [];
  String? _activeStoreName;
  String? _activeStoreLocation; // "City, ST"
  bool _isLoading = true;

  // Flavor roulette
  final List<String> _flavors = [
    "Matcha Latte + Tapioca Boba",
    "Thai Tea + Mango Pearls",
    "Honeydew Tea + Aloe Vera",
    "Taro Latte + Crystal Boba",
    "Brown Sugar Milk + Cold Brew Jelly",
    "Strawberry Smoothie + Strawberry Jelly",
    "Oolong Tea + Lychee Jelly",
    "Chocolate Milk Tea + Coffee Jelly",
  ];
  String? _selectedFlavor;
  bool _spinning = false;

  @override
  void initState() {
    super.initState();
    _initLocationAndStores();
  }

  Future<void> _initLocationAndStores() async {
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final stores = await _storeService.fetchNearbyStores(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        radiusInMeters: 5000,
      );
      stores.sort((a, b) {
        final da = Geolocator.distanceBetween(_currentPosition!.latitude,
            _currentPosition!.longitude, a.latitude, a.longitude);
        final db = Geolocator.distanceBetween(_currentPosition!.latitude,
            _currentPosition!.longitude, b.latitude, b.longitude);
        return da.compareTo(db);
      });
      setState(() {
        _nearbyStores = stores.take(8).toList();
        _determineActiveStore();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching location/stores: $e");
      setState(() => _isLoading = false);
    }
  }

  void _determineActiveStore() {
    if (_currentPosition == null || _nearbyStores.isEmpty) return;
    const threshold = 20.0;
    double bestDist = double.infinity;
    BobaStore? best;
    for (var s in _nearbyStores) {
      final d = Geolocator.distanceBetween(_currentPosition!.latitude,
          _currentPosition!.longitude, s.latitude, s.longitude);
      if (d < bestDist) {
        bestDist = d;
        best = s;
      }
    }
    if (best != null && bestDist <= threshold) {
      _activeStoreName = best.name;
      _activeStoreLocation = "${best.city}, ${best.state}";
    } else {
      _activeStoreName = null;
      _activeStoreLocation = null;
    }
  }

  Future<void> _spin() async {
    if (_spinning) return;
    setState(() {
      _spinning = true;
      _selectedFlavor = null;
    });
    await Future.delayed(const Duration(milliseconds: 800));
    final rnd = Random();
    setState(() {
      _selectedFlavor = _flavors[rnd.nextInt(_flavors.length)];
      _spinning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: theme.toggleTheme,
          isDarkMode: theme.isDarkMode,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_activeStoreName != null) ...[
                      Text(
                        _activeStoreName!,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.isDarkMode ? Colors.white : Colors.black,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeStoreLocation!,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.isDarkMode
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    GestureDetector(
                      onTap: _spin,
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: _spinning
                            ? CircularProgressIndicator(
                                strokeWidth: 6,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    theme.isDarkMode
                                        ? Colors.white
                                        : Colors.brown),
                              )
                            : Image.asset(
                                'assets/spinner_cup.png',
                                fit: BoxFit.contain,
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_selectedFlavor == null && !_spinning)
                      Text(
                        "Tap the cup to spin for a flavor!",
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.isDarkMode
                              ? Colors.white70
                              : Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    if (_selectedFlavor != null)
                      Column(
                        children: [
                          Text(
                            _selectedFlavor!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: theme.isDarkMode
                                  ? Colors.white
                                  : Colors.black,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _spin,
                            icon: const Icon(Icons.refresh),
                            label: const Text("Spin Again"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.brown,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
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
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21.0),
              tooltip: 'Home',
              onPressed: () {
                final fbAuth.User? user =
                    fbAuth.FirebaseAuth.instance.currentUser;
                if (user != null && user.uid.isNotEmpty) {
                  Navigator.pushReplacementNamed(context, '/main',
                      arguments: user.uid);
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 21.0),
              tooltip: 'Map',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, size: 21.0),
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(
                context,
                '/profile',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
