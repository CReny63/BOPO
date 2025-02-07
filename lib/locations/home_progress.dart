import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/fetch_stores.dart';
import 'package:test/locations/geolocator.dart';
import 'package:test/locations/nearby_stores.dart';
import 'package:test/widgets/Greeting.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:test/widgets/carousel_widget.dart';
import 'package:test/widgets/chatbot_popup.dart';
import 'package:test/widgets/circular_layout.dart';
import 'package:test/widgets/promo.dart';
import 'package:test/widgets/social_media.dart';

class HomeWithProgress extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback toggleTheme;

  const HomeWithProgress({
    Key? key,
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  @override
  HomeWithProgressState createState() => HomeWithProgressState();
}

class HomeWithProgressState extends State<HomeWithProgress> {
  final Set<String> scannedStoreIds = {};
  double progressValue = 0.0;
  final GeolocationService _geoService = GeolocationService();
  final StoreService _storeService = StoreService(); // Our Realtime DB service
  String city = 'Loading...';

  // Declare these as instance variables so they’re in scope in build().
  Position? _lastKnownPosition;
  List<BobaStore> sortedStores = [];

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
        });
        // Debug print to verify realtime data:
        print("Realtime fetched stores:");
        for (var store in sortedStores) {
          print("Store: name=${store.name}, imageName=${store.imageName}, city=${store.city}");
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
      _lastKnownPosition = userPosition;
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

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double radius = min(screenWidth, screenHeight) / 4;

    // Show a progress indicator if we don't have a valid position.
    if (_lastKnownPosition == null) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    String greeting = getGreeting();
    String currentDate = getCurrentDate();

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: widget.toggleTheme,
          isDarkMode: widget.isDarkMode,
        ),
      ),
      body: SingleChildScrollView(
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
              // Use the realtime-fetched list via NearbyStoresWidget.
              SizedBox(
                height: 400,
                child: NearbyStoresWidget(
                  stores: sortedStores, // Pass our realtime data list.
                  userPosition: _lastKnownPosition!,
                  userLocationText: city,
                ),
              ),
              const SizedBox(height: 100),
              Center(child: CarouselWidget()),
              const SizedBox(height: 120),
              const PromoBanner(),
              const SizedBox(height: 30),
              const SocialMediaLinks(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const ChatbotPopup(),
          );
        },
        backgroundColor: Theme.of(context).floatingActionButtonTheme.backgroundColor,
        child: const Icon(Icons.chat),
      ),
      bottomNavigationBar: buildBottomNavBar(context),
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
            icon: const Icon(Icons.star_half_sharp, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/review');
            },
            tooltip: 'Reviews',
          ),
          IconButton(
            icon: const Icon(Icons.home, size: 21.0),
            onPressed: () {},
            tooltip: 'Home',
          ),
          IconButton(
            icon: const Icon(Icons.qr_code, size: 30.0),
            onPressed: () {
              Navigator.pushNamed(context, '/qr_code');
            },
            tooltip: 'QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, size: 21.0),
            onPressed: () {
              Navigator.pushNamed(context, '/notifications');
            },
            tooltip: 'Notifications',
          ),
          IconButton(
            icon: const Icon(Icons.person, size: 21.0),
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
