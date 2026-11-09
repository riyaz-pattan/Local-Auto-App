import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/custom_splash_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class UpdateWrapper extends StatefulWidget {
  final Widget child;

  const UpdateWrapper({super.key, required this.child});

  @override
  State<UpdateWrapper> createState() => _UpdateWrapperState();
}

class _UpdateWrapperState extends State<UpdateWrapper> {
  bool _isLoading = true;
  bool _isForceUpdate = false;
  bool _isSoftUpdate = false;
  String _playStoreUrl = '';
  String _currentVersion = '0.0.0';
  StreamSubscription? _settingsSub;
  bool _softDialogShown = false;

  @override
  void initState() {
    super.initState();
    _initAndListen();
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    super.dispose();
  }

  Future<void> _initAndListen() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _currentVersion = packageInfo.version;
    } catch (e) {
      _currentVersion = '0.0.0';
    }

    _settingsSub = FirebaseDatabase.instance
        .ref('app_settings/rider_app')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final minVersion = data['minimum_version']?.toString() ?? '1.0.0';
        final latestVersion = data['latest_version']?.toString() ?? '1.0.0';
        _playStoreUrl = data['play_store_url']?.toString() ?? '';

        bool newForce = _isVersionLower(_currentVersion, minVersion);
        bool newSoft = _isVersionLower(_currentVersion, latestVersion);

        if (mounted) {
          setState(() {
            _isForceUpdate = newForce;
            _isSoftUpdate = newSoft;
            _isLoading = false;
          });

          if (_isSoftUpdate && !_isForceUpdate && !_softDialogShown) {
            _softDialogShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showSoftUpdateDialog();
            });
          }
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    }, onError: (e) {
      if (mounted) setState(() => _isLoading = false);
    });
  }

  bool _isVersionLower(String current, String target) {
    try {
      final v1 = current.split('.').map(int.parse).toList();
      final v2 = target.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        final c1 = i < v1.length ? v1[i] : 0;
        final c2 = i < v2.length ? v2[i] : 0;
        if (c1 < c2) return true;
        if (c1 > c2) return false;
      }
      return false; 
    } catch (e) {
      return false; 
    }
  }

  Future<void> _launchUrl() async {
    if (_playStoreUrl.isEmpty) return;
    final uri = Uri.parse(_playStoreUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSoftUpdateDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Update Available', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        content: Text(
          'A newer version of the app is available. Please update to get the latest features.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Later', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: Text('Update', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CustomSplashScreen(text: 'Checking for updates...');
    }

    if (_isForceUpdate) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.system_update, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                Text(
                  'Update Required',
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your version of the app is no longer supported. Please update to continue booking rides.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[700]),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _launchUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Update Now', style: GoogleFonts.inter(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}
