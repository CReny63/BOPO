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
  final String zip; // Optional

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
  });

 factory BobaStore.fromJson(String id, Map<String, dynamic> json) {
  print("Parsing store with id: $id, data: $json");
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
    address: '123 Main St',
    city: 'San Marcos',
    state: 'CA',
    zip: '92069',
  ),
  BobaStore(
    name: 'Bubble Tea',
    imageName: 'bubble_tea',
    qrData: 'https://www.meta-verse.com/store/bubble_tea',
    id: '2',
    latitude: 34.0522,
    longitude: -118.2437,
    address: '456 Elm St',
    city: 'San Marcos',
    state: 'CA',
    zip: '92069',
  ),
  BobaStore(
    name: 'Happy Lemon',
    imageName: 'happy_lemon',
    qrData: 'https://www.meta-verse.com/store/happy_lemon',
    id: '3',
    latitude: 34.7749,
    longitude: -118.4194,
    address: '789 Oak St',
    city: 'San Marcos',
    state: 'CA',
    zip: '92069',
  ),
  BobaStore(
    name: 'Kung Fu',
    imageName: 'kung_fu',
    qrData: 'https://www.meta-verse.com/store/kung_fu',
    id: '4',
    latitude: 1,
    longitude: 1,
    address: 'No Address',
    city: 'San Marcos',
    state: 'CA',
    zip: '',
  ),
  BobaStore(
    name: 'Nintai Tea',
    imageName: 'nintai_tea',
    qrData: 'https://www.meta-verse.com/store/nintai_tea',
    id: '5',
    latitude: 1,
    longitude: 1,
    address: 'No Address',
    city: 'San Marcos',
    state: 'CA',
    zip: '',
  ),
  BobaStore(
    name: 'Serenitea',
    imageName: 'serenitea',
    qrData: 'https://www.meta-verse.com/store/serenitea',
    id: '6',
    latitude: 1,
    longitude: 1,
    address: 'No Address',
    city: 'San Marcos',
    state: 'CA',
    zip: '',
  ),
  BobaStore(
    name: 'Tea Amo',
    imageName: 'tea_amo',
    qrData: 'https://www.meta-verse.com/store/tea_amo',
    id: '7',
    latitude: 1,
    longitude: 1,
    address: 'No Address',
    city: 'San Marcos',
    state: 'CA',
    zip: '',
  ),
  BobaStore(
    name: 'Vivi Tea',
    imageName: 'vivi_tea',
    qrData: 'https://www.meta-verse.com/store/vivi_tea',
    id: '8',
    latitude: 1,
    longitude: 1,
    address: 'No Address',
    city: 'San Marcos',
    state: 'CA',
    zip: '',
  ),
  BobaStore(
    name: 'Ding Tea',
    imageName: 'dingtealogo',
    qrData: 'https://www.meta-verse.com/store/ding_tea',
    id: '9',
    latitude: 33.130827,
    longitude: -117.227392,
    address: '321 Pine St',
    city: 'San Marcos',
    state: 'CA',
    zip: '92069',
  ),
];
