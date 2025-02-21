import 'dart:math';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart'; // Your BobaStore class
import 'package:test/models/store_details.dart'; // Contains your StoreDetailsScreen
import 'package:test/widgets/app_bar_content.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
        builder: (BuildContext context, Widget child, IndicatorController controller) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
              // Wrap the animated capybara icon in a RepaintBoundary.
              RepaintBoundary(
                child: Transform.translate(
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
              ),
              // Wrap the child in a RepaintBoundary to reduce repaints.
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
                    if (storeData is Map && storeData.containsKey('name')) {
                      final Map<String, dynamic> storeMap = Map<String, dynamic>.from(storeData);
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

            // Sort the stores so that favorites appear at the top, then by distance.
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
              padding: const EdgeInsets.all(16),
              itemCount: displayStores.length,
              itemBuilder: (context, index) {
                final store = displayStores[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Builder(
                          builder: (context) {
                            // Use asset image if imageName is provided and not a URL.
                            if (store.imageName.isNotEmpty && !store.imageName.startsWith('http')) {
                              return Image.asset(
                                'assets/${store.imageName}.png',
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              );
                            } 
                            // Use CachedNetworkImage for network images.
                            else if (store.imageName.startsWith('http')) {
                              return CachedNetworkImage(
                                imageUrl: store.imageName,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                              );
                            } 
                            // Fallback to default asset image.
                            else {
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
                          // Toggle favorite status.
                          if (favoriteStoreIds.contains(store.id)) {
                            favoriteStoreIds.remove(store.id);
                          } else {
                            favoriteStoreIds.add(store.id);
                          }
                          // After toggling, re-sort the list so favorites come to the top.
                        });
                      },
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
