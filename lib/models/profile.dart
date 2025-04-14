import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:test/widgets/app_bar_content.dart';
import 'package:test/widgets/missionScreen.dart';

/// A simple HelpScreen for Q&A support.
class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get Help'),
      ),
      body: const Center(
        child: Text(
          'Q&A\n\nHere are some frequently asked questions and answers...',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

/// A simple SavedStores screen that displays the saved/starred stores.
class SavedStoresScreen extends StatelessWidget {
  final String uid;
  const SavedStoresScreen({Key? key, required this.uid}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Here you would retrieve the saved stores for the user (using uid)
    // For demonstration, we simply show placeholder content.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Stores'),
      ),
      body: const Center(
        child: Text(
          'List of your saved stores will appear here.',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final String username;
  final String email;
  // The password is not displayed in plain text – using a masked value.
  final String maskedPassword;
  final bool isDarkMode;
  final void Function() toggleTheme;

  const ProfilePage({
    Key? key,
    required this.username,
    required this.email,
    this.maskedPassword = '********',
    required this.isDarkMode,
    required this.toggleTheme,
  }) : super(key: key);

  // Shows the Manage Account dialog with user details and a reset password button.
  void _showManageAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Manage Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Username'),
                subtitle: Text(username),
              ),
              ListTile(
                title: const Text('Email'),
                subtitle: Text(email),
              ),
              ListTile(
                title: const Text('Password'),
                subtitle: Text(maskedPassword),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Add your reset password logic here.
                print('Reset password pressed - sending one time code.');
                Navigator.of(context).pop();
              },
              child: const Text('Reset Password'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Shows the Privacy dialog with details about the user's location usage.
  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Privacy'),
          content: const Text(
            'Your location data is used solely for personalized recommendations and will not be shared with third parties.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Logs out the user.
  void _logout(BuildContext context) {
    print('Logout pressed');
    // Replace this with your Firebase sign-out logic if needed.
    fbAuth.FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Build the Account tab with updated actions.
  Widget _buildAccountTab(BuildContext context) {
  // Retrieve the current Firebase user and extract the UID.
  final fbAuth.User? currentUser = fbAuth.FirebaseAuth.instance.currentUser;
  final String uid = currentUser?.uid ?? '';

  return ListView(
    children: [
      _buildListTile(
        'My Missions',
        'View your missions progress',
        Icons.emoji_events,
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MissionsScreen(
              userId: uid, // Use the retrieved uid
              storeId: "Oceanside_store1", // Example store id
              storeLatitude: 33.15965,
              storeLongitude: -117.2048917,
              storeCity: "Oceanside",
              scannedStoreIds: <String>{},
              themeProvider: Provider.of<ThemeProvider>(context, listen: false),
            ),
          ),
        ),
      ),
      _buildListTile(
        'Get Help',
        'Access Q/A support',
        Icons.help_outline,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const HelpScreen()),
        ),
      ),
      _buildListTile(
        'Saved Stores',
        'View your starred stores',
        Icons.store,
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SavedStoresScreen(uid: uid)),
        ),
      ),
      _buildListTile(
        'Privacy',
        'Learn about how your location is used',
        Icons.privacy_tip_outlined,
        () => _showPrivacyDialog(context),
      ),
    ],
  );
}


  // Build the Settings tab.
  Widget _buildSettingsTab(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return ListView(
      children: [
        _buildListTile(
          'Manage Account',
          'View and update your account details',
          Icons.account_circle,
          () => _showManageAccountDialog(context),
        ),
        _buildListTile(
          'Rate Us',
          'Leave a review on the app store',
          Icons.rate_review_outlined,
          () {
            // Add your Rate Us functionality here.
          },
        ),
        _buildListTile(
          themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
          themeProvider.isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
          themeProvider.isDarkMode ? Icons.wb_sunny : Icons.dark_mode,
          themeProvider.toggleTheme,
        ),
        _buildListTile(
          'Logout',
          'Sign out of your account',
          Icons.logout,
          () => _logout(context),
        ),
      ],
    );
  }

  // Helper method to build a ListTile.
  Widget _buildListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBarContent(
          toggleTheme: themeProvider.toggleTheme,
          isDarkMode: themeProvider.isDarkMode,
        ),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: <Widget>[
                  Container(
                    color: Theme.of(context).cardColor,
                    child: const TabBar(
                      labelColor: Color.fromARGB(255, 206, 189, 152),
                      tabs: [
                        Tab(text: 'Account'),
                        Tab(text: 'Settings'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildAccountTab(context),
                        _buildSettingsTab(context),
                      ],
                    ),
                  ),
                ],
              ),
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
              icon: const Icon(Icons.star_outline, size: 21.0),
              tooltip: 'Visits',
              onPressed: () => Navigator.pushNamed(context, '/review'),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_food_beverage_outlined, size: 21.0),
              tooltip: 'Featured',
              onPressed: () => Navigator.pushNamed(context, '/friends'),
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21.0),
              tooltip: 'Home',
              onPressed: () {
                final fbAuth.User? user = fbAuth.FirebaseAuth.instance.currentUser;
                if (user != null && user.uid.isNotEmpty) {
                  Navigator.pushReplacementNamed(context, '/main', arguments: user.uid);
                } else {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.map_outlined, size: 21.0),
              tooltip: 'Map',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, size: 21.0),
              tooltip: 'Profile',
              onPressed: () {
                // Already on the profile page.
              },
            ),
          ],
        ),
      ),
    );
  }
}
