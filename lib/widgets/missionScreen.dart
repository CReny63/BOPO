// missions_screen.dart
import 'package:flutter/material.dart';

class Mission {
  final String title;
  final String description;
  final int current;
  final int goal;

  const Mission({
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
  });
}

class MissionsScreen extends StatelessWidget {
  const MissionsScreen({Key? key}) : super(key: key);

  // Dummy list of missions. In a real app, these values would be dynamic.
  final List<Mission> missions = const [
    Mission(
      title: "Scan 3 Unique Stores",
      description: "Scan the QR codes at 3 different stores to unlock your reward!",
      current: 1,
      goal: 3,
    ),
    Mission(
      title: "Scan 5 Unique Stores",
      description: "Scan the QR codes at 5 different stores to unlock a bonus!",
      current: 2,
      goal: 5,
    ),
    Mission(
      title: "Scan 10 Unique Stores",
      description: "Complete scanning at 10 unique stores for a major reward!",
      current: 0,
      goal: 10,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Missions"),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: missions.length,
        itemBuilder: (context, index) {
          final mission = missions[index];
          double progress = mission.goal == 0 ? 0 : mission.current / mission.goal;
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    mission.description,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "${mission.current} / ${mission.goal} scanned",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
