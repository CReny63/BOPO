import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/locations/firestore.dart';
import 'package:test/locations/geolocator.dart';
import 'package:test/locations/nearby_stores.dart';
import 'package:test/widgets/Greeting.dart';
// import 'package:test/models/boba_store.dart';
// import 'package:test/services/geolocation_service.dart';
//import 'package:test/widgets/circular_layout.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:test/widgets/carousel_widget.dart';
import 'package:test/widgets/chatbot_popup.dart';
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
  final FirestoreService _firestoreService = FirestoreService();
  String userCity = 'Loading...';

  // Store the last known position
  Position? _lastKnownPosition;

  // Create a mutable copy of bobaStores to sort based on distance
  late List<BobaStore> sortedStores = List.from(bobaStores);

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

  Future<void> fetchFirestoreData() async {
  try {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('stores') //get stores
        .where('city', isEqualTo: userCity) // Match user's city
        .get();

    sortedStores = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return BobaStore(
        name: data['name'],
        imageName: data['imagename'],
        qrData: data['qrdata'],
        id: doc.id,
        latitude: data['latitude'],
        longitude: data['longitude'],
        city: data['city'],
      );
    }).toList();

    setState(() {}); // Update the UI with the fetched data
  } catch (e) {
    print('Error fetching Firestore data: $e');
  }
}



  // Fetch stores by city
  Future<void> _fetchStoresByCity(String city) async {
  try {
    // Fetch new stores from Firestore
    List<BobaStore> fetchedStores = await _firestoreService.fetchStoresByCity(city);

    // Merge fetched stores with existing ones while avoiding duplicates
    setState(() {
      final fetchedStoreIds = fetchedStores.map((store) => store.id).toSet();
      sortedStores = [
        ...sortedStores.where((store) => !fetchedStoreIds.contains(store.id)), // Keep old stores not in fetched list
        ...fetchedStores, // Add fetched stores
      ];
    });
  } catch (e) {
    print('Error fetching stores by city: $e');
  }
}


Future<void> _sortStoresByDistance() async {
  try {
    Position userPosition = await _geoService.determinePosition();
    _lastKnownPosition = userPosition;
    
    // Directly retrieve and assign the city since it's non-nullable
    userCity = await _geoService.getCityFromPosition(userPosition);

    // Fetch stores using the determined city
    await _fetchStoresByCity(userCity);

    // Sort stores by distance
    _sortStoresByDistanceWithPosition(userPosition);
  } catch (e) {
    if (kDebugMode) {
      print('Error determining position or sorting stores: $e');
    }
  }
}



//based on users location present stores nearby to user.
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

    const double maxDistance = 50000; // 50 km threshold
    sortedStores = sortedStores.where((store) {
      double distance = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        store.latitude,
        store.longitude,
      );
      return distance <= maxDistance;
    }).toList();

    setState(() {}); // Update UI after sorting/filtering
  }

 @override
Widget build(BuildContext context) {
  // Calculate responsive radius based on screen size
  final double screenWidth = MediaQuery.of(context).size.width;
  final double screenHeight = MediaQuery.of(context).size.height;
  final double radius = min(screenWidth, screenHeight) / 4;

  // Wait until we have a valid user position before building the main UI
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

  // Greeting and date functions
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
            // Replace CircularLayout with NearbyStoresWidget
              SizedBox(
                height: 400,  // adjust height as needed
                child: NearbyStoresWidget(),
              ),
            // You can keep other widgets like CarouselWidget, PromoBanner, etc. below
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
