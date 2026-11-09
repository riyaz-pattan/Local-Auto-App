import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldGoOnline = '''  Future<void> _goOnline({bool isResuming = false}) async {
    if (!isResuming) {
      // PROMINENT DISCLOSURE FOR GOOGLE PLAY POLICY
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Background Location Needed'),
          content: const Text(
            'Local Auto Driver collects location data to enable live vehicle tracking on the rider\\'s map so they can find and call you, even when the app is closed or not in use.\\n\\nThis ensures you never miss a ride while the "Online" status is active.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ACCEPT'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
      
      await _requestForegroundPermissions();
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable in settings.',
      );
    }''';

  String newGoOnline = '''  Future<void> _goOnline({bool isResuming = false}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied && !isResuming) {
      // PROMINENT DISCLOSURE FOR GOOGLE PLAY POLICY (Only show if permission not yet granted)
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Location Needed'),
          content: const Text(
            'Local Auto Driver collects location data to enable live vehicle tracking on the rider\\'s map so they can find and call you, even when the app is closed or not in use.\\n\\nThis ensures you never miss a ride while the "Online" status is active.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ACCEPT'),
            ),
          ],
        ),
      );

      if (shouldProceed != true) return;
    }
    
    if (!isResuming) {
      await _requestForegroundPermissions();
    }
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Please enable in settings.',
      );
    }''';

  code = code.replaceFirst(oldGoOnline, newGoOnline);
  
  // Re-add onDisconnect().remove()
  String oldRtdbRef = "// await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove(); // Removed to keep driver online when app is closed";
  String newRtdbRef = "await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove(); // Re-added since stopWithTask=false keeps process alive safely";
  
  if (code.contains(oldRtdbRef)) {
    code = code.replaceFirst(oldRtdbRef, newRtdbRef);
  } else {
    // If it doesn't contain the commented out version, let's insert it before startService
    if (!code.contains("onDisconnect().remove()")) {
      code = code.replaceFirst(
        "await FlutterForegroundTask.saveData(key: 'uid', value: _uid);", 
        "await _rtdb.ref('liveLocations/\$_uid').onDisconnect().remove();\n    await FlutterForegroundTask.saveData(key: 'uid', value: _uid);"
      );
    }
  }

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Patched goOnline dialog and onDisconnect');
}
