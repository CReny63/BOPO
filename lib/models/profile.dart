import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart'; // Adjust the path as needed
import 'package:test/widgets/app_bar_content.dart';

class ProfilePage extends StatelessWidget {
  final String username;
  final String email;
  // The password is not displayed in plain text – using a masked value.
  final String maskedPassword;

  const ProfilePage({
    Key? key,
    required this.username,
    required this.email,
    this.maskedPassword = '********', required bool isDarkMode, required void Function() toggleTheme,
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
                // Add your reset password logic here (e.g. sending a one-time code).
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
    // Replace this with your logout logic (e.g. FirebaseAuth.instance.signOut()).
    print('Logout pressed');
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Build the Account tab.
  Widget _buildAccountTab(BuildContext context) {
    return ListView(
      children: [
        _buildListTile(
          'My Missions',
          'View your missions progress',
          Icons.emoji_events,
          () => Navigator.pushNamed(context, '/missions'),
        ),
        _buildListTile(
          'Get Help',
          'Access Q/A support',
          Icons.help_outline,
          () => Navigator.pushNamed(context, '/q_a'),
        ),
        _buildListTile(
          'Saved Stores',
          'View your starred stores',
          Icons.store,
          () => Navigator.pushNamed(context, '/savedStores'),
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
    // Obtain the theme provider to get current theme values.
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
    // Obtain theme values from ThemeProvider.
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
              tooltip: 'Map',
              onPressed: () => Navigator.pushNamed(context, '/notifications'),
            ),
            IconButton(
              icon: const Icon(Icons.person_outline, size: 21.0),
              tooltip: 'Profile',
              onPressed: () {
                // Already on this page.
              },
            ),
          ],
        ),
      ),
    );
  }
}
