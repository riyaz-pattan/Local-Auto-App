import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldGoOffline = '''  Future<void> _goOffline() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    final ref = _rtdb.ref('liveLocations/\$_uid');
    await ref.onDisconnect().cancel();
    await ref.remove();

    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
        'isOnline': false,
      });
    } catch (_) {}
  }''';
  
  String newGoOffline = '''  Future<void> _goOffline() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    if (FirebaseAuth.instance.currentUser == null) {
      return; // Already signed out, no permission to update DB
    }

    try {
      final ref = _rtdb.ref('liveLocations/\$_uid');
      await ref.onDisconnect().cancel();
      await ref.remove();
    } catch (e) {
      print('RTDB offline error (ignored): \$e');
    }

    try {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
        'isOnline': false,
      });
    } catch (e) {
      print('Firestore offline error (ignored): \$e');
    }
  }''';
  
  if (code.contains(oldGoOffline)) {
    code = code.replaceFirst(oldGoOffline, newGoOffline);
    File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
    print('_goOffline patched');
  } else {
    print('Failed to patch _goOffline');
  }
}
