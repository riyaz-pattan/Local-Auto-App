import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  if (!code.contains("import 'package:firebase_messaging/firebase_messaging.dart';")) {
    code = code.replaceFirst(
      "import 'package:flutter_foreground_task/flutter_foreground_task.dart';",
      "import 'package:flutter_foreground_task/flutter_foreground_task.dart';\nimport 'package:firebase_messaging/firebase_messaging.dart';"
    );
  }

  String statefulProfileGate = '''
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  @override
  void initState() {
    super.initState();
    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        String? token = await messaging.getToken();
        if (token != null) {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
              'fcmToken': token,
            }, SetOptions(merge: true));
          }
        }
        
        messaging.onTokenRefresh.listen((newToken) async {
          final uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid != null) {
            await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
              'fcmToken': newToken,
            }, SetOptions(merge: true));
          }
        });
      }
    } catch (e) {
      print('Error saving FCM token: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(
''';

  String oldProfileGate = '''class ProfileGate extends StatelessWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(''';

  code = code.replaceFirst(oldProfileGate, statefulProfileGate);

  File('lib/main.dart').writeAsStringSync(code);
  print('main.dart updated with FCM logic');
}
