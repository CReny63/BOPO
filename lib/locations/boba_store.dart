import 'package:flutter/foundation.dart';

class BobaStore {
  final String name;
  final String imageName;
  final String qrData;
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String zip;
  int visits;
  bool isFavorite;

  BobaStore({
    required this.name,
    required this.imageName,
    required this.qrData,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    this.visits = 0,
    this.isFavorite = false,
  });

  factory BobaStore.fromJson(String id, Map<String, dynamic> json) {
    if (kDebugMode) {
      print("Parsing store with id: $id, data: $json");
    }
    return BobaStore(
      id: id,
      name: json['name'] ?? 'Unknown Name',
      imageName: json.containsKey('imagename') && json['imagename'] != null
          ? json['imagename']
          : 'default_image',
      qrData: json['qrdata'] ?? 'No QR Data',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] ?? 'No Address',
      city: json['city'] ?? 'Unknown City',
      state: json['state'] ?? 'Unknown State',
      zip: json['zip'] ?? '',
      visits: json['visits'] != null ? json['visits'] as int : 0,
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}
