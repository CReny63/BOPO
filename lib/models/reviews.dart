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

/// ------------------------------------------------------------------------
/// STORES PAGE: shows a list of stores, tapping navigates to details.
/// ------------------------------------------------------------------------
class StoresPage extends StatefulWidget {
  final String uid; // FirebaseAuth UID
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

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    try {
      final p = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      setState(() => _userPosition = p);
    } catch (e) {
      print('Location error: $e');
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _userPosition = null);
    await _locateUser();
    await Future.delayed(Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    if (_userPosition == null) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: widget.toggleTheme,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: widget.toggleTheme,
          isDarkMode: widget.isDarkMode,
        ),
      ),
      body: CustomRefreshIndicator(
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
        child: StreamBuilder<DatabaseEvent>(
          stream: _storesRef.onValue,
          builder: (ctx, snap) {
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (!snap.hasData || snap.data!.snapshot.value == null) {
              return Center(child: CircularProgressIndicator());
            }

            // build store list
            final raw = snap.data!.snapshot.value as Map;
            final stores = <BobaStore>[];
            raw.forEach((city, cityMap) {
              final m = Map<String, dynamic>.from(cityMap as Map);
              m.forEach((sid, sdata) {
                final s = Map<String, dynamic>.from(sdata as Map);
                s['city'] = city;
                stores.add(BobaStore.fromJson(sid, s));
              });
            });

            if (stores.isEmpty) {
              return Center(child: Text('No stores found.'));
            }

            // sort by favorite then distance
            stores.sort((a, b) {
              final aFav = _favorites.contains(a.id);
              final bFav = _favorites.contains(b.id);
              if (aFav != bFav) return aFav ? -1 : 1;
              final da = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                a.latitude,
                a.longitude,
              );
              final db = Geolocator.distanceBetween(
                _userPosition!.latitude,
                _userPosition!.longitude,
                b.latitude,
                b.longitude,
              );
              return da.compareTo(db);
            });

            final display = stores.take(6).toList();

            return ListView.builder(
              padding: EdgeInsets.all(8),
              itemCount: display.length,
              itemBuilder: (ctx, i) {
                final store = display[i];
                return AnimatedStoreCard(
                  index: i,
                  child: StoreCard(
                    store: store,
                    isFavorite: _favorites.contains(store.id),
                    isDarkMode: widget.isDarkMode,
                    userPosition: _userPosition!,
                    onFavoriteToggle: () {
                      setState(() {
                        _favorites.contains(store.id)
                            ? _favorites.remove(store.id)
                            : _favorites.add(store.id);
                      });
                    },
                    onTap: () {
                      // navigate without writing—details page handles visit logic
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
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.star_outline, size: 21.0),
              onPressed: () => Navigator.pushNamed(context, '/review'),
            ),
            IconButton(
              icon: Icon(Icons.emoji_food_beverage_outlined, size: 21.0),
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
            IconButton(
              icon: Icon(Icons.home_outlined, size: 21.0),
              onPressed: () {
                final user = fbAuth.FirebaseAuth.instance.currentUser;
                if (user != null) {
                  Navigator.pushReplacementNamed(context, '/main',
                      arguments: user.uid);
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            IconButton(
              icon: Icon(Icons.map_outlined, size: 21.0),
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: Icon(Icons.person_outline, size: 21.0),
              onPressed: () => Navigator.pushNamed(context, '/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------------
/// STORE DETAILS: geofence + countdown, then record per-user + global.
/// ------------------------------------------------------------------------
class StoreDetailsScreen extends StatefulWidget {
  final BobaStore store;
  final Position userPosition;
  final String userId;

  const StoreDetailsScreen({
    Key? key,
    required this.store,
    required this.userPosition,
    required this.userId,
  }) : super(key: key);

  @override
  _StoreDetailsScreenState createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  static const _threshold = 3.05; // meters
  bool _visited = false;
  bool _timerActive = false;
  int _seconds = 30;
  Timer? _geoTimer;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _geoTimer = Timer.periodic(Duration(seconds: 5), (_) => _checkProximity());
  }

  @override
  void dispose() {
    _geoTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkProximity() async {
    if (_visited) {
      _geoTimer?.cancel();
      return;
    }
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return;
    }
    final dist = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    if (dist <= _threshold && !_timerActive) {
      _startCountdown();
    } else if (dist > _threshold && _timerActive) {
      _cancelCountdown();
    }
  }

  void _startCountdown() {
    setState(() {
      _timerActive = true;
      _seconds = 30;
    });
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (t) async {
      setState(() => _seconds--);
      if (_seconds <= 0) {
        t.cancel();
        await _confirmAndRecord();
      }
    });
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _timerActive = false;
      _seconds = 30;
    });
  }

  Future<void> _confirmAndRecord() async {
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      _cancelCountdown();
      return;
    }
    final dist2 = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    if (dist2 <= _threshold) {
      await _recordVisit(pos);
      setState(() {
        _visited = true;
        _timerActive = false;
      });
    } else {
      _cancelCountdown();
    }
  }

  Future<void> _recordVisit(Position pos) async {
    final fbUser = fbAuth.FirebaseAuth.instance.currentUser;
    if (fbUser == null || fbUser.uid != widget.userId) {
      print('Auth mismatch; not recording');
      return;
    }

    final userRef = FirebaseDatabase.instance
        .ref()
        .child('userStoreVisits')
        .child(widget.userId)
        .child(widget.store.id);

    try {
      final snap = await userRef.get();
      int cnt = snap.exists ? int.parse(snap.value.toString()) : 0;
      await userRef.set(cnt + 1);

      final storeRef = FirebaseDatabase.instance
          .ref()
          .child('stores')
          .child(widget.store.city)
          .child(widget.store.id);
      await storeRef.runTransaction((data) {
        if (data != null) {
          final m = Map<String, dynamic>.from(data as Map);
          m['visits'] = (m['visits'] ?? 0) + 1;
          return Transaction.success(m);
        }
        return Transaction.success(data);
      });
      print('Visit recorded for ${widget.store.id}');
    } catch (e) {
      print('Error recording visit: $e');
    }
  }

  Future<void> _openMaps() async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      {
        'api': '1',
        'query': '${widget.store.latitude},${widget.store.longitude}'
      },
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not open maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dist = Geolocator.distanceBetween(
      widget.userPosition.latitude,
      widget.userPosition.longitude,
      widget.store.latitude,
      widget.store.longitude,
    );
    final miles = dist / 1000 * 0.621371;

    return Scaffold(
      appBar: AppBar(title: Text(widget.store.name), centerTitle: true),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.store, size: 100, color: Colors.grey),
              SizedBox(height: 24),
              Text('${miles.toStringAsFixed(2)} mi away',
                  style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              GestureDetector(
                onTap: _openMaps,
                child: Text(
                  '${widget.store.address}\n'
                  '${widget.store.city}, ${widget.store.state} ${widget.store.zip}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              if (_visited)
                Text('Visit recorded!',
                    style: TextStyle(fontSize: 16, color: Colors.green))
              else if (_timerActive)
                Text('$_seconds sec to record visit',
                    style: TextStyle(fontSize: 16, color: Colors.orange))
              else
                Text('Move closer to record visit',
                    style: TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------------------------------------------------------------
/// STORE CARD (list item)
/// ------------------------------------------------------------------------
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
      margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: ListTile(
        leading: Hero(
          tag: 'storeImage-${store.id}',
          child: Icon(
            Icons.store,
            size: 60,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        title: Text(store.name, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${store.city}, ${store.state}"),
            Text("Global Visits: ${store.visits}"),
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
                return Text("Your Visits: $count",
                    style: TextStyle(color: Colors.blue));
              },
            ),
          ],
        ),
        trailing: IconButton(
          icon: Icon(isFavorite ? Icons.star : Icons.star_border,
              color: isFavorite ? Colors.amber : null),
          onPressed: onFavoriteToggle,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// ------------------------------------------------------------------------
/// SIMPLE FADE+SLIDE ANIMATION FOR THE LIST ITEMS
/// ------------------------------------------------------------------------
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
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 400),
    );
    _a = CurvedAnimation(parent: _c, curve: Curves.easeOut);
    Future.delayed(Duration(milliseconds: widget.index * 100), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _a,
      child: SlideTransition(
        position:
            Tween<Offset>(begin: Offset(0, 0.2), end: Offset.zero).animate(_a),
        child: widget.child,
      ),
    );
  }
}
