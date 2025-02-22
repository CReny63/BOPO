import 'dart:convert';
import 'package:http/http.dart' as http;

Future<String> fetchQrCode(String data) async {
  final url = Uri.parse('https://us-central1-bopo-f6eeb.cloudfunctions.net/generateQr?data=$data');
  final response = await http.get(url);
  if (response.statusCode == 200) {
    final jsonResponse = jsonDecode(response.body);
    return jsonResponse['qrCode'];  // This is the Base64 encoded QR code image
  } else {
    throw Exception('Failed to generate QR code');
  }
}
