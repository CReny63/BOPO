import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/widgets/app_bar_content.dart';

class FeaturedPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const FeaturedPage({
    Key? key,
    required this.toggleTheme,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  _FeaturedPageState createState() => _FeaturedPageState();
}

class _FeaturedPageState extends State<FeaturedPage> {
  // List of featured items using asset images.
  // Each item has a unique 'id' to track daily votes.
  final List<Map<String, dynamic>> featuredItems = [
    {
      'id': 'boba1',
      'imagePath': 'assets/sharetea_featured.png',
      'caption': 'New Drink: Matcha Bliss',
      'likes': 0,
      'dislikes': 0,
    },
    {
      'id': 'boba2',
      'imagePath': 'assets/dingtea_featured.png',
      'caption': 'Trending: Wintermelon',
      'likes': 0,
      'dislikes': 0,
    },
    {
      'id': 'boba3',
      'imagePath': 'assets/teaamo_featured.png',
      'caption': 'Trending: Matcha Strawberry',
      'likes': 0,
      'dislikes': 0,
    },
    // Add more featured items as needed.
  ];

  late String _today;

  @override
  void initState() {
    super.initState();
    _today = _getToday();
  }

  // Returns a simple date string (e.g., "2025-03-28")
  String _getToday() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  // Handles voting for an item.
  // voteType is either 'like' or 'dislike'
  Future<void> _voteItem(int index, String voteType) async {
    final prefs = await SharedPreferences.getInstance();
    final item = featuredItems[index];
    final key = 'vote_${item['id']}';
    String? storedValue = prefs.getString(key);

    String? storedVote;
    String storedDate = '';

    if (storedValue != null) {
      // Stored format: "vote|date" (e.g., "like|2025-03-28")
      final parts = storedValue.split('|');
      if (parts.length == 2) {
        storedVote = parts[0];
        storedDate = parts[1];
      }
    }

    // Check if a vote was cast today
    if (storedDate == _today) {
      // If the same vote is tapped again, do nothing.
      if (storedVote == voteType) {
        return;
      } else {
        // User is switching vote: update the counts accordingly.
        setState(() {
          if (voteType == 'like') {
            if (item['dislikes'] > 0) item['dislikes']--;
            item['likes']++;
          } else if (voteType == 'dislike') {
            if (item['likes'] > 0) item['likes']--;
            item['dislikes']++;
          }
        });
        await prefs.setString(key, '$voteType|$_today');
      }
    } else {
      // No vote for today: register the new vote.
      setState(() {
        if (voteType == 'like') {
          item['likes']++;
        } else if (voteType == 'dislike') {
          item['dislikes']++;
        }
      });
      await prefs.setString(key, '$voteType|$_today');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Reuse your existing top app bar for consistency.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: const AppBarContent(),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CarouselSlider.builder(
        itemCount: featuredItems.length,
        itemBuilder: (context, index, realIndex) {
          final item = featuredItems[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                // Display asset image.
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item['imagePath'],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
                // Caption overlay.
                Positioned(
                  bottom: 70,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.black54,
                    child: Text(
                      item['caption'],
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Like button and count.
                Positioned(
                  bottom: 10,
                  left: 10,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_up, color: Colors.white),
                        onPressed: () => _voteItem(index, 'like'),
                      ),
                      Text(
                        '${item['likes']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Dislike button and count.
                Positioned(
                  bottom: 10,
                  right: 10,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.thumb_down, color: Colors.white),
                        onPressed: () => _voteItem(index, 'dislike'),
                      ),
                      Text(
                        '${item['dislikes']}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        options: CarouselOptions(
          height: MediaQuery.of(context).size.height * 0.75,
          enlargeCenterPage: true,
          enableInfiniteScroll: false,
          autoPlay: true,
        ),
      ),
      // Reuse your existing bottom navigation.
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.star_outline, size: 21.0),
              tooltip: 'Featured',
              onPressed: () => Navigator.pushNamed(context, '/featured'),
            ),
            IconButton(
              icon: const Icon(Icons.people_alt_outlined, size: 21.0),
              tooltip: 'Friends',
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21.0),
              tooltip: 'Home',
              onPressed: () => Navigator.pushNamed(context, '/main'),
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 21.0),
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
