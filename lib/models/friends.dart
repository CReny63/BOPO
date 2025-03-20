import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard
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
  final TextEditingController friendCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Generate a unique code for this user.
    myFriendCode = _generateUniqueCode();
  }

  String _generateUniqueCode() {
    // Generate a random 8-character alphanumeric code.
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      8,
      (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
    ));
  }

  void _copyMyCode() {
    if (myFriendCode != null) {
      Clipboard.setData(ClipboardData(text: myFriendCode!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your code has been copied!")),
      );
    }
  }

  void _addFriend() {
    String friendCode = friendCodeController.text.trim();
    if (friendCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a friend's code.")),
      );
      return;
    }
    if (!friendsList.contains(friendCode)) {
      setState(() {
        friendsList.add(friendCode);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Friend added!")),
      );
      friendCodeController.clear();
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Card showing the user's unique friend code.
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Your Friend Code",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      myFriendCode ?? "",
                      style: const TextStyle(
                          fontSize: 24, color: Colors.brown),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _copyMyCode,
                      icon: const Icon(Icons.copy),
                      label: const Text("Copy Code"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade300,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Card for adding a friend via their code.
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text(
                      "Add a Friend",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: friendCodeController,
                      decoration: const InputDecoration(
                        labelText: "Enter Friend's Code",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _addFriend,
                      icon: const Icon(Icons.person_add),
                      label: const Text("Add Friend"),
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
            Expanded(
              child: Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Your Friends",
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: friendsList.isEmpty
                            ? const Center(child: Text("No friends added yet."))
                            : ListView.builder(
                                itemCount: friendsList.length,
                                itemBuilder: (context, index) {
                                  return ListTile(
                                    leading: const Icon(Icons.person),
                                    title: Text(friendsList[index]),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
