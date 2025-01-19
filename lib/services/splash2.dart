import 'package:flutter/material.dart';

class Splash2 extends StatefulWidget {
  @override
  _Splash2State createState() => _Splash2State();
}

class _Splash2State extends State<Splash2> with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    // Trigger fade animation once
    _fadeController.forward();

    // Navigate to the home page after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacementNamed(context, '/main');
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 249, 249, 249), // Light Beige
              Color.fromARGB(255, 254, 254, 254), // Tan
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: const Text(
                  "Logging in...",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 50,
                height: 50,
                child: _SimpleBobaBall(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SimpleBobaBall extends StatefulWidget {
  const _SimpleBobaBall();

  @override
  State<_SimpleBobaBall> createState() => _SimpleBobaBallState();
}

class _SimpleBobaBallState extends State<_SimpleBobaBall>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // Continuous rotation
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: Container(
        width: 50,
        height: 50,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF4E342E), // Solid dark brown color
        ),
        child: Center(
          // Off-center white speck to show rotation
          child: Transform.translate(
            offset: const Offset(15, 0), // Adjust offset for desired angle
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ),
      builder: (context, child) {
        return Transform.rotate(
          angle: _controller.value * 2 * 3.141592653589793,
          child: child,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
