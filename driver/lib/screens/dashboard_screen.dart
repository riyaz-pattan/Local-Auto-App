import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/foreground_service_handler.dart';
import 'package:location/location.dart' as loc;
import 'package:flutter/services.dart';
import '../utils/custom_toast.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geohash_plus/geohash_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  bool _isOnline = false;
  bool _toggling = false;
  StreamSubscription<Position>? _locationSubscription;
  String _driverName = 'Driver';

  late AnimationController _pulseController;
  late AnimationController _offlineRotateController;
  DateTime? _lastPressedAt;

  final _uid = FirebaseAuth.instance.currentUser!.uid;
  final _rtdb = FirebaseDatabase.instance;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _offlineRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    // Play offline animation once on startup
    _triggerOfflineAnimation();
    _loadDriverName();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'driver_online_service_v4',
        channelName: 'Driver Online Service',
        channelDescription: 'Keeps the driver online and tracks location in the background.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.HIGH,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _requestForegroundPermissions() async {
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    NotificationPermission notificationPermissionStatus = await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
  }

  void _triggerOfflineAnimation() {
    _offlineRotateController.repeat();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && !_isOnline) _offlineRotateController.stop();
    });
  }

  void _triggerOnlineAnimation() {
    _pulseController.repeat();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted && _isOnline) _pulseController.stop();
    });
  }

  @override
  void dispose() {
    _goOffline();
    _pulseController.dispose();
    _offlineRotateController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverName() async {
    final doc = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .get();
    final rtdbSnap = await _rtdb.ref('liveLocations/$_uid').get();
    if (doc.exists && mounted) {
      setState(() {
        _driverName = doc.data()?['name'] ?? 'Driver';
        _isOnline = rtdbSnap.exists;
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
  }

  Future<void> _toggleOnline() async {
    if (_toggling) return;

    setState(() => _toggling = true);

    try {
      if (!_isOnline) {
        await _goOnline();
      } else {
        await _goOffline();
      }

      if (mounted) {
        setState(() {
          _isOnline = !_isOnline;
          if (_isOnline) {
            _triggerOnlineAnimation();
          } else {
            _pulseController.stop();
            _pulseController.reset();
            _triggerOfflineAnimation();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _goOnline({bool isResuming = false}) async {
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied && !isResuming) {
      // PROMINENT DISCLOSURE FOR GOOGLE PLAY POLICY (Only show if permission not yet granted)
      final shouldProceed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Location Needed'),
          content: const Text(
            'Local Auto Driver collects location data to enable live vehicle tracking on the rider\'s map so they can find and call you, even when the app is closed or not in use.\n\nThis ensures you never miss a ride while the "Online" status is active.',
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
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      final locationPkg = loc.Location();
      serviceEnabled = await locationPkg.requestService();
      if (!serviceEnabled) {
        throw Exception('Please enable location services');
      }
    }

    await _rtdb.ref('liveLocations/$_uid').onDisconnect().remove(); // Re-added since stopWithTask=false keeps process alive safely
    await FlutterForegroundTask.saveData(key: 'uid', value: _uid);
    final result = await FlutterForegroundTask.startService(
      notificationTitle: 'Local Auto: Online',
      notificationText: 'Tracking location in background to receive rides.',
      notificationIcon: const NotificationIcon(metaDataName: 'ic_notification'),
      notificationInitialRoute: '/',
      callback: startCallback,
    );
    if (result is ServiceRequestFailure) {
      print('Service Start Failure: ${result.error}');
    }

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 30, // Changed from 10 to 30 meters
          ),
        ).listen((position) {
          final String geoHash = GeoHash.encode(position.latitude, position.longitude, precision: 7).hash;
          _rtdb.ref('liveLocations/$_uid').set({
            'lat': position.latitude,
            'lng': position.longitude,
            'geohash': geoHash,
            'timestamp': ServerValue.timestamp,
          });
        });

    if (!isResuming) {

    }
  }

  Future<void> _goOffline() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    if (FirebaseAuth.instance.currentUser == null) {
      return; // Already signed out, no permission to update DB
    }

    try {
      await FlutterForegroundTask.stopService();
    final ref = _rtdb.ref('liveLocations/$_uid');
      await ref.onDisconnect().cancel();
      await ref.remove();
    } catch (e) {
      print('RTDB offline error (ignored): $e');
    }


  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirm Logout',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to logout from the application?',
            style: GoogleFonts.inter(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black87,
        builder: (_) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),
              Text(
                'Signing out securely...',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );

      try {
        await _goOffline();
        // Add a slight delay to ensure the animation looks smooth and deliberate
        await Future.delayed(const Duration(milliseconds: 800));
        await FirebaseAuth.instance.signOut();
      } finally {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
          _lastPressedAt = now;
          CustomToast.show(context, 'Press back again to exit', isError: false);
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: _isOnline ? Colors.white : Colors.white,
        ),
        actions: [
          IconButton(
            onPressed: _confirmLogout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background Transition
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _isOnline
                    ? [
                        const Color(0xFF0F172A),
                        const Color(0xFF020617),
                      ] // Deep radar dark
                    : [
                        const Color(0xFF1E293B),
                        const Color(0xFF0F172A),
                      ], // Standby sleek dark
              ),
            ),
          ),

          // Abstract Offline Pattern (Subtle)
          if (!_isOnline)
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: Image.network(
                  'https://www.transparenttextures.com/patterns/cubes.png',
                  repeat: ImageRepeat.repeat,
                ),
              ),
            ),

          SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 400),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    child: Text('Hello, $_driverName'),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 400),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.5,
                        color: Colors.white70,
                        letterSpacing: 0.5,
                      ),
                      child: Text(
                        _isOnline
                            ? 'You are visible on the map.\nNearby riders can now contact you directly.'
                            : 'Ready to hit the road?\nGo online to start receiving ride requests.',
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // The Interactive Toggle Area
                  GestureDetector(
                    onTap: _toggleOnline,
                    child: SizedBox(
                      width: 320,
                      height: 320,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Offline Rotating Ring Animation
                          if (!_isOnline)
                            AnimatedBuilder(
                              animation: _offlineRotateController,
                              builder: (context, child) {
                                return Transform.rotate(
                                  angle:
                                      _offlineRotateController.value *
                                      2 *
                                      math.pi,
                                  child: Container(
                                    width: 170,
                                    height: 170,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 2,
                                      ),
                                    ),
                                    child: CustomPaint(
                                      painter: DashedRingPainter(
                                        color: Colors.white.withOpacity(0.3),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Radar Pulse 1 (Online)
                          if (_isOnline)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: 1.0 + (_pulseController.value * 1.5),
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.blueAccent.withOpacity(
                                        (1.0 - _pulseController.value).clamp(
                                              0.0,
                                              1.0,
                                            ) *
                                            0.4,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Radar Pulse 2 (Online)
                          if (_isOnline)
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) {
                                final delayVal =
                                    (_pulseController.value + 0.5) % 1.0;
                                return Transform.scale(
                                  scale: 1.0 + (delayVal * 1.5),
                                  child: Container(
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.tealAccent.withOpacity(
                                        (1.0 - delayVal).clamp(0.0, 1.0) * 0.3,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                          // Central Button
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isOnline
                                  ? Colors.blueAccent
                                  : const Color(0xFF1E293B),
                              boxShadow: [
                                if (_isOnline)
                                  BoxShadow(
                                    color: Colors.blueAccent.withOpacity(0.6),
                                    blurRadius: 40,
                                    spreadRadius: 10,
                                  )
                                else
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                    offset: const Offset(0, 10),
                                  ),
                                if (!_isOnline)
                                  BoxShadow(
                                    color: Colors.white.withOpacity(0.05),
                                    blurRadius: 10,
                                    spreadRadius: -2,
                                    offset: const Offset(0, -5),
                                  ),
                              ],
                              border: Border.all(
                                color: _isOnline
                                    ? Colors.transparent
                                    : Colors.white.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: _toggling
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isOnline
                                              ? Icons.radar
                                              : Icons.power_settings_new,
                                          size: 48,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _isOnline ? 'ONLINE' : 'GO ONLINE',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Bottom status text
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 400),
                    opacity: _isOnline ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Location sharing active',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}

class DashedRingPainter extends CustomPainter {
  final Color color;

  DashedRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    double strokeWidth = 2;
    double radius = (size.width - strokeWidth) / 2;
    Offset center = Offset(size.width / 2, size.height / 2);

    Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double dashWidth = 8;
    double dashSpace = 8;
    double circumference = 2 * math.pi * radius;
    int dashCount = (circumference / (dashWidth + dashSpace)).floor();

    double adjustedDashSpace =
        (circumference - (dashCount * dashWidth)) / dashCount;

    for (int i = 0; i < dashCount; i++) {
      double startAngle = (i * (dashWidth + adjustedDashSpace)) / radius;
      double sweepAngle = dashWidth / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
