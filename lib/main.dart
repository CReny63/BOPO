import 'package:firebase_auth/firebase_auth.dart' as fbAuth;
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
//import 'package:test/models/friends.dart'; // Updated FeaturedPage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // Initialize Firebase

  // Automatically sign out after every restart (for testing/demo).
  await GoogleSignIn().signOut();
  await fbAuth.FirebaseAuth.instance.signOut();

  // Initialize Hive for Flutter.
  await Hive.initFlutter();
  Hive.registerAdapter(UserAdapter());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        // Add other providers if needed.
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
          initialRoute: '/splash', // Start at splash screen.
          routes: {
            '/friends': (context) => const FeaturedPage(),
            '/splash': (context) => SplashScreen(),
            // '/splash2' is handled via onGenerateRoute.
            '/login': (context) => LoginPage(
                  themeProvider: Provider.of<ThemeProvider>(context, listen: false),
                ),
            '/review': (context) {
              // Option 1: Obtain UID directly from FirebaseAuth, if desired.
              final fbAuth.User? user = fbAuth.FirebaseAuth.instance.currentUser;
              final String uid = user?.uid ?? '';
              return review.StoresPage(
                toggleTheme: Provider.of<ThemeProvider>(context, listen: false).toggleTheme,
                isDarkMode: Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
                uid: uid,
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
                username: '', // Supply actual username as needed.
                email: '',    // Supply actual email as needed.
              );
            },
          },
          // onGenerateRoute handles routes that require a UID argument.
          onGenerateRoute: (RouteSettings settings) {
            if (settings.name == '/splash2') {
              final uid = settings.arguments as String?;
              if (uid == null || uid.isEmpty) {
                return MaterialPageRoute(
                  builder: (_) => LoginPage(
                      themeProvider: Provider.of<ThemeProvider>(_, listen: false)),
                );
              }
              return MaterialPageRoute(builder: (_) => Splash2(uid: uid));
            }
            if (settings.name == '/main') {
              final uid = settings.arguments as String?;
              if (uid == null || uid.isEmpty) {
                return MaterialPageRoute(
                  builder: (_) => LoginPage(
                      themeProvider: Provider.of<ThemeProvider>(_, listen: false)),
                );
              }
              return MaterialPageRoute(
                builder: (_) => HomeWithProgress(
                  uid: uid,
                  isDarkMode: themeProvider.isDarkMode,
                  toggleTheme: themeProvider.toggleTheme,
                ),
              );
            }
            return null;
          },
          debugShowCheckedModeBanner: false,
          // Instead of a fallback home with an empty UID, use a FutureBuilder
          // to check FirebaseAuth state.
          home: FutureBuilder<fbAuth.User?>(
            future: fbAuth.FirebaseAuth.instance.authStateChanges().first,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData && snapshot.data != null) {
                // Use the real UID from FirebaseAuth.
                return HomeWithProgress(
                  uid: snapshot.data!.uid,
                  isDarkMode: themeProvider.isDarkMode,
                  toggleTheme: themeProvider.toggleTheme,
                );
              }
              return LoginPage(themeProvider: themeProvider);
            },
          ),
        );
      },
    );
  }
}
