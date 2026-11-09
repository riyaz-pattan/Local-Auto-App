import 'dart:io';

void main() {
  String code = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  // 1. Remove notificationButtons from startService
  String startServiceCode = '''    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'You are visible to nearby riders.',
      notificationIcon: null,
      notificationButtons: [
        const NotificationButton(id: 'go_offline', text: 'GO OFFLINE'),
      ],
      notificationInitialRoute: '/',
      callback: startCallback,
    );''';
    
  String newStartServiceCode = '''    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'Tracking location in background to receive rides.',
      notificationIcon: null,
      notificationInitialRoute: '/',
      callback: startCallback,
    );''';
    
  code = code.replaceFirst(startServiceCode, newStartServiceCode);

  // 2. Add Prominent Disclosure to _goOnline
  String oldGoOnline = '''  Future<void> _goOnline({bool isResuming = false}) async {
    if (!isResuming) await _requestForegroundPermissions();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();''';
      
  String newGoOnline = '''  Future<void> _goOnline({bool isResuming = false}) async {
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
      permission = await Geolocator.requestPermission();''';
      
  code = code.replaceFirst(oldGoOnline, newGoOnline);

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(code);
  print('Patched disclosure and removed buttons');
}
