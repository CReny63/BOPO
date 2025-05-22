import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

// A history entry: key + data map (description, timestamp, boxAsset)
typedef HistoryItem = MapEntry<String, Map<String, dynamic>>;

/// Mystery box model
class _MysteryBox {
  final String title;
  final int cost;
  final Color color;
  final String asset;
  const _MysteryBox(this.title, this.cost, this.color, this.asset);
}

/// Splash screen after opening a box
class RewardSplashPage extends StatelessWidget {
  final int reward;
  final String stickerAsset;
  const RewardSplashPage(
      {Key? key, required this.reward, required this.stickerAsset})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(stickerAsset, width: 120, height: 120),
            const SizedBox(height: 20),
            Text(
              '+\$$reward coins!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text('New Sticker Unlocked!', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Detailed page to confirm box purchase
class BoxDetailPage extends StatelessWidget {
  final _MysteryBox box;
  final VoidCallback onConfirm;
  const BoxDetailPage({Key? key, required this.box, required this.onConfirm})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(box.title), backgroundColor: box.color),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(box.asset, width: 120, height: 120),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Cost: ${box.cost}'),
                const SizedBox(width: 4),
                Image.asset('assets/coin_boba.png', width: 20, height: 20),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: box.color,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              ),
              onPressed: () {
                onConfirm();
                Navigator.pop(context);
              },
              child: const Text('Open Box'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Main Store page with three tabs: Collection, Shop, History
class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);
  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late DatabaseReference _userRef;
  late StreamSubscription<DatabaseEvent> _coinSub;
  String _uid = '';
  int _coins = 0;
  Map<int, int> _stickerCounts = {};
  List<HistoryItem> _history = [];

  final List<_MysteryBox> _boxes = [
    const _MysteryBox('Bronze Box', 5, Colors.brown, 'assets/bronze_box.png'),
    const _MysteryBox('Silver Box', 10, Colors.grey, 'assets/silver_box.png'),
    const _MysteryBox('Gold Box', 20, Colors.amber, 'assets/gold_box.png'),
  ];

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    final user = fbAuth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _uid = user.uid;
    _userRef = FirebaseDatabase.instance.ref('users/$_uid');

    // Listen for coin changes in real time
    _coinSub = _userRef.child('coins').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is int) setState(() => _coins = val);
    });

    // One-time load: stickers & history
    final stickerSnap = await _userRef.child('stickers').get();
    final historySnap = await _userRef.child('history').get();

    final counts = <int, int>{};
    if (stickerSnap.exists) {
      final data = Map<String, dynamic>.from(stickerSnap.value as Map);
      for (var v in data.values) {
        final path = v['asset'] as String;
        final m = RegExp(r'sticker(\d+)\.png').firstMatch(path);
        if (m != null) {
          final num = int.parse(m.group(1)!);
          counts[num] = (counts[num] ?? 0) + 1;
        }
      }
    }

    final hist = <HistoryItem>[];
    if (historySnap.exists) {
      final data = Map<String, dynamic>.from(historySnap.value as Map);
      data.forEach((k, v) {
        hist.add(MapEntry(k, Map<String, dynamic>.from(v as Map)));
      });
      hist.sort((a, b) => DateTime.parse(b.value['timestamp'] as String)
          .compareTo(DateTime.parse(a.value['timestamp'] as String)));
    }

    setState(() {
      _stickerCounts = counts;
      _history = hist;
    });
  }

  @override
  void dispose() {
    _coinSub.cancel();
    super.dispose();
  }

  Future<void> _openBox(_MysteryBox box) async {
    if (_coins < box.cost) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not enough coins')));
      return;
    }
    final reward = Random().nextInt(6) + 20;
    await _userRef.child('coins').set(_coins - box.cost + reward);

    // Push sticker
    final assets = List.generate(50, (i) => 'assets/sticker${i + 1}.png');
    final sticker = assets[Random().nextInt(assets.length)];
    await _userRef.child('stickers').push().set({'asset': sticker});

    // Push history entry
    await _userRef.child('history').push().set({
      'description': 'Opened ${box.title}: +\$$reward coins',
      'timestamp': DateTime.now().toIso8601String(),
      'boxAsset': box.asset,
    });

    // Show splash
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RewardSplashPage(reward: reward, stickerAsset: sticker),
      ),
    ).then((_) => _initUser());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: theme.toggleTheme,
            isDarkMode: theme.isDarkMode,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            TabBar(
              indicatorColor: theme.isDarkMode ? Colors.amber : Colors.orange,
              labelColor: theme.isDarkMode ? Colors.white : Colors.black,
              tabs: const [
                Tab(text: 'Collection'),
                Tab(text: 'Shop'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // COLLECTION
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: 50,
                      itemBuilder: (context, index) {
                        final slot = index + 1;
                        final cnt = _stickerCounts[slot] ?? 0;
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: cnt > 0
                                    ? Image.asset('assets/sticker$slot.png')
                                    : Text('$slot',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                              ),
                            ),
                            if (cnt > 1)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle),
                                  child: Text(
                                    '$cnt',
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  // SHOP
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Image.asset('assets/coin_boba.png',
                                  width: 20, height: 20),
                              const SizedBox(width: 6),
                              Text(
                                '$_coins',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.isDarkMode
                                      ? Colors.white
                                      : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 250,
                          child: PageView.builder(
                            controller: PageController(viewportFraction: 0.6),
                            itemCount: _boxes.length,
                            itemBuilder: (context, idx) {
                              final box = _boxes[idx];
                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BoxDetailPage(
                                        box: box,
                                        onConfirm: () => _openBox(box),
                                      ),
                                    ),
                                  ),
                                  child: SizedBox(
                                    height: 300, // ↑ bump this up from 180
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                            color: box.color, width: 2),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Image.asset(box.asset,
                                              width: 100, height: 100),
                                          const SizedBox(height: 12),
                                          Text(box.title,
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: box.color)),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text('${box.cost}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium),
                                              const SizedBox(width: 4),
                                              Image.asset(
                                                  'assets/coin_boba.png',
                                                  width: 25,
                                                  height: 25),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // HISTORY
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final entry = _history[idx].value;
                        final boxAsset = entry['boxAsset'] as String?;
                        final tsRaw = entry['timestamp'] as String? ?? '';
                        final timeOnly = tsRaw.isNotEmpty
                            ? DateTime.parse(tsRaw)
                                .toLocal()
                                .toString()
                                .split('.')[0]
                            : '';
                        final desc = entry['description'] as String? ?? '';

                        return ListTile(
                          leading: boxAsset != null
                              ? Image.asset(boxAsset, width: 32, height: 32)
                              : const SizedBox(width: 32, height: 32),
                          title: Text(timeOnly),
                          subtitle: Text(desc),
                        );
                      },
                    ),
                  ),
                ],
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
                  onPressed: () => Navigator.pushNamed(context, '/review')),
              IconButton(
                  icon:
                      const Icon(Icons.emoji_food_beverage_outlined, size: 21),
                  tooltip: 'Featured',
                  onPressed: () => Navigator.pushNamed(context, '/featured')),
              IconButton(
                  icon: const Icon(Icons.home_outlined, size: 21),
                  tooltip: 'Home',
                  onPressed: () {
                    if (_uid.isNotEmpty)
                      Navigator.pushReplacementNamed(context, '/main',
                          arguments: _uid);
                    else
                      Navigator.pushReplacementNamed(context, '/login');
                  }),
              IconButton(
                  icon: const Icon(Icons.map_outlined, size: 21),
                  tooltip: 'Map',
                  onPressed: () =>
                      Navigator.pushNamed(context, '/notifications')),
              IconButton(
                  icon: const Icon(Icons.person_outline, size: 21),
                  tooltip: 'Profile',
                  onPressed: () => Navigator.pushNamed(context, '/profile')),
            ],
          ),
        ),
      ),
    );
  }
}
