import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

// Model for history entries
class HistoryItem {
  final String id;
  final String description;
  final DateTime timestamp;
  HistoryItem(this.id, this.description, this.timestamp);
}

class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late DatabaseReference _userRef;
  String _uid = '';
  int _coins = 0;
  List<String> _unlockedStickers = [];
  List<HistoryItem> _history = [];

  final List<_MysteryBox> _boxes = [
    _MysteryBox('Bronze Box', 5, Colors.brown, 'assets/bronze_box.png'),
    _MysteryBox('Silver Box', 8, Colors.grey, 'assets/silver_box.png'),
    _MysteryBox('Gold Box', 12, Colors.amber, 'assets/gold_box.png'),
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
    _userRef = FirebaseDatabase.instance.ref().child('users/$_uid');

    final coinSnap = await _userRef.child('coins').get();
    final stickerSnap = await _userRef.child('stickers').get();
    final historySnap = await _userRef.child('history').get();

    final coins = coinSnap.exists ? (coinSnap.value as int) : 10;
    final stickers = <String>[];
    if (stickerSnap.exists) {
      final data = Map<String, dynamic>.from(stickerSnap.value as Map);
      data.values.forEach((e) => stickers.add(e['asset'] as String));
    }
    final history = <HistoryItem>[];
    if (historySnap.exists) {
      final data = Map<String, dynamic>.from(historySnap.value as Map);
      data.forEach((key, value) {
        final entry = Map<String, dynamic>.from(value);
        history.add(HistoryItem(
          key,
          entry['description'] as String,
          DateTime.parse(entry['timestamp'] as String),
        ));
      });
      history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    setState(() {
      _coins = coins;
      _unlockedStickers = stickers;
      _history = history;
    });
  }

  Future<void> _openBox(_MysteryBox box) async {
    if (_coins < box.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    await _updateCoins(-box.cost);
    final reward = Random().nextInt(6) + 20;
    await _updateCoins(reward);
    final assets = [
      'assets/sticker1.png',
      'assets/sticker2.png',
      'assets/sticker3.png',
      'assets/sticker4.png',
      'assets/sticker5.png',
    ];
    final sticker = assets[Random().nextInt(assets.length)];
    await _userRef.child('stickers').push().set({'asset': sticker});

    final description = 'Opened ${box.title}: +$reward coins';
    final timestamp = DateTime.now().toIso8601String();
    await _userRef.child('history').push().set({
      'description': description,
      'timestamp': timestamp,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RewardSplashPage(
          reward: reward,
          stickerAsset: sticker,
        ),
      ),
    ).then((_) => _initUser());
  }

  Future<void> _updateCoins(int delta) async {
    setState(() => _coins += delta);
    await _userRef.update({'coins': _coins});
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
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: _unlockedStickers.length,
                      itemBuilder: (context, idx) =>
                          Image.asset(_unlockedStickers[idx]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.monetization_on_outlined,
                              color: theme.isDarkMode
                                  ? Colors.amber
                                  : Colors.orange,
                            ),
                            const SizedBox(width: 4),
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
                        const SizedBox(height: 24),
                        // Vertical mystery boxes
                        Expanded(
                          child: ListView.separated(
                            physics: const NeverScrollableScrollPhysics(),
                            separatorBuilder: (_, __) => const SizedBox(
                              height: 16,
                            ),
                            itemCount: _boxes.length,
                            itemBuilder: (context, idx) {
                              final box = _boxes[idx];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BoxDetailPage(
                                        box: box,
                                        onConfirm: () => _openBox(box),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: box.color,
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Image.asset(
                                        box.asset,
                                        width: 48,
                                        height: 48,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            box.title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: box.color,
                                            ),
                                          ),
                                          Text(
                                            '${box.cost} coins',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final item = _history[idx];
                        return ListTile(
                          leading: const Icon(Icons.history),
                          title: Text(item.description),
                          subtitle: Text(
                            '${item.timestamp.toLocal()}'.split('.')[0],
                          ),
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
            children: <Widget>[
              IconButton(
                icon: const Icon(Icons.star_outline),
                tooltip: 'Visits',
                onPressed: () => Navigator.pushNamed(context, '/review'),
              ),
              IconButton(
                icon:
                    const Icon(Icons.emoji_food_beverage_outlined),
                tooltip: 'Featured',
                onPressed: () =>
                    Navigator.pushNamed(context, '/featured'),
              ),
              IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'Home',
                onPressed: () {
                  if (_uid.isNotEmpty) {
                    Navigator.pushReplacementNamed(
                      context,
                      '/main',
                      arguments: _uid,
                    );
                  } else {
                    Navigator.pushReplacementNamed(
                        context, '/login');
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.map_outlined),
                tooltip: 'Map',
                onPressed: () =>
                    Navigator.pushNamed(context, '/notifications'),
              ),
              IconButton(
                icon: const Icon(Icons.person_outline),
                tooltip: 'Profile',
                onPressed: () =>
                    Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-screen detail for a mystery box
class BoxDetailPage extends StatelessWidget {
  final _MysteryBox box;
  final VoidCallback onConfirm;

  const BoxDetailPage({
    Key? key,
    required this.box,
    required this.onConfirm,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(box.title),
        backgroundColor: box.color,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(box.asset, width: 120, height: 120),
            const SizedBox(height: 20),
            Text(
              'Cost: ${box.cost} coins',
              style: const TextStyle(fontSize: 18),
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

/// Splash screen for rewards
class RewardSplashPage extends StatelessWidget {
  final int reward;
  final String stickerAsset;

  const RewardSplashPage({
    Key? key,
    required this.reward,
    required this.stickerAsset,
  }) : super(key: key);

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
              '+\$${reward} coins!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text('New Sticker Unlocked!',
                style: TextStyle(fontSize: 18)),
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

class _MysteryBox {
  final String title;
  final int cost;
  final Color color;
  final String asset;

  const _MysteryBox(this.title, this.cost, this.color, this.asset);
}
