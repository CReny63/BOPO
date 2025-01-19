// lib/widgets/circular_layout.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/boba_store.dart';

class CircularLayout extends StatelessWidget {
  final double radius;
  final Widget centralWidget;
  final List<BobaStore> bobaStores;

  const CircularLayout({
    Key? key,
    required this.radius,
    required this.centralWidget,
    required this.bobaStores,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int itemCount = bobaStores.length;
    final double angleIncrement = 2 * pi / itemCount;

    return SizedBox(
      width: radius * 3,
      height: radius * 3,
      child: Stack(
        alignment: Alignment.center,
        children: [
          centralWidget,
          for (int i = 0; i < itemCount; i++) _buildPositionedStore(context, i, angleIncrement),
        ],
      ),
    );
  }

  Widget _buildPositionedStore(BuildContext context, int index, double angleIncrement) {
    final double orbitRadius = radius * 1.5;
    final double angle = angleIncrement * index - pi / 2;
    final double x = orbitRadius * cos(angle);
    final double y = orbitRadius * sin(angle);

    BobaStore store = bobaStores[index];
    return Transform.translate(
      offset: Offset(x, y),
      child: Tooltip(
        message: store.name,
        child: GestureDetector(
          onTap: () {
            // Handle store tap (e.g., show details or QR code)
          },
          child: CircleAvatar(
            radius: 30,
            backgroundImage: AssetImage('assets/${store.imageName}.png'),
            backgroundColor: Colors.transparent,
          ),
        ),
      ),
    );
  }
}
