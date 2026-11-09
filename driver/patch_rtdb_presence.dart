import 'dart:io';

void main() {
  // 1. Patch dashboard_screen.dart
  String dashCode = File('lib/screens/dashboard_screen.dart').readAsStringSync();
  
  String oldLoadDriver = '''  Future<void> _loadDriverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .get();
    if (doc.exists && mounted) {
      setState(() {
        _driverName = doc.data()?['name'] ?? 'Driver';
        _isOnline = doc.data()?['isOnline'] ?? false;
      });''';
      
  String newLoadDriver = '''  Future<void> _loadDriverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .get();
    final rtdbSnap = await _rtdb.ref('liveLocations/\$_uid').get();
    if (doc.exists && mounted) {
      setState(() {
        _driverName = doc.data()?['name'] ?? 'Driver';
        _isOnline = rtdbSnap.exists;
      });''';
      
  dashCode = dashCode.replaceFirst(oldLoadDriver, newLoadDriver);
  
  // Remove Firestore writes
  String oldGoOnlineUpdate = '''      await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
        'isOnline': true,
      });''';
  dashCode = dashCode.replaceFirst(oldGoOnlineUpdate, "");
  
  String oldGoOfflineUpdate = '''    await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
      'isOnline': false,
    });''';
  dashCode = dashCode.replaceFirst(oldGoOfflineUpdate, "");

  File('lib/screens/dashboard_screen.dart').writeAsStringSync(dashCode);
  
  // 2. Patch main.dart
  String mainCode = File('lib/main.dart').readAsStringSync();
  mainCode = mainCode.replaceFirst(
    "await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'isOnline': false});", 
    ""
  );
  File('lib/main.dart').writeAsStringSync(mainCode);
  
  // 3. Patch foreground_service_handler.dart
  String handlerCode = File('lib/services/foreground_service_handler.dart').readAsStringSync();
  String oldHandlerUpdate = '''        await FirebaseFirestore.instance.collection('drivers').doc(_uid).update({
          'isOnline': false,
        });''';
  handlerCode = handlerCode.replaceFirst(oldHandlerUpdate, "");
  File('lib/services/foreground_service_handler.dart').writeAsStringSync(handlerCode);

  print('Patched all isOnline usages to use RTDB presence');
}
