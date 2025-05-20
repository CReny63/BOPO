import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart'; // Import geoflutterfire_plus
   
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch stores from Firestore based on city with enhanced null-safety.
  Future<List<BobaStore>> fetchStoresByCity(String city) async {
    try {
      QuerySnapshot snapshot =
          await _db.collection('stores').where('city', isEqualTo: city).get();

      List<BobaStore> stores = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BobaStore.fromJson(doc.id, data);
      }).toList();

      return stores;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stores by city: $e');
      }
      return [];
    }
  }

  /// Fetch all stores within a certain distance from a location using manual filtering
  /// Fetch all stores and then filter by location (distance).
  Future<List<BobaStore>> fetchStoresByLocation(
      double latitude, double longitude, double maxDistance) async {
    try {
      QuerySnapshot snapshot = await _db.collection('stores').get();

      List<BobaStore> stores = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return BobaStore.fromJson(doc.id, data);
      }).toList();

      // Filter the stores based on distance.
      List<BobaStore> nearbyStores = stores.where((store) {
        double distance = Geolocator.distanceBetween(
          latitude,
          longitude,
          store.latitude,
          store.longitude,
        );
        return distance <= maxDistance;
      }).toList();

      return nearbyStores;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stores by location: $e');
      }
      return [];
    }
  }

  /// Fetch stores within a given radius using geoflutterfire_plus.
  Future<List<BobaStore>> fetchStoresWithinRadius(
      double latitude, double longitude, double radiusInKm) async {
    try {
      final center = GeoFirePoint(GeoPoint(latitude, longitude));
      const String field = 'position';

      final collectionReference = _db.collection('stores');

      // Stream the documents ensuring the 'position' field exists.
      final stream = collectionReference
          .where(field, isNotEqualTo: null)
          .snapshots()
          .map((snapshot) => snapshot.docs);

      final docs = await stream.first;
      List<BobaStore> stores = docs.map((doc) {
        final data = doc.data();
        return BobaStore.fromJson(doc.id, data);
      }).toList();

      // Optionally, apply further filtering by distance here if needed.
      return stores;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stores within radius: $e');
      }
      return [];
    }
  }

  /// Sign in anonymously using Firebase Authentication.
  Future<void> signInAnonymously() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInAnonymously();
      if (kDebugMode) {
        print('Signed in as: ${userCredential.user?.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during anonymous sign-in: $e');
      }
    }
  }

  /// Add a store with geospatial data to Firestore.
  Future<void> addStore({
    required String name,
    required String city,
    required String state,
    required String imagename,
    required String qrdata,
    required double latitude,
    required double longitude,
  }) async {
    try {
      // Create a GeoPoint and generate a GeoFirePoint (includes geohash and coordinates)
      final geoPoint = GeoPoint(latitude, longitude);
      final point = GeoFirePoint(geoPoint);

      await _db.collection('stores').add({
        'name': name,
        'city': city,
        'state': state,
        'imagename': imagename,
        'qrdata': qrdata,
        'position': point.data, // Contains geohash, lat, lng
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error adding store: $e');
      }
    }
  }
}
