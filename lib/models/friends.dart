import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';

class StorePage extends StatefulWidget {
  const StorePage({Key? key}) : super(key: key);

  @override
  _StorePageState createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  late DatabaseReference _userRef;
  String _uid = '';
  int _coins = 10;
  List<String> _unlockedStickers = [];

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

    setState(() {
      _coins = coinSnap.exists ? (coinSnap.value as int) : 0;
      if (stickerSnap.exists) {
        final data = Map<String, dynamic>.from(stickerSnap.value as Map);
        _unlockedStickers = data.values
            .map((e) => e['asset'] as String)
            .toList();
      }
    });
  }

  Future<void> _openBox(_MysteryBox box) async {
    if (_coins < box.cost) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Not enough coins')),
      );
      return;
    }

    // Deduct cost
    await _updateCoins(-box.cost);

    // Reward coins 20-25
    final reward = Random().nextInt(6) + 20;
    await _updateCoins(reward);

    // Unlock sticker
    final assets = [
      'stickers/sticker1.png',
      'stickers/sticker2.png',
      'stickers/sticker3.png',
      'stickers/sticker4.png',
      'stickers/sticker5.png',
    ];
    final sticker = assets[Random().nextInt(assets.length)];
    await _userRef.child('stickers').push().set({'asset': sticker});

    // Show splash dialog
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(sticker, width: 100, height: 100),
              const SizedBox(height: 12),
              Text('You earned \$${reward} coins!',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('New Sticker Unlocked!'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });

    await _initUser();
  }

  Future<void> _updateCoins(int delta) async {
    setState(() => _coins += delta);
    await _userRef.update({'coins': _coins});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: theme.toggleTheme,
          isDarkMode: theme.isDarkMode,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            // Coin count below AppBar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.monetization_on_outlined,
                    color: theme.isDarkMode ? Colors.amber : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  '$_coins',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mystery boxes row centered
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _boxes.map((box) {
                return GestureDetector(
                  onTap: () => _openBox(box),
                  child: Column(
                    children: [
                      Image.asset(box.asset, width: 64, height: 64),
                      const SizedBox(height: 8),
                      Text(box.title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: box.color)),
                      Text('${box.cost} coins',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            // Sticker collection
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Your Stickers',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: _unlockedStickers.length,
                itemBuilder: (context, idx) {
                  return Image.asset(_unlockedStickers[idx]);
                },
              ),
            ),
          ],
        ),
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
              icon: const Icon(Icons.emoji_food_beverage_outlined),
              tooltip: 'Featured',
              onPressed: () => Navigator.pushNamed(context, '/featured'),
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
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined),
              tooltip: 'Map',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => Navigator.pushNamed(context, '/profile'),
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