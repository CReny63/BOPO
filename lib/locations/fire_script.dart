import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreDataUploader {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Upload sample store data to Firestore
  Future<void> uploadSampleData() async {
    final List<Map<String, dynamic>> sampleData = [
      {
        'name': 'Share Tea',
        'imageName': 'sharetealogo.png',
        'qrData': 'https://www.meta-verse.com/store/share_tea',
        'latitude': 33.1598,
        'longitude': -117.2049,
        'city': 'San Marcos, CA',
      },
      {
        'name': 'Bubble Tea',
        'imageName': 'bubble_tea.png',
        'qrData': 'https://www.meta-verse.com/store/bubble_tea',
        'latitude': 34.0522,
        'longitude': -118.2437,
        'city': 'Los Angeles, CA',
      },
      {
        'name': 'Happy Lemon',
        'imageName': 'happy_lemon.png',
        'qrData': 'https://www.meta-verse.com/store/happy_lemon',
        'latitude': 37.7749,
        'longitude': -122.4194,
        'city': 'San Francisco, CA',
      },
      {
        'name': 'Kung Fu Tea',
        'imageName': 'kung_fu_tea.png',
        'qrData': 'https://www.meta-verse.com/store/kung_fu_tea',
        'latitude': 36.7783,
        'longitude': -119.4179,
        'city': 'Fresno, CA',
      },
    ];

    try {
      for (var store in sampleData) {
        await _db.collection('stores').add(store);
      }
      print('Sample data uploaded successfully.');
    } catch (e) {
      print('Error uploading data: $e');
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Required for Firebase initialization
  FirestoreDataUploader uploader = FirestoreDataUploader();

  await uploader.uploadSampleData(); // Call this to upload data
}
