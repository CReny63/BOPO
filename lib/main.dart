import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:test/locations/home_progress.dart';
import 'package:test/models/friends.dart';
import 'package:test/models/reviews.dart' as review;
import 'package:test/locations/geolocator.dart';
import 'package:test/user.dart';
import 'package:test/models/notifications.dart' as notifications;
import 'package:test/services/theme_provider.dart';
import 'package:test/login.dart';
import 'package:test/services/splash.dart';
import 'package:test/services/splash2.dart';
import 'package:test/models/profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:test/models/friends.dart'; // Updated FeaturedPage
// import 'package:test/models/user_admin_page.dart'; // Uncomment if needed

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // Initialize Firebase

  // Automatically sign out after every restart.
  await GoogleSignIn().signOut();
  await FirebaseAuth.instance.signOut();

  // Initialize Hive for Flutter
  await Hive.initFlutter();
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
    // Request location permission at startup.
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
            // For pages that now obtain theme from Provider, we instantiate them without extra parameters.
            '/friends': (context) => const FeaturedPage(),
            '/splash': (context) => SplashScreen(),
            '/splash2': (context) => Splash2(),
            // Uncomment and adjust the following if needed:
            // '/user_admin': (context) => const UserAdminPage(),
            '/login': (context) => LoginPage(
                  themeProvider:
                      Provider.of<ThemeProvider>(context, listen: false),
                ),
            '/review': (context) {
              return review.StoresPage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
            '/splash3': (context) => const SplashScreen(),
            '/notifications': (context) {
              return notifications.NotificationsPage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
            '/profile': (context) {
              return ProfilePage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
                username: '', // Supply actual username as needed
                email: '', // Supply actual email as needed
              );
            },
          },
          onGenerateRoute: (settings) {
            if (settings.name == '/main') {
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  return HomeWithProgress(
                    isDarkMode: themeProvider.isDarkMode,
                    toggleTheme: themeProvider.toggleTheme,
                  );
                },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            }
            return null; // Use default behavior for other routes.
          },
          debugShowCheckedModeBanner: false,
          // Set home to the main page as fallback.
          home: HomeWithProgress(
            isDarkMode: themeProvider.isDarkMode,
            toggleTheme: themeProvider.toggleTheme,
          ),
        );
      },
    );
  }
}
