import 'package:flutter/material.dart';
import 'package:test/widgets/app_bar_content.dart';

class NotificationsPage extends StatelessWidget {
  final VoidCallback toggleTheme;
  final bool isDarkMode;

  const NotificationsPage({
    super.key,
    required this.toggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: const AppBarContent(),
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: const Center(
        child: Text('noti Content Here'),
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
              tooltip: 'QR Code',
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.home_outlined, size: 21.0),
              tooltip: 'Home',
              onPressed: () => Navigator.pushNamed(context, '/main'),
            ),
            IconButton(
              icon: const Icon(Icons.discount_outlined, size: 21.0),
              tooltip: 'Notifications',
              onPressed: () {}, //already on noti page...
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

  // Widget _buildBottomNavItem(
  //     BuildContext context,
  //     IconData iconData,
  //     String tooltipMessage,
  //     VoidCallback onTap, {
  //       double iconSize = 24.0,
  //     }) {
  //   return Expanded(
  //     child: InkWell(
  //       onTap: onTap,
  //       child: Padding(
  //         padding: const EdgeInsets.symmetric(vertical: 8.0),
  //         child: Tooltip(
  //           message: tooltipMessage,
  //           child: Icon(
  //             iconData,
  //             size: iconSize,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  void _showQRCodeModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return const AlertDialog(
          title: Text('QR Code'),
          content: Text('QR Code content here'),
        );
      },
    );
  }
}
