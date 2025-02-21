import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart'; // Your BobaStore class
import 'package:test/models/store_details.dart'; // Contains your StoreDetailsScreen
import 'package:test/widgets/app_bar_content.dart';

class StoresPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const StoresPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  _StoresPageState createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  // Reference to the "stores" node in Firebase Realtime Database.
  final DatabaseReference _storesRef =
      FirebaseDatabase.instance.ref().child('stores');
  Position? userPosition;
  

  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  /// Fetches the current user position.
  Future<void> _getUserLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      print("User position: $pos");
      setState(() {
        userPosition = pos;
      });
    } catch (e) {
      print("Error getting user location: $e");
    }
  }

  /// Pull-to-refresh callback: clears the current location,
  /// re-fetches it, and waits briefly for the animation.
  Future<void> _handleRefresh() async {
    setState(() {
      userPosition = null;
    });
    await _getUserLocation();
    // Optional delay so the refresh animation is visible.
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    // Show a loader until we have the user's location.
    if (userPosition == null) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: const AppBarContent(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
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
              // Animate the capybara icon during pull-to-refresh.
              Transform.translate(
                offset: Offset(0, controller.value * 100 - 50),
                child: Opacity(
                  opacity: min(controller.value, 1.0),
                  child: Image.asset(
                    'assets/capy_boba.png', // Ensure this asset exists and is listed in pubspec.yaml.
                    width: 50,
                    height: 50,
                  ),
                ),
              ),
              // Move the child (our main content) down as the pull occurs.
              Transform.translate(
                offset: Offset(0, controller.value * 100),
                child: child,
              ),
            ],
          );
        },
        child: StreamBuilder<DatabaseEvent>(
          stream: _storesRef.onValue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            }
            if (!snapshot.hasData || snapshot.data!.snapshot.value == null) {
              return const Center(child: CircularProgressIndicator());
            }

            // Debug: print raw snapshot data.
            print("Raw snapshot: ${snapshot.data!.snapshot.value}");

            // Parse the Firebase data.
            final dynamic decoded = snapshot.data!.snapshot.value;
            List<BobaStore> storeList = [];
            if (decoded is Map) {
              final Map<String, dynamic> cities = Map<String, dynamic>.from(decoded);
              cities.forEach((cityName, cityData) {
                if (cityData is Map) {
                  final Map<String, dynamic> storesMap = Map<String, dynamic>.from(cityData);
                  storesMap.forEach((storeKey, storeData) {
                    // Process only if storeData is a Map and contains a 'name'.
                    if (storeData is Map && storeData.containsKey('name')) {
                      final Map<String, dynamic> storeMap = Map<String, dynamic>.from(storeData);
                      // Inject the city name into the store data.
                      storeMap['city'] = cityName;
                      BobaStore store = BobaStore.fromJson(storeKey, storeMap);
                      storeList.add(store);
                    } else {
                      print("Skipping key '$storeKey' in city '$cityName' as it's not a valid store record.");
                    }
                  });
                  print("City '$cityName' processed with ${storesMap.length} entries.");
                } else {
                  print("Skipping city '$cityName' because its data is not a Map.");
                }
              });
            } else {
              print("Decoded data is not a Map.");
            }

            print("Total stores parsed: ${storeList.length}");
            if (storeList.isEmpty) {
              return const Center(child: Text("No stores found."));
            }

            // Sort the stores by distance from the user.
            storeList.sort((a, b) {
              double distanceA = Geolocator.distanceBetween(
                userPosition!.latitude,
                userPosition!.longitude,
                a.latitude,
                a.longitude,
              );
              double distanceB = Geolocator.distanceBetween(
                userPosition!.latitude,
                userPosition!.longitude,
                b.latitude,
                b.longitude,
              );
              return distanceA.compareTo(distanceB);
            });

            // For debugging, display all stores.
            List<BobaStore> displayStores = storeList;

            // For each store, if the user is within 100 meters, update the visit count.
            for (BobaStore store in displayStores) {
              double distance = Geolocator.distanceBetween(
                userPosition!.latitude,
                userPosition!.longitude,
                store.latitude,
                store.longitude,
              );
              if (distance < 100) {
                int currentVisits = store.visits;
                currentVisits++;
                store.visits = currentVisits;
                print("Incrementing visits for store ${store.id}, new visits: $currentVisits");
                _storesRef.child(store.id).update({'visits': currentVisits});
              }
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: displayStores.length,
              itemBuilder: (context, index) {
                final store = displayStores[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    // Constrain the leading widget.
                    leading: SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Builder(
                          builder: (context) {
                            if (store.imageName.isNotEmpty && !store.imageName.startsWith('http')) {
                              // Use asset image; append .png to the asset filename.
                              return Image.asset(
                                'assets/${store.imageName}.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              );
                            } else if (store.imageName.startsWith('http')) {
                              // Use network image.
                              return Image.network(
                                store.imageName,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              );
                            } else {
                              // Fallback default image.
                              return Image.asset(
                                'assets/default_image.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    title: Text(
                      store.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(store.address),
                        Text("${store.city}, ${store.state}"),
                        Text("Visits: ${store.visits}"),
                      ],
                    ),
                    onTap: () {
                      // Navigate to the store details screen.
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreDetailsScreen(
                            store: store,
                            userPosition: userPosition!,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.star_outline, size: 21.0),
              tooltip: 'Reviews',
              onPressed: () => Navigator.pushNamed(context, '/reviews'),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined, size: 21.0),
              tooltip: 'QR Code',
              onPressed: () => Navigator.pushNamed(context, '/qr_code'),
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21.0),
              tooltip: 'Home',
              onPressed: () => Navigator.pushNamed(context, '/main'),
            ),
            IconButton(
              icon: const Icon(Icons.discount_outlined, size: 21.0),
              tooltip: 'Notifications',
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
