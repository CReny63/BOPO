import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/models/boba_store.dart';
import 'package:test/services/boba_store_qr_code_page.dart';
//import 'package:test/services/geolocation_service.dart';
import 'package:test/services/geolocator.dart';
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

  // Create a mutable copy of bobaStores to sort based on distance
  late List<BobaStore> sortedStores = List.from(bobaStores);

  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    // Initial sort based on current location
    _sortStoresByDistance();
    // Listen for location changes and update sorting dynamically
    _positionStream = Geolocator.getPositionStream().listen((position) {
      _sortStoresByDistanceWithPosition(position);
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _sortStoresByDistance() async {
    try {
      Position userPosition = await _geoService.determinePosition();
      _sortStoresByDistanceWithPosition(userPosition);
    } catch (e) {
      print('Error determining position or sorting stores: $e');
      // Handle error as needed
    }
  }

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
    setState(() {}); // Update UI after sorting
  }

  @override
  Widget build(BuildContext context) {
    // Calculate responsive radius based on screen size
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double radius = min(screenWidth, screenHeight) / 4;

    // Greeting and date functions
    String getGreeting() {
      final hour = DateTime.now().hour;
      if (hour < 12) return 'Good Morning';
      if (hour < 17) return 'Good Afternoon';
      return 'Good Evening';
    }

    String getCurrentDate() {
      final now = DateTime.now();
      return '${now.month}/${now.day}/${now.year}';
    }

    final String greeting = getGreeting();
    final String currentDate = getCurrentDate();

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
              const SizedBox(height: 100), 
              Center(
                child: CircularLayout(
                  radius: radius,
                  centralWidget: Container(
                    width: radius,
                    height: radius,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                  bobaStores: sortedStores,
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
          // Trigger chatbot popup
          showDialog(
            context: context,
            builder: (context) => const ChatbotPopup(),
          );
        },
        backgroundColor:
            Theme.of(context).floatingActionButtonTheme.backgroundColor,
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
