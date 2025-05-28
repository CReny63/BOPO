import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/boba_store.dart';
import 'package:test/models/store_details.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:test/widgets/missionScreen.dart';

/// A simple HelpScreen for Q&A support.
class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Help'),
      ),
      body: const Center(
        child: Text(
          'Q&A\n\nHere are some frequently asked questions and answers...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/// Displays the user's saved (starred) stores by listening to userFavorites/<uid> and stores tree.
class SavedStoresScreen extends StatefulWidget {
  final String uid;
  const SavedStoresScreen({Key? key, required this.uid}) : super(key: key);

  @override
  _SavedStoresScreenState createState() => _SavedStoresScreenState();
}

class _SavedStoresScreenState extends State<SavedStoresScreen> {
  final _storesRef = FirebaseDatabase.instance.ref().child('stores');
  final _favRef = FirebaseDatabase.instance.ref().child('userFavorites');

  StreamSubscription<DatabaseEvent>? _storesSub;
  StreamSubscription<DatabaseEvent>? _favSub;

  List<BobaStore> _allStores = [];
  Set<String> _favorites = {};

  /// Current user position (optional retrieval).
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _locateUser();
    _listenStores();
    _listenFavorites();
  }

  Future<void> _locateUser() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() => _userPosition = pos);
    } catch (e) {
      debugPrint('Failed to get location: $e');
    }
  }

  void _listenStores() {
    _storesSub = _storesRef.onValue.listen((evt) {
      final data = evt.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final tmp = <BobaStore>[];
      data.forEach((city, cityMap) {
        final m = Map<String, dynamic>.from(cityMap as Map);
        m.forEach((sid, sdata) {
          final map = Map<String, dynamic>.from(sdata as Map);
          map['city'] = city;
          tmp.add(BobaStore.fromJson(sid.toString(), map));
        });
      });
      setState(() => _allStores = tmp);
    });
  }

  void _listenFavorites() {
    _favSub = _favRef.child(widget.uid).onValue.listen((evt) {
      final data = evt.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() => _favorites = data.keys.map((k) => k.toString()).toSet());
    });
  }

  @override
  void dispose() {
    _storesSub?.cancel();
    _favSub?.cancel();
    super.dispose();
  }

  List<BobaStore> get _favoriteStores =>
      _allStores.where((s) => _favorites.contains(s.id)).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Stores')),
      body: _allStores.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _favoriteStores.isEmpty
              ? const Center(child: Text('No saved stores yet.'))
              : ListView.builder(
                  itemCount: _favoriteStores.length,
                  itemBuilder: (ctx, i) {
                    final store = _favoriteStores[i];
                    return ListTile(
                        leading: const Icon(Icons.store),
                        title: Text(store.name),
                        subtitle: Text('${store.city}, ${store.state}'),
                        trailing: const Icon(Icons.star, color: Colors.amber),
                        onTap: () {
                          if (_userPosition != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StoreDetailsScreen(
                                  store: store,
                                  userPosition: _userPosition!,
                                  userId: widget.uid,
                                ),
                              ),
                            );
                          }
                        }
                        );
                  },
                ),
    );
  }
}

/// Profile page with Account & Settings tabs.
class ProfilePage extends StatelessWidget {
  final String username;
  final String email;
  final String maskedPassword;
  final bool isDarkMode;
  final void Function() toggleTheme;

  const ProfilePage({
    Key? key,
    required this.username,
    required this.email,
    this.maskedPassword = '********',
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  void _showManageAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Username'),
                subtitle: Text(username),
              ),
              ListTile(
                title: const Text('Email'),
                subtitle: Text(email),
              ),
              ListTile(
                title: const Text('Password'),
                subtitle: Text(maskedPassword),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Reset Password'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy'),
          content: const Text(
            'Your location data is used solely for personalized recommendations and will not be shared with third parties.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _logout(BuildContext context) {
    fbAuth.FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Widget _buildAccountTab(BuildContext context) {
    final fbAuth.User? currentUser = fbAuth.FirebaseAuth.instance.currentUser;
    final String uid = currentUser?.uid ?? '';

    return ListView(
      children: [
        _buildListTile(
          'My Missions',
          'View your missions progress',
          Icons.emoji_events,
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MissionsScreen(
                userId: uid,
                storeId: 'Oceanside_store1',
                storeLatitude: 33.15965,
                storeLongitude: -117.2048917,
                storeCity: 'Oceanside',
                scannedStoreIds: <String>{},
                themeProvider:
                    Provider.of<ThemeProvider>(context, listen: false),
              ),
            ),
          ),
        ),
        _buildListTile(
          'Get Help',
          'Access Q/A support',
          Icons.help_outline,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HelpScreen()),
          ),
        ),
        _buildListTile(
          'Saved Stores',
          'View your starred stores',
          Icons.store,
          () {
            final user = fbAuth.FirebaseAuth.instance.currentUser;
            if (user != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SavedStoresScreen(uid: user.uid),
                ),
              );
            }
          },
        ),
        _buildListTile(
          'Privacy',
          'Learn about how your location is used',
          Icons.privacy_tip_outlined,
          () => _showPrivacyDialog(context),
        ),
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListView(
      children: [
        _buildListTile(
          'Manage Account',
          'View and update your account details',
          Icons.account_circle,
          () => _showManageAccountDialog(context),
        ),
        _buildListTile(
          'Rate Us',
          'Leave a review on the app store',
          Icons.rate_review_outlined,
          () {},
        ),
        _buildListTile(
          themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
          themeProvider.isDarkMode
              ? 'Switch to light mode'
              : 'Switch to dark mode',
          themeProvider.isDarkMode ? Icons.wb_sunny : Icons.dark_mode,
          themeProvider.toggleTheme,
        ),
        _buildListTile(
          'Logout',
          'Sign out of your account',
          Icons.logout,
          () => _logout(context),
        ),
      ],
    );
  }

  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: themeProvider.toggleTheme,
          isDarkMode: themeProvider.isDarkMode,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  Container(
                    color: Theme.of(context).cardColor,
                    child: const TabBar(
                      labelColor: Color.fromARGB(255, 206, 189, 152),
                      tabs: [
                        Tab(text: 'Account'),
                        Tab(text: 'Settings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAccountTab(context),
                        _buildSettingsTab(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.star_outline, size: 21),
              tooltip: 'Visits',
              onPressed: () => Navigator.pushNamed(context, '/review'),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_food_beverage_outlined, size: 21),
              tooltip: 'Featured',
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21),
              tooltip: 'Home',
              onPressed: () {
                final user = fbAuth.FirebaseAuth.instance.currentUser;
                if (user != null && user.uid.isNotEmpty) {
                  Navigator.pushReplacementNamed(
                    context,
                    '/main',
                    arguments: user.uid,
                  );
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 21),
              tooltip: 'Map',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, size: 21),
              tooltip: 'Profile',
              onPressed: () {
                // Already on profile page
              },
            ),
          ],
        ),
      ),
    );
  }
}
