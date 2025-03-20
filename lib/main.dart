import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:test/locations/home_progress.dart';
import 'package:test/models/reviews.dart' as review;
import 'package:test/locations/geolocator.dart';
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
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(); // Initialize Firebase

  await GoogleSignIn()
      .signOut(); //automatically sign out user after every restart

  await FirebaseAuth.instance
      .signOut(); //automatically sign out of firebase after every restart

  // FirestoreDataUploader uploader = FirestoreDataUploader();

  // // Upload data to Firestore
  // await uploader.uploadSampleData(); //firebase sample database

  // // Exit the app after upload
  // print('Data upload completed.');

  //await signInAnonymously();

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

// Future<void> signInAnonymously() async {
//   try {
//     UserCredential userCredential =
//         await FirebaseAuth.instance.signInAnonymously();
//     print('Signed in as: ${userCredential.user?.uid}');
//   } catch (e) {
//     print('Error during anonymous sign-in: $e');
//   }
// }

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
            '/review': (context) {
              final themeProvider = Provider.of<ThemeProvider>(context);
              return review.StoresPage(
                toggleTheme: themeProvider.toggleTheme,
                isDarkMode: themeProvider.isDarkMode,
              );
            },
           
            '/splash3': (context) => const SplashScreen(),
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
          onGenerateRoute: (settings) {
            // Check if we're going to '/main'
            if (settings.name == '/main') {
              // Return a PageRouteBuilder with zero-duration transition:
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) {
                  // We can still access your theme provider, if needed:
                  final themeProvider =
                      Provider.of<ThemeProvider>(context, listen: false);
                  return HomeWithProgress(
                    isDarkMode: themeProvider.isDarkMode,
                    toggleTheme: themeProvider.toggleTheme,
                  );
                },
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              );
            }
            return null; // Let Flutter use the default behavior for other named routes
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
