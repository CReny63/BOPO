import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch stores by city
  Future<List<BobaStore>> fetchStoresByCity(String city) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('stores') // Firestore collection name
          .where('city', isEqualTo: city) // Filter by city
          .get();

      // Convert the fetched data into a list of BobaStore
      List<BobaStore> stores = snapshot.docs.map((doc) {
        return BobaStore.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      return stores;
    } catch (e) {
      print('Error fetching stores by city: $e');
      return [];
    }
  }

  /// Fetch all stores within a certain distance from a location
  Future<List<BobaStore>> fetchStoresByLocation(
      double latitude, double longitude, double maxDistance) async {
    try {
      QuerySnapshot snapshot = await _db.collection('stores').get();

      List<BobaStore> stores = snapshot.docs.map((doc) {
        return BobaStore.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      // Filter stores within the given distance
      List<BobaStore> nearbyStores = stores.where((store) {
        double distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          store.latitude,
          store.longitude,
        );
        return distance <= maxDistance; // Return stores within the range
      }).toList();

      return nearbyStores;
    } catch (e) {
      print('Error fetching stores by location: $e');
      return [];
    }
  }

  Future<void> signInAnonymously() async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
    print('Signed in as: ${userCredential.user?.uid}');
  } catch (e) {
    print('Error during anonymous sign-in: $e');
  }
}
}
