import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart'; 
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class NearbyStoresWidget extends StatefulWidget {
  @override
  _NearbyStoresWidgetState createState() => _NearbyStoresWidgetState();
}

class _NearbyStoresWidgetState extends State<NearbyStoresWidget> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  Stream<List<DocumentSnapshot<Map<String, dynamic>>>>? stream;  // Make stream nullable
  late Position currentPosition;

  @override
  void initState() {
    super.initState();
    _initLocationAndQuery();
  }

  Future<void> _initLocationAndQuery() async {
    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Create a GeoFirePoint for the center of the query using current coordinates
    final centerPoint = GeoFirePoint(GeoPoint(currentPosition.latitude, currentPosition.longitude));

    double radiusInKm = 50.0;
    const String field = 'position'; 

    final collectionReference = firestore.collection('stores');

    // Set up a stream to listen for documents within the specified radius
    stream = GeoCollectionReference<Map<String, dynamic>>(collectionReference)
        .subscribeWithin(
          center: centerPoint,
          radiusInKm: radiusInKm,
          field: field,
          geopointFrom: (Map<String, dynamic> data) {
            final positionData = data['position'] as Map<String, dynamic>;
            return GeoPoint(
              (positionData['lat'] as num).toDouble(),
              (positionData['lng'] as num).toDouble(),
            );
          },
        );

    setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    // Check if stream is initialized
    if (stream == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<List<DocumentSnapshot<Map<String, dynamic>>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }
        final stores = snapshot.data!;
        return ListView.builder(
          itemCount: stores.length,
          itemBuilder: (context, index) {
            final data = stores[index].data();
            return ListTile(
              title: Text(data?['name'] ?? 'Unknown'),
              subtitle: Text('${data?['city']}, ${data?['state']}'),
            );
          },
        );
      },
    );
  }
}
