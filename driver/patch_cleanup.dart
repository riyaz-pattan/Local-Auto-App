import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  String oldSignOut = '''          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {''';
              
  String newSignOut = '''          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              try {
                final uid = currentUser.uid;
                await FirebaseDatabase.instance.ref('liveLocations/\$uid').remove();
                await FirebaseFirestore.instance.collection('drivers').doc(uid).update({'isOnline': false});
                await FlutterForegroundTask.stopService();
              } catch (e) {
                // ignore errors if they happen during cleanup
              }
              await FirebaseAuth.instance.signOut();
              if (mounted) {''';

  code = code.replaceFirst(oldSignOut, newSignOut);

  // Add FirebaseDatabase import if needed
  if (!code.contains("import 'package:firebase_database/firebase_database.dart';")) {
    code = code.replaceFirst(
      "import 'package:cloud_firestore/cloud_firestore.dart';",
      "import 'package:cloud_firestore/cloud_firestore.dart';\nimport 'package:firebase_database/firebase_database.dart';"
    );
  }

  File('lib/main.dart').writeAsStringSync(code);
  print('Cleanup before signOut patched');
}
