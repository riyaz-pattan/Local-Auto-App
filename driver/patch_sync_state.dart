import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldLoad = '''  Future<void> _loadDriverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _driverName = doc.data()?['name'] ?? 'Driver';
      });
    }
  }''';

  String newLoad = '''  Future<void> _loadDriverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _driverName = doc.data()?['name'] ?? 'Driver';
        _isOnline = doc.data()?['isOnline'] ?? false;
      });
      if (_isOnline) {
        _triggerOnlineAnimation();
        // Check if service is actually running, if not, restart it
        FlutterForegroundTask.isRunningService.then((isRunning) {
          if (!isRunning) {
            _goOnline(isResuming: true);
          }
        });
      } else {
        _triggerOfflineAnimation();
      }
    }
  }''';

  code = code.replaceFirst(oldLoad, newLoad);
  
  // Need to handle isResuming in _goOnline
  String oldGoOnline = 'Future<void> _goOnline() async {';
  String newGoOnline = 'Future<void> _goOnline({bool isResuming = false}) async {';
  code = code.replaceFirst(oldGoOnline, newGoOnline);
  
  // Skip requesting permissions if just resuming to avoid popups if they already denied
  String oldReq = '    await _requestForegroundPermissions();';
  String newReq = '    if (!isResuming) await _requestForegroundPermissions();';
  code = code.replaceFirst(oldReq, newReq);
  
  // Skip modifying firestore if just resuming
  String oldUpdate = '''    await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
      'isOnline': true,
    });''';
  String newUpdate = '''    if (!isResuming) {
      await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
        'isOnline': true,
      });
    }''';
  code = code.replaceFirst(oldUpdate, newUpdate);

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Sync state patched');
}
