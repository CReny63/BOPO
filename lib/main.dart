import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:test/home_progress.dart';
import 'package:test/models/reviews.dart' as review;
import 'package:test/services/geolocator.dart';
import 'package:test/user.dart';
import 'package:provider/provider.dart';

// Import your widgets/models
import 'models/notifications.dart' as notifications;
import 'services/theme_provider.dart';
import 'login.dart';
import 'models/user_admin_page.dart';
import 'services/splash.dart';
import 'services/splash2.dart';
import 'models/profile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for Flutter
  await Hive.initFlutter();

  // Register adapters if you haven't yet
  Hive.registerAdapter(UserAdapter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Add other providers here if needed
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GeolocationService _geoService = GeolocationService();

  @override
  void initState() {
    super.initState();
    // Request location permission at startup
    _geoService.determinePosition().then((position) {
      print("Obtained position: $position");
    }).catchError((error) {
      print("Location error: $error");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Meta Verse',
          theme: themeProvider.currentTheme,
          initialRoute: '/splash', // Start at splash screen
          routes: {
            '/splash': (context) => SplashScreen(), // Splash1 -> user_admin
            '/splash2': (context) => Splash2(), // Sign in -> splash2 -> home
            '/user_admin': (context) => const UserAdminPage(),
            '/login': (context) => LoginPage(
                  themeProvider:
                      Provider.of<ThemeProvider>(context, listen: false),
                ),
            '/main': (context) => HomeWithProgress(
                  toggleTheme: themeProvider.toggleTheme,
                  isDarkMode: themeProvider.isDarkMode,
                ),
            '/review': (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              return review.ReviewsPage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
            '/notifications': (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              return notifications.NotificationsPage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
            '/profile': (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              return ProfilePage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
            // Add other routes here if needed
          },
          debugShowCheckedModeBanner: false,
          home: HomeWithProgress(
            isDarkMode: themeProvider.isDarkMode,
            toggleTheme: themeProvider.toggleTheme,
          ),
        );
      },
    );
  }
}
