// lib/widgets/store_page.dart

import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/models/bottom_bar.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:intl/intl.dart';

/// ─── MYSTERY BOX MODEL ─────────────────────────────────────────────────────────
class _MysteryBox {
  final String title;
  final int cost;
  final Color color;
  final String asset;

  const _MysteryBox(this.title, this.cost, this.color, this.asset);
}

/// ─── REWARD SPLASH PAGE ────────────────────────────────────────────────────────
/// Now respects light/dark mode, and only shows “New Sticker Unlocked!”
/// if [isNewSticker] is true.
class RewardSplashPage extends StatelessWidget {
  final int reward;
  final String stickerAsset;
  final bool isNewSticker;

  const RewardSplashPage({
    Key? key,
    required this.reward,
    required this.stickerAsset,
    required this.isNewSticker,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = theme.isDarkMode;

    return Scaffold(
      // Adapt background to theme
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(stickerAsset, width: 120, height: 120),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '+$reward',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amberAccent : Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 6),
                Image.asset('assets/coin_boba.png', width: 24, height: 24),
              ],
            ),
            const SizedBox(height: 12),
            if (isNewSticker)
              Text(
                'New Sticker Unlocked!',
                style: TextStyle(
                  fontSize: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.purpleAccent : Colors.orange,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Continue',
                style: TextStyle(
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── BOX DETAIL PAGE ───────────────────────────────────────────────────────────
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
    // Box color header stays same; but the rest of the page will adapt automatically
    // because it uses the default background/text colors.
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
                Text(
                  '${box.cost}',
                  style: const TextStyle(fontSize: 20),
                ),
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
              child: Text(
                'Open Box',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── STORE PAGE WITH TABS (Collection, Shop, History) ──────────────────────────
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

  // How many of each sticker the user wants to sell (0…available)
  Map<int, int> _sellSelections = {};
  bool _isProcessingSell = false;

  bool _allSelected = false;

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
      if (!mounted) return;
      final val = event.snapshot.value;
      if (val is int) {
        setState(() => _coins = val);
      }
    });

    // Load existing stickers
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
      _sellSelections = {for (var slot in counts.keys) slot: 0};
      _allSelected = false;
    });
  }

  @override
  void dispose() {
    _coinSub.cancel();
    super.dispose();
  }

  /// Opens a mystery box, awards coins + possibly a sticker.
  Future<void> _openBox(_MysteryBox box) async {
    if (_coins < box.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }

    int rewardCoins;
    if (box.title == 'Bronze Box') {
      rewardCoins = Random().nextInt(3) + 1; // 1–3
    } else if (box.title == 'Silver Box') {
      rewardCoins = Random().nextInt(3) + 3; // 3–5
    } else {
      rewardCoins = Random().nextInt(4) + 5; // 5–8
    }

    await _userRef.child('coins').set(_coins - box.cost + rewardCoins);

    // Determine sticker ID pool:
    List<int> pool;
    if (box.title == 'Bronze Box') {
      pool = List.generate(24, (i) => i + 1); // 1–24
    } else if (box.title == 'Silver Box') {
      pool = List.generate(11, (i) => i + 25); // 25–35
    } else {
      pool = List.generate(15, (i) => i + 36); // 36–50
    }

    // Weight map (higher IDs rarer)
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

    // Check if user already has that sticker:
    final alreadyHas =
        (_stickerCounts.containsKey(chosenId) && _stickerCounts[chosenId]! > 0);
    final stickerAsset = 'assets/sticker$chosenId.png';

    // Always record the sticker (duplicates included)
    await _userRef.child('stickers').push().set({'asset': stickerAsset});

    // Add to history
    await _userRef.child('history').push().set({
      'description': 'Opened ${box.title}: +$rewardCoins coins',
      'timestamp': DateTime.now().toIso8601String(),
      'boxAsset': box.asset,
      'stickerId': chosenId,
    });

    // Show the splash. Pass isNewSticker = !alreadyHas
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RewardSplashPage(
          reward: rewardCoins,
          stickerAsset: stickerAsset,
          isNewSticker: !alreadyHas,
        ),
      ),
    ).then((_) => _initUser());
  }

  /// Toggles “Select All” ↔ “Deselect All” for the Sell‐Stickers list.
  void _toggleSelectAll() {
    if (_allSelected) {
      // Deselect all
      setState(() {
        _sellSelections = {for (var slot in _stickerCounts.keys) slot: 0};
        _allSelected = false;
      });
    } else {
      // Select all at maximum possible
      setState(() {
        _sellSelections = {
          for (var slot in _stickerCounts.keys) slot: _stickerCounts[slot]!
        };
        _allSelected = true;
      });
    }
  }

  /// Sells whichever stickers have a positive selected quantity.
  Future<void> _sellSelected() async {
    if (_isProcessingSell) return;
    final toSell = <int, int>{};
    int totalEarned = 0;

    _sellSelections.forEach((slot, qty) {
      if (qty > 0) {
        final available = _stickerCounts[slot] ?? 0;
        final sellCount = qty.clamp(0, available);
        if (sellCount > 0) {
          final rate = slot <= 20
              ? 1
              : slot <= 39
                  ? 2
                  : 5;
          totalEarned += rate * sellCount;
          toSell[slot] = sellCount;
        }
      }
    });

    if (totalEarned == 0) return;

    setState(() => _isProcessingSell = true);

    await _userRef.child('coins').set(_coins + totalEarned);

    // Remove sold stickers from DB
    final stickersRef = _userRef.child('stickers');
    final snap = await stickersRef.get();
    if (snap.exists) {
      final data = Map<String, dynamic>.from(snap.value as Map);
      final toRemoveMap = Map<int, int>.from(toSell);
      for (var key in data.keys) {
        final m = RegExp(r'sticker(\d+)\.png').firstMatch(data[key]['asset']);
        if (m != null) {
          final slot = int.parse(m.group(1)!);
          if (toRemoveMap.containsKey(slot) && toRemoveMap[slot]! > 0) {
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
      _sellSelections = {for (var slot in _stickerCounts.keys) slot: 0};
      _allSelected = false;
      _isProcessingSell = false;
    });

    await _initUser();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(75),
          child: AppBarContent(
            toggleTheme: theme.toggleTheme,
            isDarkMode: isDark,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            TabBar(
              indicatorColor: isDark ? Colors.amber : Colors.orange,
              labelColor: isDark ? Colors.white : Colors.black,
              tabs: const [
                Tab(text: 'Collection'),
                Tab(text: 'Shop'),
                Tab(text: 'History'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // ── COLLECTION TAB ───────────────────────────────────────
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
                                    ? Image.asset('assets/sticker$slot.png')
                                    : Text(
                                        '$slot',
                                        style:
                                            const TextStyle(color: Colors.grey),
                                      ),
                              ),
                            ),
                            if (count > 1)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 15, // fixed diameter
                                  height: 15,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        isDark ? Colors.purple : Colors.orange,
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

                  // ── SHOP TAB ──────────────────────────────────────────────
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Coin Balance Row
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
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Mystery Boxes Carousel
                        SizedBox(
                          height: 300,
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
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: box.color, width: 4),
                                      borderRadius: BorderRadius.circular(16),
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
                                            Image.asset('assets/coin_boba.png',
                                                width: 25, height: 25),
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
                        // Sell Stickers Section Header + Select/Deselect All
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Sell Stickers for Coins',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              TextButton(
                                onPressed: _toggleSelectAll,
                                child: Text(_allSelected
                                    ? 'Deselect All'
                                    : 'Select All'),
                              ),
                            ],
                          ),
                        ),

                        // List of stickers with +/- controls
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _stickerCounts.length,
                          itemBuilder: (context, idx) {
                            final slot = _stickerCounts.keys.elementAt(idx);
                            final quantity = _stickerCounts[slot]!;
                            final rate = slot <= 20
                                ? 1
                                : slot <= 39
                                    ? 2
                                    : 5;
                            final selectedCount = _sellSelections[slot] ?? 0;

                            return ListTile(
                              leading: Image.asset(
                                'assets/sticker$slot.png',
                                width: 32,
                                height: 32,
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${quantity}x',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Sell',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Image.asset('assets/coin_boba.png',
                                      width: 16, height: 16),
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
                                              _allSelected = false;
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
                                              if (_sellSelections[slot] ==
                                                  quantity) {
                                                // If all have been individually selected,
                                                // and every slot matches its max, flip _allSelected:
                                                final allMatch = _stickerCounts
                                                    .keys
                                                    .every((s) =>
                                                        _sellSelections[s] ==
                                                        _stickerCounts[s]);
                                                _allSelected = allMatch;
                                              } else {
                                                _allSelected = false;
                                              }
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // “Convert Selected to Coins” button
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: (_isProcessingSell ||
                                    !_sellSelections.values.any((v) => v > 0))
                                ? null
                                : _sellSelected,
                            child: _isProcessingSell
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Text('Convert Selected to Coins'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── HISTORY TAB ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: ListView.separated(
                      itemCount: _history.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, idx) {
                        final item = _history[idx].value;
                        final asset = item['boxAsset'] as String?;
                        final ts = item['timestamp'] as String?;
                        String dateStr = '';
                        String timeStr = '';
                        Widget rewardWidget = const SizedBox();

                        if (ts != null) {
                          final dt = DateTime.parse(ts).toLocal();
                          dateStr = DateFormat('MM/dd/yyyy').format(dt);
                          timeStr = DateFormat('h:mm a').format(dt);
                        }

                        // If your stored “description” always looks like “Opened <Box>: +<n> coins”,
                        // extract the “+n” part and show the coin image instead of the word “coins”.
                        final desc = item['description'] as String? ?? '';
                        final coinMatch = RegExp(r'\+(\d+)').firstMatch(desc);
                        if (coinMatch != null) {
                          // e.g. "+5"
                          final amount =
                              coinMatch.group(0); // including the plus sign
                          rewardWidget = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                amount!,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              Image.asset('assets/coin_boba.png',
                                  width: 16, height: 16),
                            ],
                          );
                        } else {
                          // fallback: just show the raw description
                          rewardWidget = Text(desc);
                        }

                        return ListTile(
                          leading: asset != null
                              ? Image.asset(asset, width: 32, height: 32)
                              : const SizedBox(width: 32, height: 32),
                          title: Text('$dateStr  $timeStr'),
                          subtitle: rewardWidget,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        /// ─── REUSABLE BOTTOM BAR ─────────────────────────────────────────────────
        bottomNavigationBar: const CustomBottomAppBar(
            //activeTab: BottomTab.shop, // highlight “Shop”
            ),
      ),
    );
  }
}
