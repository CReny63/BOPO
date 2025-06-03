import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

/// Mystery box model
class _MysteryBox {
  final String title;
  final int cost;
  final Color color;
  final String asset;

  const _MysteryBox(this.title, this.cost, this.color, this.asset);
}

/// Splash shown after opening a box
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
              '+$reward coins!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'New Sticker Unlocked!',
              style: TextStyle(fontSize: 18),
            ),
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

/// Confirmation page before opening a box
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
                Text('${box.cost}'),
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

/// Store page with tabs: Collection, Shop, History
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
  List<MapEntry<String, Map<String, dynamic>>> _history = [];

  // Number of each sticker to sell (0…count)
  Map<int, int> _sellSelections = {};
  bool _isProcessingSell = false;

  final List<_MysteryBox> _boxes = const [
    _MysteryBox('Bronze Box', 5, Colors.brown, 'assets/bronze_box.png'),
    _MysteryBox('Silver Box', 10, Colors.grey, 'assets/silver_box.png'),
    _MysteryBox('Gold Box', 20, Colors.amber, 'assets/gold_box.png'),
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

    // Initialize coins if missing
    final coinSnap = await _userRef.child('coins').get();
    if (!coinSnap.exists) {
      await _userRef.child('coins').set(20);
    }
    _coinSub = _userRef.child('coins').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is int) {
        setState(() => _coins = val);
      }
    });

    // Load stickers
    final stickerSnap = await _userRef.child('stickers').get();
    final counts = <int, int>{};
    if (stickerSnap.exists) {
      final data = Map<String, dynamic>.from(stickerSnap.value as Map);
      for (var v in data.values) {
        final m = RegExp(r'sticker(\d+)\.png').firstMatch(v['asset']);
        if (m != null) {
          final slot = int.parse(m.group(1)!);
          counts[slot] = (counts[slot] ?? 0) + 1;
        }
      }
    }

    // Load history
    final histSnap = await _userRef.child('history').get();
    final histList = <MapEntry<String, Map<String, dynamic>>>[];
    if (histSnap.exists) {
      final data = Map<String, dynamic>.from(histSnap.value as Map);
      data.forEach((k, v) {
        histList.add(MapEntry(k, Map<String, dynamic>.from(v as Map)));
      });
      histList.sort((a, b) => DateTime.parse(b.value['timestamp'])
          .compareTo(DateTime.parse(a.value['timestamp'])));
    }

    setState(() {
      _stickerCounts = counts;
      _history = histList;
      _sellSelections = {
        for (var slot in counts.keys) slot: 0,
      };
    });
  }

  @override
  void dispose() {
    _coinSub.cancel();
    super.dispose();
  }

  Future<void> _openBox(_MysteryBox box) async {
    if (_coins < box.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }
    final reward = Random().nextInt(1) + 3;
    await _userRef.child('coins').set(_coins - box.cost + reward);

    // Determine sticker ID range based on box:
    List<int> pool;
    if (box.title == 'Bronze Box') {
      pool = List.generate(24, (i) => i + 1); // 1–24
    } else if (box.title == 'Silver Box') {
      pool = List.generate(11, (i) => i + 25); // 25–35
    } else {
      pool = List.generate(15, (i) => i + 36); // 36–50
    }

    // Build a weight map: higher IDs = rarer.
    final maxId = pool.reduce(max);
    final weights = {for (var id in pool) id: (maxId + 1) - id};
    final totalWeight = weights.values.reduce((a, b) => a + b);
    var rnd = Random().nextInt(totalWeight);
    int chosenId = pool.first;
    for (var id in pool) {
      rnd -= weights[id]!;
      if (rnd < 0) {
        chosenId = id;
        break;
      }
    }

    final sticker = 'assets/sticker$chosenId.png';
    await _userRef.child('stickers').push().set({'asset': sticker});

    await _userRef.child('history').push().set({
      'description': 'Opened ${box.title}: +$reward coins',
      'timestamp': DateTime.now().toIso8601String(),
      'boxAsset': box.asset,
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            RewardSplashPage(reward: reward, stickerAsset: sticker),
      ),
    ).then((_) => _initUser());
  }

  Future<void> _selectAllStickers() async {
    setState(() {
      _sellSelections = {
        for (var slot in _stickerCounts.keys) slot: _stickerCounts[slot]!,
      };
    });
  }

  Future<void> _sellSelected() async {
    if (_isProcessingSell) return;
    final toSell = <int, int>{};
    int totalEarned = 0;

    _sellSelections.forEach((slot, qty) {
      if (qty > 0) {
        final available = _stickerCounts[slot] ?? 0;
        final sellCount = qty.clamp(0, available);
        if (sellCount > 0) {
          final rate = slot <= 20 ? 1 : slot <= 39 ? 2 : 5;
          totalEarned += rate * sellCount;
          toSell[slot] = sellCount;
        }
      }
    });

    if (totalEarned == 0) return;

    setState(() => _isProcessingSell = true);

    await _userRef.child('coins').set(_coins + totalEarned);

    // Remove sold stickers
    final stickersRef = _userRef.child('stickers');
    final snap = await stickersRef.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final toRemoveMap = Map<int, int>.from(toSell);
      for (var key in data.keys) {
        final m = RegExp(r'sticker(\d+)\.png')
            .firstMatch(data[key]['asset']);
        if (m != null) {
          final slot = int.parse(m.group(1)!);
          if (toRemoveMap.containsKey(slot) &&
              toRemoveMap[slot]! > 0) {
            await stickersRef.child(key).remove();
            toRemoveMap[slot] = toRemoveMap[slot]! - 1;
            if (toRemoveMap[slot] == 0) {
              toRemoveMap.remove(slot);
            }
            if (toRemoveMap.isEmpty) break;
          }
        }
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sold for $totalEarned coins!')),
    );

    setState(() {
      _sellSelections = {
        for (var slot in _stickerCounts.keys) slot: 0
      };
      _isProcessingSell = false;
    });

    await _initUser();
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
              indicatorColor:
                  theme.isDarkMode ? Colors.amber : Colors.orange,
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
                  // Collection Tab
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
                        final count = _stickerCounts[slot] ?? 0;
                        return Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: count > 0
                                    ? Image.asset(
                                        'assets/sticker$slot.png')
                                    : Text(
                                        '$slot',
                                        style: const TextStyle(
                                            color: Colors.grey),
                                      ),
                              ),
                            ),
                            if (count > 1)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$count',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),

                  // Shop Tab
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Coin Balance
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
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

                        // Mystery Boxes
                        SizedBox(
                          height: 300,
                          child: PageView.builder(
                            controller:
                                PageController(viewportFraction: 0.6),
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
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: box.color, width: 4),
                                      borderRadius:
                                          BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Image.asset(box.asset,
                                            width: 100, height: 100),
                                        const SizedBox(height: 12),
                                        Text(
                                          box.title,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: box.color,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${box.cost}',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium,
                                            ),
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
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Sell Stickers Section
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sell Stickers for Coins',
                                style:
                                    Theme.of(context).textTheme.titleMedium,
                              ),
                              TextButton(
                                onPressed: _selectAllStickers,
                                child: const Text('Select All'),
                              ),
                            ],
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics:
                              const NeverScrollableScrollPhysics(),
                          itemCount: _stickerCounts.length,
                          itemBuilder: (context, idx) {
                            final slot =
                                _stickerCounts.keys.elementAt(idx);
                            final quantity =
                                _stickerCounts[slot]!;
                            final rate =
                                slot <= 20 ? 1 : slot <= 39 ? 2 : 5;
                            final selectedCount =
                                _sellSelections[slot] ?? 0;

                            return ListTile(
                              leading: Image.asset(
                                'assets/sticker$slot.png',
                                width: 32,
                                height: 32,
                              ),
                              title: Row(
                                children: [
                                  // Keeps “You have x$quantity” from overflowing
                                  Expanded(
                                    child: Text(
                                      'You have x$quantity',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  // Wrap each text in Flexible so they can shrink
                                  Flexible(
                                    child: Text(
                                      'Sell',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Image.asset(
                                      'assets/coin_boba.png',
                                      width: 16,
                                      height: 16),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '$rate each',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: selectedCount > 0
                                        ? () {
                                            setState(() {
                                              _sellSelections[slot] =
                                                  selectedCount - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text('$selectedCount'),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: selectedCount < quantity
                                        ? () {
                                            setState(() {
                                              _sellSelections[slot] =
                                                  selectedCount + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: (_isProcessingSell ||
                                    !_sellSelections.values
                                        .any((v) => v > 0))
                                ? null
                                : _sellSelected,
                            child: _isProcessingSell
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text(
                                    'Convert Selected to Coins'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // History Tab
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) =>
                          const Divider(),
                      itemBuilder: (context, idx) {
                        final item = _history[idx].value;
                        final asset =
                            item['boxAsset'] as String?;
                        final ts = item['timestamp']
                            as String?;
                        final time = ts != null
                            ? DateTime.parse(ts)
                                .toLocal()
                                .toString()
                                .split('.')[0]
                            : '';
                        final desc =
                            item['description']
                                as String? ??
                                '';
                        return ListTile(
                          leading: asset != null
                              ? Image.asset(asset,
                                  width: 32, height: 32)
                              : const SizedBox(
                                  width: 32, height: 32),
                          title: Text(time),
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
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.star_outline, size: 21),
                tooltip: 'Visits',
                onPressed: () =>
                    Navigator.pushNamed(context, '/review'),
              ),
              IconButton(
                icon: const Icon(
                    Icons.emoji_food_beverage_outlined,
                    size: 21),
                tooltip: 'Featured',
                onPressed: () =>
                    Navigator.pushNamed(context, '/featured'),
              ),
              IconButton(
                icon:
                    const Icon(Icons.home_outlined, size: 21),
                tooltip: 'Home',
                onPressed: () {
                  if (_uid.isNotEmpty) {
                    Navigator.pushReplacementNamed(
                        context, '/main',
                        arguments: _uid);
                  } else {
                    Navigator.pushReplacementNamed(
                        context, '/login');
                  }
                },
              ),
              IconButton(
                icon:
                    const Icon(Icons.map_outlined, size: 21),
                tooltip: 'Map',
                onPressed: () =>
                    Navigator.pushNamed(context, '/notifications'),
              ),
              IconButton(
                icon:
                    const Icon(Icons.person_outline, size: 21),
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
