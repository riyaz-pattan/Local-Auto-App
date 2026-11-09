import 'dart:io';

void main() {
  String code = File('lib/services/foreground_service_handler.dart').readAsStringSync();
  
  // Add geohash import
  if (!code.contains("import 'package:geohash_plus/geohash_plus.dart';")) {
    code = code.replaceFirst(
      "import 'package:geolocator/geolocator.dart';",
      "import 'package:geolocator/geolocator.dart';\nimport 'package:geohash_plus/geohash_plus.dart';"
    );
  }

  // Update the location stream logic
  String oldSet = '''        FirebaseDatabase.instance.ref('liveLocations/\$_uid').set({
          'latitude': position.latitude,
          'longitude': position.longitude,
          'heading': position.heading,
          'timestamp': ServerValue.timestamp,
        });''';

  String newSet = '''        final String geoHash = GeoHash.encode(position.latitude, position.longitude, precision: 7).hash;
        FirebaseDatabase.instance.ref('liveLocations/\$_uid').set({
          'lat': position.latitude,
          'lng': position.longitude,
          'geohash': geoHash,
          'timestamp': ServerValue.timestamp,
        });''';

  code = code.replaceFirst(oldSet, newSet);

  File('lib/services/foreground_service_handler.dart').writeAsStringSync(code);
  print('Handler patched');
}
