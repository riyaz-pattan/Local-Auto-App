import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  // 1. Add import
  if (!code.contains("import 'package:location/location.dart'")) {
    code = code.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:location/location.dart' as loc;"
    );
  }

  // 2. Fix the serviceEnabled check
  String oldCheck = '''    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Please enable location services');
    }''';

  String newCheck = '''    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final locationPkg = loc.Location();
      serviceEnabled = await locationPkg.requestService();
      if (!serviceEnabled) {
        throw Exception('Please enable location services');
      }
    }''';

  // 3. Remove onDisconnect().remove() to keep driver online when app is closed
  String oldDisconnect = "    await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove();";
  
  if (code.contains(oldCheck)) {
    code = code.replaceFirst(oldCheck, newCheck);
    if (code.contains(oldDisconnect)) {
        code = code.replaceFirst(oldDisconnect, "    // await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove(); // Removed to keep driver online when app is closed");
    }
    File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
    print('Patched successfully');
  } else {
    print('Failed to find oldCheck block');
  }
}
