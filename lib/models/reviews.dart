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

  // Maintain a set of favorite store IDs.
  final Set<String> favoriteStoreIds = {};

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

  /// Pull-to-refresh callback.
  Future<void> _handleRefresh() async {
    setState(() {
      userPosition = null;
    });
    await _getUserLocation();
    await Future.delayed(const Duration(milliseconds: 1000));
  }

  @override
  Widget build(BuildContext context) {
    // Show a loader until we have the user's location.
    if (userPosition == null) {
      return Scaffold(
        appBar: const PreferredSize(
          preferredSize: Size.fromHeight(75),
          child: AppBarContent(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: const PreferredSize(
        preferredSize: Size.fromHeight(75),
        child: AppBarContent(),
      ),
      body: CustomRefreshIndicator(
        onRefresh: _handleRefresh,
        builder: (BuildContext context, Widget child,
            IndicatorController controller) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // Animated capybara icon.
              RepaintBoundary(
                child: Transform.translate(
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
              ),
              RepaintBoundary(
                child: Transform.translate(
                  offset: Offset(0, controller.value * 100),
                  child: child,
                ),
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

            // Parse the Firebase data.
            final dynamic decoded = snapshot.data!.snapshot.value;
            List<BobaStore> storeList = [];
            if (decoded is Map) {
              final Map<String, dynamic> cities =
                  Map<String, dynamic>.from(decoded);
              cities.forEach((cityName, cityData) {
                if (cityData is Map) {
                  final Map<String, dynamic> storesMap =
                      Map<String, dynamic>.from(cityData);
                  storesMap.forEach((storeKey, storeData) {
                    if (storeData is Map && storeData.containsKey('name')) {
                      final Map<String, dynamic> storeMap =
                          Map<String, dynamic>.from(storeData);
                      storeMap['city'] = cityName;
                      BobaStore store = BobaStore.fromJson(storeKey, storeMap);
                      storeList.add(store);
                    } else {
                      print(
                          "Skipping key '$storeKey' in city '$cityName' as it's not a valid store record.");
                    }
                  });
                  print(
                      "City '$cityName' processed with ${storesMap.length} entries.");
                } else {
                  print(
                      "Skipping city '$cityName' because its data is not a Map.");
                }
              });
            } else {
              print("Decoded data is not a Map.");
            }

            print("Total stores parsed: ${storeList.length}");
            if (storeList.isEmpty) {
              return const Center(child: Text("No stores found."));
            }

            // Sort so that favorites are at the top, then by distance.
            storeList.sort((a, b) {
              bool aFav = favoriteStoreIds.contains(a.id);
              bool bFav = favoriteStoreIds.contains(b.id);
              if (aFav && !bFav) return -1;
              if (!aFav && bFav) return 1;
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

            // Only display the first 6 stores.
            List<BobaStore> displayStores = storeList.take(6).toList();

            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: displayStores.length,
              itemBuilder: (context, index) {
                final store = displayStores[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    // Use a smaller leading icon.
                    leading: SizedBox(
                      width: 60,
                      height: 60,
                      child: Icon(
                        Icons.store,
                        size: 60,
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),

                    title: Text(
                      store.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.address,
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          "${store.city}, ${store.state}",
                          style: const TextStyle(fontSize: 12),
                        ),
                        Text(
                          "Visits: ${store.visits}",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        favoriteStoreIds.contains(store.id)
                            ? Icons.star
                            : Icons.star_border,
                        color: favoriteStoreIds.contains(store.id)
                            ? Colors.amber
                            : null,
                      ),
                      onPressed: () {
                        setState(() {
                          if (favoriteStoreIds.contains(store.id)) {
                            favoriteStoreIds.remove(store.id);
                          } else {
                            favoriteStoreIds.add(store.id);
                          }
                        });
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StoreDetailsScreen(
                            store: store,
                            userPosition: userPosition!, userId: '',
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
