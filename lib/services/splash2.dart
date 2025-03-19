import 'package:flutter/material.dart';

class Splash2 extends StatefulWidget {
  const Splash2({Key? key}) : super(key: key);

  @override
  Splash2State createState() => Splash2State();
}

class Splash2State extends State<Splash2> {
  @override
  void initState() {
    super.initState();
    // Wait for 3 seconds before navigating to the main screen.
    Future.delayed(const Duration(seconds: 4), _navigateToMain);
  }

  void _navigateToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Use a similar gradient background.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFECEFF1), // Light Grayish-Blue.
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
              // Display the static capy_boba.png image.
              Image.asset(
                'assets/capy_boba.png',
                width: 100,  // Adjust width as needed.
                height: 100, // Adjust height as needed.
              ),
            ],
          ),
        ),
      ),
    );
  }
}
