// lib/models/boba_store.dart

class BobaStore {
  final String name;
  final String imageName;
  final String qrData;
  final String id;
  final double latitude;
  final double longitude;

  BobaStore({
    required this.name,
    required this.imageName,
    required this.qrData,
    required this.id,
    required this.latitude,
    required this.longitude,
  });

    factory BobaStore.fromJson(Map<String, dynamic> json) {
    return BobaStore(
      id: json['id'],
      name: json['name'],
      imageName: json['imageName'],
      qrData: json['qrData'],
      latitude: json['latitude'],
      longitude: json['longitude'],
    );
  }
}



// List of Boba Stores
List<BobaStore> bobaStores = [
  BobaStore(
    name: 'Share Tea',
    imageName: 'sharetealogo',
    qrData: 'https://www.meta-verse.com/store/share_tea',
    id: '1',
    latitude: 33.130827,
    longitude: -117.227392,
  ),
  BobaStore(
    name: 'Bubble Tea',
    imageName: 'bubble_tea',
    qrData: 'https://www.meta-verse.com/store/bubble_tea',
    id: '2',
    latitude: 34.0522,
    longitude: -118.2437,
  ),
  BobaStore(
    name: 'Happy Lemon',
    imageName: 'happy_lemon',
    qrData: 'https://www.meta-verse.com/store/happy_lemon',
    id: '3',
    latitude: 37.7749,
    longitude: -122.4194,
  ),
  BobaStore(
    name: 'Kung Fu',
    imageName: 'kung_fu',
    qrData: 'https://www.meta-verse.com/store/kung_fu',
    id: '4',
    latitude: 1,
    longitude: 1,
  ),
  BobaStore(
    name: 'Nintai Tea',
    imageName: 'nintai_tea',
    qrData: 'https://www.meta-verse.com/store/nintai_tea',
    id: '5',
    latitude: 1,
    longitude: 1,
  ),
  BobaStore(
    name: 'Serenitea',
    imageName: 'serenitea',
    qrData: 'https://www.meta-verse.com/store/serenitea',
    id: '6',
    latitude: 1,
    longitude: 1,
  ),
  BobaStore(
    name: 'Tea Amo',
    imageName: 'tea_amo',
    qrData: 'https://www.meta-verse.com/store/tea_amo',
    id: '7',
    latitude: 1,
    longitude: 1,
  ),
  BobaStore(
    name: 'Vivi Tea',
    imageName: 'vivi_tea',
    qrData: 'https://www.meta-verse.com/store/vivi_tea',
    id: '8',
    latitude: 1,
    longitude: 1,
  ),
  BobaStore(
    
    name: 'Ding Tea',
    imageName: 'dingtealogo',
    qrData: 'https://www.meta-verse.com/store/ding_tea',
    id: '9',
    latitude: 33.130827,
    longitude: -117.227392,
  ),
];
