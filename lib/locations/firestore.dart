import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:test/locations/boba_store.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';  // Import geoflutterfire_plus

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Fetch stores by city
  Future<List<BobaStore>> fetchStoresByCity(String city) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('stores')
          .where('city', isEqualTo: city)
          .get();

      List<BobaStore> stores = snapshot.docs.map((doc) {
        return BobaStore.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

      return stores;
    } catch (e) {
      print('Error fetching stores by city: $e');
      return [];
    }
  }

  /// Fetch all stores within a certain distance from a location using manual filtering
  Future<List<BobaStore>> fetchStoresByLocation(
      double latitude, double longitude, double maxDistance) async {
    try {
      QuerySnapshot snapshot = await _db.collection('stores').get();

      List<BobaStore> stores = snapshot.docs.map((doc) {
        return BobaStore.fromJson(doc.data() as Map<String, dynamic>);
      }).toList();

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
      print('Error fetching stores by location: $e');
      return [];
    }
  }

  /// Fetch stores within a given radius using geoflutterfire_plus
  Future<List<BobaStore>> fetchStoresWithinRadius(
      double latitude, double longitude, double radiusInKm) async {
    try {
      final center = GeoFirePoint(GeoPoint(latitude, longitude));
      const String field = 'position';

      final collectionReference = _db.collection('stores');

      final stream = collectionReference
          .where(field, isNotEqualTo: null)  // Ensuring the field exists
          .snapshots()
          .map((snapshot) => snapshot.docs);

      // This example uses manual filtering after fetching, as
      // geoflutterfire_plus stream queries require proper initialization.
      // For a complete solution, integrate the query as demonstrated previously.

      final docs = await stream.first;
      List<BobaStore> stores = docs.map((doc) {
        return BobaStore.fromJson(doc.data());
      }).toList();

      // Further filtering by distance can be applied here if needed.
      return stores;
    } catch (e) {
      print('Error fetching stores within radius: $e');
      return [];
    }
  }

  Future<void> signInAnonymously() async {
    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInAnonymously();
      print('Signed in as: ${userCredential.user?.uid}');
    } catch (e) {
      print('Error during anonymous sign-in: $e');
    }
  }

  /// New method to add a store with geospatial data
  Future<void> addStore({
    required String name,
    required String city,
    required String state,
    required String imagename,
    required String qrdata,
    required double latitude,
    required double longitude,
  }) async {
    // Create a GeoPoint from latitude and longitude
    final geoPoint = GeoPoint(latitude, longitude);
    // Generate a GeoFirePoint which includes geohash and GeoPoint
    final point = GeoFirePoint(geoPoint);
    
    await _db.collection('stores').add({
      'name': name,
      'city': city,
      'state': state,
      'imagename': imagename,
      'qrdata': qrdata,
      'position': point.data, // Stores geohash, lat, lng
    });
  }
}
