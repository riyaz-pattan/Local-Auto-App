import 'package:flutter/material.dart';
import 'utils/custom_toast.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/login_options_screen.dart';
import 'screens/custom_splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/pending_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/update_wrapper.dart';
import 'screens/broadcast_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const DriverApp());
}

class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Local Auto - Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B5E20),
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
      ),
      home: const UpdateWrapper(child: AuthGate()),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (snapshot.data == null) {
          return const LoginOptionsScreen();
        }
        return const BroadcastWrapper(appType: 'drivers', child: ProfileGate());
      },
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

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
      print('Error saving FCM token: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return StreamBuilder<DocumentSnapshot>(

      stream: FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _localDeviceId == null) {
          return const CustomSplashScreen(text: 'Loading...');
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const OnboardingScreen();
        }
        final data = snapshot.data!.data()! as Map<String, dynamic>;
        
        // Fix for "Flicker" & Routing bug: 
        // When initState writes deviceId/fcmToken, Firestore's optimistic cache immediately fires a snapshot
        // containing ONLY those fields. If we route based on that, existing users see "Under Review" for a split second,
        // and new users skip onboarding!
        if (!data.containsKey('name') || !data.containsKey('phone')) {
          if (snapshot.data!.metadata.isFromCache) {
            // It's a partial local cache document. Wait for the real server data.
            return const CustomSplashScreen(text: 'Loading profile...');
          }
          // The server confirmed they actually don't have a profile yet. Route to onboarding.
          return const OnboardingScreen();
        }
        
        // Single Device Login Enforcement
        final remoteDeviceId = data['deviceId'];
        if (remoteDeviceId != null && remoteDeviceId != _localDeviceId) {
          // Log out forcefully in the next frame
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser != null) {
              try {
                final uid = currentUser.uid;
                await FirebaseDatabase.instance.ref('liveLocations/$uid').remove();
                
                await FlutterForegroundTask.stopService();
              } catch (e) {
                // ignore errors if they happen during cleanup
              }
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                CustomToast.show(context, 'Logged out: You logged in on another device.');
              }
            }
          });
          return const CustomSplashScreen(text: 'Logging out...');
        }
        
        final status = data['status'] ?? 'pending';
        if (status == 'verified' || status == 'approved') {
          return const DashboardScreen();
        }
        if (status == 'rejected') {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cancel, size: 80, color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      'Profile Rejected',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      data['rejectionReason'] ?? 'Please contact support.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OnboardingScreen(
                              isResubmission: true,
                              rejectionReason: data['rejectionReason'],
                            ),
                          ),
                        );
                      },
                      child: const Text('Resubmit Profile'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (status == 'hold') {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.pause_circle,
                      size: 80,
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Profile On Hold',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your profile is currently on hold. Please contact admin.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        // Default: pending
        return const PendingScreen();
      },
    );
  }
}
