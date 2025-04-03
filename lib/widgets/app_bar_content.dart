import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class AppBarContent extends StatelessWidget {
  const AppBarContent({Key? key, required VoidCallback toggleTheme, required bool isDarkMode}) : super(key: key);

  // Opens a bottom sheet for support (Q&A + email support)
  void _openSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the bottom sheet to expand if needed.
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally.
              children: [
                const Text(
                  "Support",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Q&A:",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Q: How do I use the app?\nA: Simply scan store QR codes to unlock missions.",
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Q: How do I earn points?\nA: Complete the challenges in the missions page.",
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Q: Do I need to share my location?\nA: Yes, the app relies on geolocation services. We strive for maximum privacy and protection for all users.",
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Q: How does the layout work?\nA: The app uses your location and presents you the 8 nearest stores in your area. With the top circle being the closest to you.",
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final Uri emailLaunchUri = Uri(
                      scheme: 'mailto',
                      path: 'support@example.com', // Replace with your support email.
                      query: 'subject=App Support&body=I need help with...',
                    );
                    if (await canLaunchUrl(emailLaunchUri)) {
                      await launchUrl(
                        emailLaunchUri,
                        mode: LaunchMode.externalApplication,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Could not open email client."),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    Icons.email,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                  ),
                  label: const Text("Email Support"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Shows a dialog to confirm log out.
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Log Out"),
          content: const Text(
              "Do you really want to log out? Your information will be saved for next login."),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Add your sign-out logic here, e.g.:
                // FirebaseAuth.instance.signOut();
                Navigator.of(context).pop(); // dismiss dialog
                // Navigate back to the login screen.
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              },
              child: const Text(
                "Log Out",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).appBarTheme.backgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // PopupMenuButton to display the dropdown menu.
          PopupMenuButton<int>(
            icon: Icon(
              Icons.menu,
              size: 13,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
            onSelected: (value) {
              if (value == 1) {
                _openSupport(context);
              } else if (value == 2) {
                _confirmLogout(context);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
              PopupMenuItem<int>(
                value: 1,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.help,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text("Support"),
                  ],
                ),
              ),
              PopupMenuItem<int>(
                value: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.logout,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Log Out",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Theme toggle remains on the right.
          IconButton(
            icon: Icon(
              Icons.light_mode,
              size: 13,
              color: Theme.of(context).appBarTheme.iconTheme?.color,
            ),
            onPressed: () {
              Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
            },
          ),
        ],
      ),
    );
  }
}
