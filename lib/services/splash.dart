import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _speckController;
  late final Animation<double> _speckOpacity;

  @override
  void initState() {
    super.initState();

    // Set up the speck's fade animation.
    _speckController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _speckOpacity = Tween<double>(begin: 0.3, end: 1.0).animate(_speckController);

    // Wait for 3 seconds before navigating to the login page.
    Future.delayed(const Duration(seconds: 3), _navigateToLogin);
  }

  void _navigateToLogin() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _speckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Simple gradient background.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF1ECE9), // Light warm gray.
              Color(0xFFFFFFFF), // White.
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "BOPO",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              // Boba ball with a fading speck.
              SpeckBobaBall(speckOpacity: _speckOpacity),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeckBobaBall extends StatelessWidget {
  final Animation<double> speckOpacity;

  const SpeckBobaBall({Key? key, required this.speckOpacity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // The ball is static; the speck is the animated part.
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          // Brown boba ball.
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4E342E), // Dark brown.
            ),
          ),
          // Fading speck in the top-right corner.
          Positioned(
            top: 8,
            right: 8,
            child: AnimatedBuilder(
              animation: speckOpacity,
              builder: (context, child) {
                return Opacity(
                  opacity: speckOpacity.value,
                  child: child,
                );
              },
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
