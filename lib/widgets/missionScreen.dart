import 'package:flutter/material.dart';

class Mission {
  final String title;
  final String description;
  final int goal;
  final int current;

  const Mission({
    required this.title,
    required this.description,
    required this.current,
    required this.goal,
  });
}

class MissionsScreen extends StatelessWidget {
  // A set of unique scanned store IDs.
  final Set<String> scannedStoreIds;

  const MissionsScreen({Key? key, required this.scannedStoreIds}) : super(key: key);

  /// Generates a list of missions with their current progress updated
  /// based on the number of unique store scans.
  List<Mission> getMissions() {
    final int uniqueCount = scannedStoreIds.length;
    return [
      Mission(
        title: "Scan 3 Unique Stores",
        description: "Scan the QR codes at 3 different stores to unlock your reward!",
        current: uniqueCount >= 3 ? 3 : uniqueCount,
        goal: 3,
      ),
      Mission(
        title: "Scan 5 Unique Stores",
        description: "Scan the QR codes at 5 different stores to unlock a bonus!",
        current: uniqueCount >= 5 ? 5 : uniqueCount,
        goal: 5,
      ),
      Mission(
        title: "Scan 10 Unique Stores",
        description: "Complete scanning at 10 unique stores for a major reward!",
        current: uniqueCount >= 10 ? 10 : uniqueCount,
        goal: 10,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final missions = getMissions();

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
