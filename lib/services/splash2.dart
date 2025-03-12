import 'package:flutter/material.dart';

class Splash2 extends StatefulWidget {
  const Splash2({Key? key}) : super(key: key);

  @override
  Splash2State createState() => Splash2State();
}

class Splash2State extends State<Splash2> with SingleTickerProviderStateMixin {
  // Controller for the speck's fade animation
  late final AnimationController _speckController;
  late final Animation<double> _speckOpacity;

  @override
  void initState() {
    super.initState();

    // Fade the speck in and out
    _speckController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Map controller 0.0->1.0 to 0.3->1.0 in opacity
    _speckOpacity = Tween<double>(begin: 0.3, end: 1.0).animate(_speckController);

    // Navigate to main after 3 seconds
    Future.delayed(const Duration(seconds: 3), _navigateToMain);
  }

  void _navigateToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  void dispose() {
    _speckController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Similar gradient background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFECEFF1), // Light Grayish-Blue
              Color(0xFFFFFFFF), // White
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          // Static column layout
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
              // Same boba ball, new fade controller
              SpeckBobaBall(speckOpacity: _speckOpacity),
            ],
          ),
        ),
      ),
    );
  }
}

// Reuse the same SpeckBobaBall widget or copy/paste it here
class SpeckBobaBall extends StatelessWidget {
  final Animation<double> speckOpacity;

  const SpeckBobaBall({Key? key, required this.speckOpacity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        children: [
          // Static boba ball
          Container(
            width: 50,
            height: 50,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF4E342E), // Dark brown
            ),
          ),
          // Fading speck in top-right corner
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
