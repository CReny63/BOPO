import 'dart:async';
import 'dart:math';

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:test/locations/boba_store.dart';
import 'package:test/models/store_details.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

class StoresPage extends StatefulWidget {
  final String uid;
  final void Function() toggleTheme;
  final bool isDarkMode;

  const StoresPage({
    Key? key,
    required this.uid,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _StoresPageState createState() => _StoresPageState();
}

class _StoresPageState extends State<StoresPage> {
  final DatabaseReference _storesRef =
      FirebaseDatabase.instance.ref().child('stores');
  Position? _userPosition;
  final Set<String> _favorites = {};
  final Set<String> _visitedStoreIds = {};
  List<BobaStore> _allStores = [];

  StreamSubscription<DatabaseEvent>? _storesSub;
  StreamSubscription<DatabaseEvent>? _favSub;
  StreamSubscription<DatabaseEvent>? _visitedSub;

  @override
  void initState() {
    super.initState();
    _locateUser();
    _listenStores();
    _listenFavorites();
    _listenVisited();
  }

  @override
  void dispose() {
    _storesSub?.cancel();
    _favSub?.cancel();
    _visitedSub?.cancel();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _userPosition = p);
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  void _listenStores() {
    _storesSub = _storesRef.onValue.listen((evt) {
      final data = evt.snapshot.value as Map<dynamic, dynamic>? ?? {};
      final stores = <BobaStore>[];
      data.forEach((city, cityMap) {
        final m = Map<String, dynamic>.from(cityMap as Map);
        m.forEach((sid, sdata) {
          final s = Map<String, dynamic>.from(sdata as Map);
          s['city'] = city;
          stores.add(BobaStore.fromJson(sid, s));
        });
      });
      setState(() => _allStores = stores);
    });
  }

  void _listenFavorites() {
    final favRef = FirebaseDatabase.instance
        .ref()
        .child('userFavorites')
        .child(widget.uid);
    _favSub = favRef.onValue.listen((evt) {
      final data = evt.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _favorites
          ..clear()
          ..addAll(data.keys.map((k) => k.toString()));
      });
    });
  }

  void _listenVisited() {
    final visitedRef = FirebaseDatabase.instance
        .ref()
        .child('userStoreVisits')
        .child(widget.uid);
    _visitedSub = visitedRef.onValue.listen((evt) {
      final data = evt.snapshot.value as Map<dynamic, dynamic>? ?? {};
      setState(() {
        _visitedStoreIds
          ..clear()
          ..addAll(data.keys.map((k) => k.toString()));
      });
    });
  }

  List<BobaStore> get _closestStores {
    if (_userPosition == null) return [];
    final list = List<BobaStore>.from(_allStores);
    list.sort((a, b) {
      final da = Geolocator.distanceBetween(_userPosition!.latitude,
          _userPosition!.longitude, a.latitude, a.longitude);
      final db = Geolocator.distanceBetween(_userPosition!.latitude,
          _userPosition!.longitude, b.latitude, b.longitude);
      return da.compareTo(db);
    });
    return list;
  }

  List<BobaStore> get _discoverStores =>
      _allStores.where((s) => !_visitedStoreIds.contains(s.id)).toList();

  List<BobaStore> get _favoriteStores =>
      _allStores.where((s) => _favorites.contains(s.id)).toList();

  Future<void> _toggleFavorite(String storeId) async {
    final favRef = FirebaseDatabase.instance
        .ref()
        .child('userFavorites')
        .child(widget.uid)
        .child(storeId);
    if (_favorites.contains(storeId)) {
      await favRef.remove();
    } else {
      await favRef.set(true);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _userPosition = null);
    await _locateUser();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        // Top bar: uses your theme's primary (orange/purple)
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(50 + kTextTabBarHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppBarContent(
                toggleTheme: widget.toggleTheme,
                isDarkMode: widget.isDarkMode,
              ),
              // Sliding tabs: white in both light/dark
              Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: TabBar(
                  indicatorColor: Colors.brown,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: Colors.brown,
                  unselectedLabelColor:
                      widget.isDarkMode ? Colors.white70 : Colors.grey,
                  labelStyle: const TextStyle(fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontSize: 14),
                  tabs: const [
                    Tab(text: 'Discover'),
                    Tab(text: 'Nearby'),
                    Tab(text: 'Favorites'),
                  ],
                ),
              ),
            ],
          ),
        ),

        body: TabBarView(
          children: [
            _buildStoreList(_discoverStores),
            _buildStoreList(_closestStores.take(6).toList()),
            _buildStoreList(_favoriteStores),
          ],
        ),

        bottomNavigationBar: BottomAppBar(
          color: Theme.of(context).colorScheme.surface,
          shape: const CircularNotchedRectangle(),
          notchMargin: 6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: <Widget>[
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
                    Navigator.pushReplacementNamed(context, '/main',
                        arguments: user.uid);
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
                onPressed: () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreList(List<BobaStore> stores) {
    if (_userPosition == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return const Center(child: Text('No stores here.'));
    }
    return CustomRefreshIndicator(
      onRefresh: _handleRefresh,
      builder: (ctx, child, controller) {
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
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: stores.length,
        itemBuilder: (ctx, i) {
          final store = stores[i];
          return AnimatedStoreCard(
            index: i,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: StoreCard(
                store: store,
                isFavorite: _favorites.contains(store.id),
                isDarkMode: widget.isDarkMode,
                userPosition: _userPosition!,
                onFavoriteToggle: () => _toggleFavorite(store.id),
                onTap: () {
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
                },
                uid: widget.uid,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// STORE CARD WITH DYNAMIC THEME COLORS:
class StoreCard extends StatelessWidget {
  final BobaStore store;
  final bool isFavorite;
  final bool isDarkMode;
  final Position userPosition;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;
  final String uid;

  const StoreCard({
    Key? key,
    required this.store,
    required this.isFavorite,
    required this.isDarkMode,
    required this.userPosition,
    required this.onFavoriteToggle,
    required this.onTap,
    required this.uid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.store,
                size: 48,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.city}, ${store.state}',
                      style: const TextStyle(fontSize: 14),
                      softWrap: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Global Visits: ${store.visits}',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                    FutureBuilder<DataSnapshot>(
                      future: FirebaseDatabase.instance
                          .ref()
                          .child('userStoreVisits')
                          .child(uid)
                          .child(store.id)
                          .get(),
                      builder: (ctx, snap) {
                        final count = (snap.hasData && snap.data!.value != null)
                            ? int.parse(snap.data!.value.toString())
                            : 0;
                        return Text(
                          'Your Visits: $count',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.blue),
                        );
                      },
                    ),
                  ],
                ),
              ),
              IconButton(
                iconSize: 24,
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? Colors.amber : Colors.grey,
                ),
                onPressed: onFavoriteToggle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// SIMPLE FADE+SLIDE ANIMATION FOR THE LIST ITEMS
class AnimatedStoreCard extends StatefulWidget {
  final Widget child;
  final int index;

  const AnimatedStoreCard({
    Key? key,
    required this.child,
    required this.index,
  }) : super(key: key);

  @override
  _AnimatedStoreCardState createState() => _AnimatedStoreCardState();
}

class _AnimatedStoreCardState extends State<AnimatedStoreCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(_animation),
        child: widget.child,
      ),
    );
  }
}
