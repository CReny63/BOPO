// lib/widgets/custom_bottom_app_bar.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
import 'package:provider/provider.dart';
import 'package:test/services/theme_provider.dart';

/// A reusable BottomAppBar that highlights the current route’s icon.
/// Use this as `bottomNavigationBar: CustomBottomAppBar()` inside any Scaffold.
class CustomBottomAppBar extends StatelessWidget {
  const CustomBottomAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1) Determine current route name (null if not set)
    final String? currentRoute = ModalRoute.of(context)?.settings.name;

    // 2) Determine colors based on theme (light → orange for selected; dark → purple for selected)
    final theme = Provider.of<ThemeProvider>(context);
    final bool isDark = theme.isDarkMode;
    final Color selectedColor = isDark ? Colors.purple : Colors.orange;
    final Color unselectedColor = isDark ? Colors.white70 : Colors.grey;

    return BottomAppBar(
      color: Theme.of(context).colorScheme.surface,
      shape: const CircularNotchedRectangle(),
      notchMargin: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          // ─── Visits Tab ───────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.star_outline, size: 21),
            tooltip: 'Visits',
            color: currentRoute == '/review' ? selectedColor : unselectedColor,
            onPressed: () {
              if (currentRoute != '/review') {
                Navigator.pushReplacementNamed(context, '/review');
              }
            },
          ),

          // ─── Featured Tab ───────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.emoji_food_beverage_outlined, size: 21),
            tooltip: 'Featured',
            color: currentRoute == '/friends' ? selectedColor : unselectedColor,
            onPressed: () {
              if (currentRoute != '/friends') {
                Navigator.pushReplacementNamed(context, '/friends');
              }
            },
          ),

          // ─── Home Tab ────────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 21),
            tooltip: 'Home',
            color: currentRoute == '/main' ? selectedColor : unselectedColor,
            onPressed: () {
              final user = fbAuth.FirebaseAuth.instance.currentUser;
              if (user != null && user.uid.isNotEmpty) {
                if (currentRoute != '/main') {
                  Navigator.pushReplacementNamed(
                    context,
                    '/main',
                    arguments: user.uid,
                  );
                }
              } else {
                if (currentRoute != '/login') {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
          ),

          // ─── Map/Notifications Tab ──────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.map_outlined, size: 21),
            tooltip: 'Map',
            color: currentRoute == '/notifications'
                ? selectedColor
                : unselectedColor,
            onPressed: () {
              if (currentRoute != '/notifications') {
                Navigator.pushReplacementNamed(context, '/notifications');
              }
            },
          ),

          // ─── Profile Tab ────────────────────────────────────────────────
          IconButton(
            icon: const Icon(Icons.person_outline, size: 21),
            tooltip: 'Profile',
            color: currentRoute == '/profile' ? selectedColor : unselectedColor,
            onPressed: () {
              if (currentRoute != '/profile') {
                Navigator.pushReplacementNamed(context, '/profile');
              }
            },
          ),
        ],
      ),
    );
  }
}
