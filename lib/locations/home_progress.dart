import 'dart:async';
import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
import 'package:test/locations/geolocator.dart';
import 'package:test/locations/nearby_stores.dart';
import 'package:test/widgets/Greeting.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:test/widgets/missionScreen.dart';
import 'package:test/widgets/promo.dart';
import 'package:test/widgets/social_media.dart';
import 'package:cached_network_image/cached_network_image.dart';

class HomeWithProgress extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const HomeWithProgress({
    super.key,
    required this.isDarkMode,
    required this.toggleTheme,
  });

  @override
  HomeWithProgressState createState() => HomeWithProgressState();
}

class HomeWithProgressState extends State<HomeWithProgress> {
  final Set<String> scannedStoreIds = {};
  double progressValue = 0.0;
  final GeolocationService _geoService = GeolocationService();
  final StoreService _storeService = StoreService(); // Our Realtime DB service
  String city = 'Loading...';

  // Instance variables for location and stores.
  Position? _lastKnownPosition;
  List<BobaStore> sortedStores = [];
  BobaStore? selectedStore; // This is our store object.

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _sortStoresByDistance();
    _positionStream = Geolocator.getPositionStream().listen((position) {
      _lastKnownPosition = position;
      _sortStoresByDistanceWithPosition(position);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  /// Fetch stores from the Realtime Database.
  Future<void> _fetchStores() async {
    try {
      if (_lastKnownPosition != null) {
        List<BobaStore> fetchedStores = await _storeService.fetchNearbyStores(
          latitude: _lastKnownPosition!.latitude,
          longitude: _lastKnownPosition!.longitude,
          radiusInMeters: 5000,
        );
        setState(() {
          sortedStores = fetchedStores;
          // Optionally set a selected store (e.g. the closest one).
          if (sortedStores.isNotEmpty) {
            selectedStore = sortedStores.first;
          }
        });
        // Debug print to verify realtime data:
        if (kDebugMode) {
          print("Realtime fetched stores:");
          for (var store in sortedStores) {
            print(
                "Store: name=${store.name}, imageName=${store.imageName}, city=${store.city}");
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stores: $e');
      }
    }
  }

  /// Determine position, fetch stores, and sort them.
  Future<void> _sortStoresByDistance() async {
    try {
      Position userPosition = await _geoService.determinePosition();
      setState(() {
        _lastKnownPosition = userPosition;
      });
      city = await _geoService.getLocationText(userPosition);
      await _fetchStores();
      _sortStoresByDistanceWithPosition(userPosition);
    } catch (e) {
      if (kDebugMode) {
        print('Error determining position or sorting stores: $e');
      }
    }
  }

  /// Sort stores by distance from the given position.
  void _sortStoresByDistanceWithPosition(Position userPosition) {
    sortedStores.sort((a, b) {
      double distanceA = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        a.latitude,
        a.longitude,
      );
      double distanceB = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        b.latitude,
        b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });

    const double maxDistance = 50000; // 50 km
    sortedStores = sortedStores.where((store) {
      double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        store.latitude,
        store.longitude,
      );
      return distance <= maxDistance;
    }).toList();

    // Update selectedStore if available.
    if (sortedStores.isNotEmpty) {
      selectedStore = sortedStores.first;
    }

    setState(() {});
  }

  /// Refresh callback for pull-to-refresh.
  Future<void> _handleRefresh() async {
    setState(() {
      _lastKnownPosition = null;
      sortedStores = [];
    });
    await _sortStoresByDistance();
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  void processStoreScan(String storeId) {
    if (!scannedStoreIds.contains(storeId)) {
      setState(() {
        scannedStoreIds.add(storeId);
      });
      // Optionally update backend or local storage here.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_lastKnownPosition == null) {
      return WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(75),
            child: const AppBarContent(),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    String greeting = getGreeting();
    String currentDate = getCurrentDate();

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: const AppBarContent(),
        ),
        body: CustomRefreshIndicator(
          onRefresh: _handleRefresh,
          builder: (BuildContext context, Widget child, IndicatorController controller) {
            return Stack(
              alignment: Alignment.topCenter,
              children: [
                Transform.translate(
                  offset: Offset(0, controller.value * 100 - 50),
                  child: Opacity(
                    opacity: min(controller.value, 1.0),
                    child: Image.asset(
                      'assets/capy_boba.png',
                      width: 50,
                      height: 50,
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, controller.value * 100),
                  child: child,
                ),
              ],
            );
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 21,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontFamily: 'Roboto',
                    ),
                  ),
                  Text(
                    currentDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 400,
                    child: NearbyStoresWidget(
                      stores: sortedStores,
                      userPosition: _lastKnownPosition!,
                      userLocationText: city,
                    ),
                  ),
                  const SizedBox(height: 120),
                  const PromoBanner(),
                  const SizedBox(height: 30),
                  const SocialMediaLinks(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (selectedStore != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MissionsScreen(
                    scannedStoreIds: scannedStoreIds,
                    userId: FirebaseAuth.instance.currentUser?.uid ?? 'defaultUserId',
                    storeId: selectedStore!.id,
                    storeLatitude: selectedStore!.latitude,
                    storeLongitude: selectedStore!.longitude,
                    storeCity: selectedStore!.city,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No store selected.')),
              );
            }
          },
          backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor,
          child: const Icon(Icons.assignment),
        ),
        bottomNavigationBar: buildBottomNavBar(context),
      ),
    );
  }

  Widget buildBottomNavBar(BuildContext context) {
    return BottomAppBar(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(Icons.star_outline, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/review');
            },
            tooltip: 'Favorites',
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/qr_code');
            },
            tooltip: 'Friends',
          ),
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 21.0),
            onPressed: () {},
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.discount_outlined, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
            tooltip: 'Promotions',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/profile');
            },
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}
