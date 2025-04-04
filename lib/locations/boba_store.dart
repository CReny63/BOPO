import 'package:flutter/foundation.dart';

class BobaStore {
  final String name;
  final String imageName;
  final String imagefeat; // New attribute for the featured image filename.
  final String namefeat;  // New attribute for the featured name.
  final String qrData;
  final String id;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String googlePlaceId; // New field for the Google Place ID.
  int visits;
  bool isFavorite;

  BobaStore({
    required this.name,
    required this.imageName,
    required this.imagefeat,
    required this.namefeat,
    required this.qrData,
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.zip,
    required this.googlePlaceId,
    this.visits = 0,
    this.isFavorite = false,
  });

  factory BobaStore.fromJson(String id, Map<String, dynamic> json) {
    // Retrieve the city from the JSON, or use a default value.
    final String cityName = json['city'] ?? 'UnknownCity';
    // Create a unique ID by concatenating the city name and the key.
    final String uniqueId = "${cityName}_$id";
    
    if (kDebugMode) {
      print("Parsing store with unique id: $uniqueId, data: $json");
    }
    
    return BobaStore(
      id: uniqueId,
      name: json['name'] ?? 'Unknown Name',
      imageName: (json['imagename'] != null) ? json['imagename'] : 'default_image',
     imagefeat: (json['imagefeat'] != null && (json['imagefeat'] as String).trim().isNotEmpty)
    ? json['imagefeat']
    : 'default_featured',
    
      namefeat: (json['namefeat'] != null) ? json['namefeat'] : 'No Featured Name',
      qrData: json['qrdata'] ?? 'No QR Data',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: json['address'] ?? 'No Address',
      city: cityName,
      state: json['state'] ?? 'Unknown State',
      zip: json['zip'] ?? '',
      googlePlaceId: json['googlePlaceId'] ?? '',
      visits: json['visits'] != null ? json['visits'] as int : 0,
      isFavorite: json['isFavorite'] ?? false,
    );
  }
}
