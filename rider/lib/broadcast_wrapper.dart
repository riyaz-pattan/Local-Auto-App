import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BroadcastWrapper extends StatefulWidget {
  final Widget child;
  final String appType; // 'drivers' or 'riders'

  const BroadcastWrapper({super.key, required this.child, required this.appType});

  @override
  State<BroadcastWrapper> createState() => _BroadcastWrapperState();
}

class _BroadcastWrapperState extends State<BroadcastWrapper> {
  SharedPreferences? _prefs;
  List<String> _dismissedIds = [];
  bool _isShowing = false;
  String? _currentlyProcessingId;

  @override
  void initState() {
    super.initState();
    _initPrefs();
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _dismissedIds = _prefs?.getStringList('dismissed_broadcasts') ?? [];
    });
  }

  void _markAsDismissed(String id) {
    if (_prefs == null) return;
    _dismissedIds.add(id);
    _prefs!.setStringList('dismissed_broadcasts', _dismissedIds);
  }

  Future<void> _downloadAndShowBroadcast(String id, String imageUrl) async {
    if (_isShowing || _currentlyProcessingId == id) return;
    _currentlyProcessingId = id;

    try {
      final imageProvider = NetworkImage(imageUrl);
      final stream = imageProvider.resolve(createLocalImageConfiguration(context));
      
      final completer = Completer<void>();
      late ImageStreamListener listener;
      
      listener = ImageStreamListener(
        (ImageInfo info, bool syncCall) {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (dynamic exception, StackTrace? stackTrace) {
          if (!completer.isCompleted) completer.completeError(exception);
        },
      );
      
      stream.addListener(listener);
      await completer.future;
      stream.removeListener(listener);

      if (mounted && !_dismissedIds.contains(id) && !_isShowing) {
        _showBroadcastDialog(id, imageProvider);
      }
    } catch (e) {
      debugPrint('Failed to preload broadcast image: $e');
    } finally {
      _currentlyProcessingId = null;
    }
  }

  void _showBroadcastDialog(String id, ImageProvider imageProvider) {
    if (_isShowing) return;
    _isShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain, 
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.black54,
                  radius: 18,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    onPressed: () {
                      _markAsDismissed(id);
                      Navigator.of(context).pop();
                      _isShowing = false;
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          widget.child,
          if (_prefs != null)
            StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('broadcasts').onValue,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  final broadcastsMap = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
                  
                  for (var entry in broadcastsMap.entries) {
                    final data = Map<String, dynamic>.from(entry.value as Map);
                    final id = entry.key.toString();
                    final isActive = data['isActive'] ?? false;
                    final target = data['target'] as String? ?? '';
                    
                    if (isActive && (target == 'both' || target == widget.appType)) {
                      if (!_dismissedIds.contains(id)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _downloadAndShowBroadcast(id, data['imageUrl'] ?? '');
                        });
                        break; 
                      }
                    }
                  }
                }
                return const SizedBox.shrink();
              },
            ),
        ],
      ),
    );
  }
}
