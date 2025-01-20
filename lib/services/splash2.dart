import 'package:flutter/material.dart';

class Splash2 extends StatefulWidget {
  @override
  _Splash2State createState() => _Splash2State();
}

class _Splash2State extends State<Splash2> {
  @override
  void initState() {
    super.initState();
    // Navigate to the home page after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacementNamed(context, '/main');
    });
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
            children: const [
              Text(
                "Logging in...",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 20),
              SimpleBobaBall(),
            ],
          ),
        ),
      ),
    );
  }
}

class SimpleBobaBall extends StatelessWidget {
  const SimpleBobaBall({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // A simple static circle representing the boba ball
    return Container(
      width: 50,
      height: 50,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF4E342E), // Solid dark brown color
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.9), // White speck
          ),
        ),
      ),
    );
  }
}
