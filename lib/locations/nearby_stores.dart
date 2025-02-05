import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:test/locations/boba_store.dart';

class NearbyStoresWidget extends StatefulWidget {
  @override
  _NearbyStoresWidgetState createState() => _NearbyStoresWidgetState();
}

class _NearbyStoresWidgetState extends State<NearbyStoresWidget> {
  // Your Realtime Database endpoint (with .json)
  final String apiEndpoint ='https://bopo-f6eeb-default-rtdb.firebaseio.com/stores.json';
  List<BobaStore> stores = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStores();
  }

  Future<void> fetchStores() async {
    try {
      final url = Uri.parse(apiEndpoint);
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        List<BobaStore> fetchedStores = [];

        if (decoded is Map<String, dynamic>) {
          decoded.forEach((key, value) {
            if (value is Map<String, dynamic>) {
              fetchedStores.add(BobaStore.fromJson(key, value));
            }
          });
        } else if (decoded is List) {
          // Handle case where data is returned as a List
          for (var item in decoded) {
            if (item is Map<String, dynamic>) {
              // Since there is no key, you can pass an empty string or use an index
              fetchedStores.add(BobaStore.fromJson('', item));
            }
          }
        }
        setState(() {
          stores = fetchedStores;
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load stores');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
      print('Error fetching stores from Realtime Database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    if (stores.isEmpty) {
      return Center(child: Text('No stores found.'));
    }
    return ListView.builder(
      itemCount: stores.length,
      itemBuilder: (context, index) {
        final store = stores[index];
        return ListTile(
          title: Text(store.name),
          subtitle: Text('${store.city}, ${store.state}'),
        );
      },
    );
  }
}
