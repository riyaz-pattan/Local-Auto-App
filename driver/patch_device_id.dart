import 'dart:io';

void main() {
  String code = File('lib/main.dart').readAsStringSync();
  
  if (!code.contains("import 'package:shared_preferences/shared_preferences.dart';")) {
    code = code.replaceFirst(
      "import 'package:flutter/material.dart';",
      "import 'package:flutter/material.dart';\nimport 'package:shared_preferences/shared_preferences.dart';\nimport 'package:uuid/uuid.dart';"
    );
  }
  
  // Add Uuid import to pubspec if not exists
  String pubspec = File('pubspec.yaml').readAsStringSync();
  if (!pubspec.contains("uuid:")) {
    pubspec = pubspec.replaceFirst("dependencies:", "dependencies:\n  uuid: ^4.5.1");
    File('pubspec.yaml').writeAsStringSync(pubspec);
    Process.runSync('flutter', ['pub', 'get']);
  }

  String statefulProfileGate = '''
class _ProfileGateState extends State<ProfileGate> {
  String? _localDeviceId;

  @override
  void initState() {
    super.initState();
    _initDeviceIdAndFcm();
  }

  Future<void> _initDeviceIdAndFcm() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('device_id', deviceId);
    }
    
    if (mounted) {
      setState(() {
        _localDeviceId = deviceId;
      });
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('drivers').doc(uid).set({
        'deviceId': deviceId,
      }, SetOptions(merge: true));
    }

    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {
''';

  String oldStatefulProfileGate = '''class _ProfileGateState extends State<ProfileGate> {
  @override
  void initState() {
    super.initState();
    _saveFcmToken();
  }

  Future<void> _saveFcmToken() async {''';

  code = code.replaceFirst(oldStatefulProfileGate, statefulProfileGate);
  
  String oldStreamBuilder = '''      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OnboardingScreen();
        }
        final data = snapshot.data!.data()! as Map<String, dynamic>;
        final status = data['status'] ?? 'pending';''';
        
  String newStreamBuilder = '''      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _localDeviceId == null) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OnboardingScreen();
        }
        final data = snapshot.data!.data()! as Map<String, dynamic>;
        
        // Single Device Login Enforcement
        final remoteDeviceId = data['deviceId'];
        if (remoteDeviceId != null && remoteDeviceId != _localDeviceId) {
          // Log out forcefully in the next frame
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (FirebaseAuth.instance.currentUser != null) {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('You have been logged out because you logged in on another device.'),
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          });
          return const CustomSplashScreen(text: 'Logging out...');
        }
        
        final status = data['status'] ?? 'pending';''';

  code = code.replaceFirst(oldStreamBuilder, newStreamBuilder);

  File('lib/main.dart').writeAsStringSync(code);
  print('deviceId enforcement patched');
}
