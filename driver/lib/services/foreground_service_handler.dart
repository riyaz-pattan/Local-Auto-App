import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geohash_plus/geohash_plus.dart';
import '../firebase_options.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(DriverTaskHandler());
}

class DriverTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _locationSubscription;
  String? _uid;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Already initialized
    }
    
    _uid = await FlutterForegroundTask.getData<String>(key: 'uid');
    
    if (_uid != null) {
      _startLocationUpdates();
    }
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 30,
      ),
    ).listen((Position position) {
      if (_uid != null) {
        final String geoHash = GeoHash.encode(position.latitude, position.longitude, precision: 7).hash;
        FirebaseDatabase.instance.ref('liveLocations/\$_uid').set({
          'lat': position.latitude,
          'lng': position.longitude,
          'geohash': geoHash,
          'timestamp': ServerValue.timestamp,
        });
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Keep alive heartbeat
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _locationSubscription?.cancel();
  }

  @override
  void onNotificationButtonPressed(String id) async {
    if (id == 'go_offline' && _uid != null) {
      try {
        await FirebaseDatabase.instance.ref('liveLocations/\$_uid').remove();

      } catch (e) {
        // print('Error going offline from notification: \$e');
      }
      FlutterForegroundTask.stopService();
    }
  }
  
  @override
  void onNotificationPressed() {
    // Use notificationInitialRoute instead
  }
}
