import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/widgets/app_bar_content.dart';

class FriendsPage extends StatefulWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const FriendsPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  _FriendsPageState createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  String? myFriendCode;
  List<String> friendsList = [];
  final TextEditingController friendUsernameController = TextEditingController();

  // Placeholder for the current user's username.
  // In a real app, you'd fetch this from your user management system.
  final String currentUsername = "MyUsername";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Load or generate a unique friend code for this user.
    String? savedFriendCode = prefs.getString('myFriendCode');
    if (savedFriendCode == null) {
      myFriendCode = _generateUniqueCode();
      await prefs.setString('myFriendCode', myFriendCode!);
    } else {
      myFriendCode = savedFriendCode;
    }
    // Load the saved friends list.
    List<String>? savedFriends = prefs.getStringList('friendsList');
    if (savedFriends != null) {
      setState(() {
        friendsList = savedFriends;
      });
    }
  }

  String _generateUniqueCode() {
    // Generate a random 8-character alphanumeric code.
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(8, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  void _copyMyCode() {
    if (myFriendCode != null) {
      Clipboard.setData(ClipboardData(text: myFriendCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your code has been copied!")),
      );
    }
  }

  Future<void> _addFriend() async {
    String friendUsername = friendUsernameController.text.trim();
    if (friendUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a friend's username.")),
      );
      return;
    }
    // Prevent a user from adding themselves.
    if (friendUsername == currentUsername) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You cannot add yourself.")),
      );
      return;
    }
    if (!friendsList.contains(friendUsername)) {
      setState(() {
        friendsList.add(friendUsername);
      });
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('friendsList', friendsList);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend added!")),
      );
      friendUsernameController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend already added.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use your existing top AppBar.
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: const AppBarContent(),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Card showing the user's unique friend code.
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Your Friend Code",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    myFriendCode ?? "",
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: Colors.brown),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _copyMyCode,
                    icon: const Icon(Icons.copy),
                    label: Text(
                      "Copy Code",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Card for adding a friend via their username.
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Add a Friend",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: friendUsernameController,
                    decoration: const InputDecoration(
                      labelText: "Enter Friend's Username",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _addFriend,
                    icon: const Icon(Icons.person_add),
                    label: Text(
                      "Add Friend",
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade300,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Card showing the list of friends.
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Your Friends",
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  friendsList.isEmpty
                      ? Center(
                          child: Text(
                            "No friends added yet.",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: friendsList.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const Icon(Icons.person),
                              title: Text(
                                friendsList[index],
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
      // Use your existing bottom navigation.
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.star_outline, size: 21.0),
              tooltip: 'Reviews',
              onPressed: () => Navigator.pushNamed(context, '/review'),
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
