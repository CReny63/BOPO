import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

class BobaStore extends Equatable {
  final String id;
  final String name;
  final String imageName;
  final String imageFeat;
  final String nameFeat;
  final String qrData;
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String zip;
  final String googlePlaceId;
  final int visits;
  final bool isFavorite;

  const BobaStore({
    required this.id,
    required this.name,
    required this.imageName,
    required this.imageFeat,
    required this.nameFeat,
    required this.qrData,
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

  /// Parses from a Firebase‐style JSON map.  
  factory BobaStore.fromJson(String key, Map<String, dynamic> json) {
    final cityName = (json['city'] as String?)?.trim().isNotEmpty == true
        ? json['city']!
        : 'UnknownCity';
    final uniqueId = '$cityName\_$key';

    return BobaStore(
      id: uniqueId,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? json['name']!
          : 'Unknown Name',
      imageName: (json['imagename'] as String?)?.trim().isNotEmpty == true
          ? json['imagename']!
          : 'default_image',
      imageFeat: (json['imagefeat'] as String?)?.trim().isNotEmpty == true
          ? json['imagefeat']!
          : 'default_featured',
      nameFeat: (json['namefeat'] as String?)?.trim().isNotEmpty == true
          ? json['namefeat']!
          : 'No Featured Name',
      qrData: (json['qrdata'] as String?)?.trim().isNotEmpty == true
          ? json['qrdata']!
          : '',
      latitude: (json['lat'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['lng'] as num?)?.toDouble() ?? 0.0,
      address: (json['address'] as String?)?.trim().isNotEmpty == true
          ? json['address']!
          : '',
      city: cityName,
      state: (json['state'] as String?)?.trim().isNotEmpty == true
          ? json['state']!
          : '',
      zip: (json['zip'] as String?)?.trim() ?? '',
      googlePlaceId:
          (json['googlePlaceId'] as String?)?.trim() ?? '',
      visits: (json['visits'] is int)
          ? json['visits'] as int
          : int.tryParse('${json['visits']}') ?? 0,
      isFavorite: json['isFavorite'] == true,
    );
  }

  /// Converts back to JSON for writes.
  Map<String, dynamic> toJson() => {
        'name': name,
        'imagename': imageName,
        'imagefeat': imageFeat,
        'namefeat': nameFeat,
        'qrdata': qrData,
        'lat': latitude,
        'lng': longitude,
        'address': address,
        'city': city,
        'state': state,
        'zip': zip,
        'googlePlaceId': googlePlaceId,
        'visits': visits,
        'isFavorite': isFavorite,
      };

  /// Returns a new instance with any fields overridden.
  BobaStore copyWith({
    String? id,
    String? name,
    String? imageName,
    String? imageFeat,
    String? nameFeat,
    String? qrData,
    double? latitude,
    double? longitude,
    String? address,
    String? city,
    String? state,
    String? zip,
    String? googlePlaceId,
    int? visits,
    bool? isFavorite,
  }) {
    return BobaStore(
      id: id ?? this.id,
      name: name ?? this.name,
      imageName: imageName ?? this.imageName,
      imageFeat: imageFeat ?? this.imageFeat,
      nameFeat: nameFeat ?? this.nameFeat,
      qrData: qrData ?? this.qrData,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      zip: zip ?? this.zip,
      googlePlaceId: googlePlaceId ?? this.googlePlaceId,
      visits: visits ?? this.visits,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  List<Object?> get props => [
        id,
        name,
        imageName,
        imageFeat,
        nameFeat,
        qrData,
        latitude,
        longitude,
        address,
        city,
        state,
        zip,
        googlePlaceId,
        visits,
        isFavorite,
      ];
}
