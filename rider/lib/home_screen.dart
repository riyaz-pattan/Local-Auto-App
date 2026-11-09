import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/custom_toast.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geohash_plus/geohash_plus.dart' hide LatLng;
import 'package:firebase_database/firebase_database.dart' as firebase_database;
import 'screens/custom_splash_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  CameraPosition? _initialCameraPosition;
  Set<Marker> _markers = {};
  BitmapDescriptor? _autoIcon;
  StreamSubscription<DatabaseEvent>? _locationSubscription;
  final DatabaseReference _liveLocationsRef = FirebaseDatabase.instance.ref().child('liveLocations');
  
  DateTime? _lastPressedAt;
  
  String? _selectedDriverId;
  LatLng? _selectedDriverLatLng;
  Future<DocumentSnapshot>? _driverFuture;
  ScreenCoordinate? _infoWindowScreenCoordinate;
  
  // Radius Filtering
  double _searchRadius = 1.0; // Active search radius
  double _tempSearchRadius = 1.0; // Temporary radius while adjusting the slider
  bool _showSlider = false;
  bool _isSearching = false;
  
  Position? _userPosition;
  Map<dynamic, dynamic> _allLiveDrivers = {};
  Map<String, Map<dynamic, dynamic>> _driversByHashChunk = {};

  final String _mapStyle = '''
  [
    {
      "featureType": "poi",
      "elementType": "labels.text",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "poi.business",
      "stylers": [{"visibility": "off"}]
    },
    {
      "featureType": "transit",
      "elementType": "labels.icon",
      "stylers": [{"visibility": "off"}]
    }
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
    _getUserLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCustomMarker() async {
    try {
      _autoIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(64, 64)),
        'assets/images/map_icons/auto.png',
      );
    } catch (e) {
      debugPrint("Error loading custom marker: $e");
    }
  }

  Future<void> _getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();
    
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever || !serviceEnabled) {
      if (mounted) {
        setState(() {
          _initialCameraPosition = const CameraPosition(
            target: LatLng(20.5937, 78.9629),
            zoom: 5,
          );
        });
      }
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    if (mounted) {
      setState(() {
        _userPosition = position;
        _initialCameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 15,
        );
      });
    }
    
    // Now that we have the position, fetch nearby drivers natively
    _listenToDrivers();

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(_initialCameraPosition!));
  }

  final List<StreamSubscription<firebase_database.DatabaseEvent>> _geoSubscriptions = [];

  void _listenToDrivers() {
    for (var sub in _geoSubscriptions) {
      sub.cancel();
    }
    _geoSubscriptions.clear();
    
    if (_userPosition == null) return;

    // Dynamically adjust geohash precision based on the slider radius.
    // Max radius is 5.0km. 
    // Precision 6 (9 boxes = ~3.6km x 1.8km) -> Good for < 1.5km
    // Precision 5 (9 boxes = ~14.7km x 14.7km) -> Good for up to 7km
    int precision = _searchRadius <= 1.5 ? 6 : 5;

    final mainHash = GeoHash.encode(_userPosition!.latitude, _userPosition!.longitude, precision: precision);
    final List<String> targetHashes = [
      mainHash.hash,
      mainHash.adjacent(Direction.north).hash,
      mainHash.adjacent(Direction.northEast).hash,
      mainHash.adjacent(Direction.east).hash,
      mainHash.adjacent(Direction.southEast).hash,
      mainHash.adjacent(Direction.south).hash,
      mainHash.adjacent(Direction.southWest).hash,
      mainHash.adjacent(Direction.west).hash,
      mainHash.adjacent(Direction.northWest).hash,
    ];

    if (mounted) {
      setState(() {
        _allLiveDrivers.clear();
        _driversByHashChunk.clear();
      });
    }

    for (String hashPrefix in targetHashes) {
      firebase_database.Query query = _liveLocationsRef.orderByChild('geohash').startAt(hashPrefix).endAt('$hashPrefix\uf8ff');
      
      _geoSubscriptions.add(query.onValue.listen((event) {
        if (mounted) {
          setState(() {
            if (event.snapshot.value != null) {
              _driversByHashChunk[hashPrefix] = event.snapshot.value as Map<dynamic, dynamic>;
            } else {
              _driversByHashChunk[hashPrefix] = {};
            }

            _allLiveDrivers.clear();
            for (var chunk in _driversByHashChunk.values) {
              _allLiveDrivers.addAll(chunk);
            }
            _updateMarkers();
          });
        }
      }));
    }
  }
  
  void _updateMarkers() {
    Set<Marker> newMarkers = {};
    Map<String, int> overlapCount = {};
    
    bool selectedDriverStillVisible = false;

    _allLiveDrivers.forEach((driverId, locationData) {
      double? lat;
      double? lng;

      if (locationData is Map) {
        if (locationData.containsKey('lat') && locationData.containsKey('lng')) {
          lat = double.tryParse(locationData['lat'].toString());
          lng = double.tryParse(locationData['lng'].toString());
        }
      }

      if (lat != null && lng != null) {
        // Distance Filtering based on ACTIVE search radius
        if (_userPosition != null) {
          final distanceInMeters = Geolocator.distanceBetween(
            _userPosition!.latitude, 
            _userPosition!.longitude, 
            lat, 
            lng
          );
          
          if (distanceInMeters > _searchRadius * 1000) {
            return; // Skip this driver, they are outside the active radius
          }
        }

        // Check for overlapping coordinates (Spiderfy)
        final coordKey = "${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}";
        final count = overlapCount[coordKey] ?? 0;
        overlapCount[coordKey] = count + 1;
        
        if (count > 0) {
          final angle = count * 1.0;
          lat += 0.00015 * math.cos(angle);
          lng += 0.00015 * math.sin(angle);
        }

        final idStr = driverId.toString();
        final pos = LatLng(lat, lng);
        
        if (idStr == _selectedDriverId) {
          selectedDriverStillVisible = true;
          _selectedDriverLatLng = pos;
          _updateInfoWindowPosition(pos);
        }
        
        newMarkers.add(Marker(
          markerId: MarkerId(idStr),
          position: pos,
          icon: _autoIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          onTap: () async {
            setState(() {
              _selectedDriverId = idStr;
              _selectedDriverLatLng = pos;
              _driverFuture = FirebaseFirestore.instance.collection('drivers').doc(idStr).get();
              _showSlider = false; // close slider if marker clicked
            });
            
            final controller = await _controller.future;
            await controller.animateCamera(CameraUpdate.newLatLngZoom(pos, 19.5));
            _updateInfoWindowPosition(pos);
          },
        ));
      }
    });

    _markers = newMarkers;
    
    // Auto-close popup if driver moved out of radius or went offline
    if (_selectedDriverId != null && !selectedDriverStillVisible) {
      _selectedDriverId = null;
      _selectedDriverLatLng = null;
      _driverFuture = null;
      _infoWindowScreenCoordinate = null;
    }
  }

  Future<void> _updateInfoWindowPosition(LatLng position) async {
    try {
      final controller = await _controller.future;
      final ScreenCoordinate coord = await controller.getScreenCoordinate(position);
      
      if (mounted) {
        setState(() {
          _infoWindowScreenCoordinate = coord;
        });
      }
    } catch (e) {}
  }

  Future<void> _callDriver(String driverId, String phoneRaw) async {
    final riderId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown_rider';
    try {
      await FirebaseFirestore.instance.collection('callLogs').add({
        'driverId': driverId,
        'riderId': riderId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {}

    if (phoneRaw.isEmpty) return;

    final Uri callUri = Uri(scheme: 'tel', path: phoneRaw); 
    if (await canLaunchUrl(callUri)) {
      await launchUrl(callUri);
    }
  }

  void _openImageFullScreen(String? url) {
    if (url == null || url.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _zoom(bool zoomIn) async {
    final controller = await _controller.future;
    if (zoomIn) {
      controller.animateCamera(CameraUpdate.zoomIn());
    } else {
      controller.animateCamera(CameraUpdate.zoomOut());
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
      body: Stack(
        children: [
          _initialCameraPosition == null
              ? const CustomSplashScreen(text: 'Getting your location...')
              : GoogleMap(
                  initialCameraPosition: _initialCameraPosition!,
                  mapType: MapType.normal,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: false,
                  mapToolbarEnabled: false,
                  markers: _markers,
                  // Only draw radius circle if the slider menu is open
                  circles: (_userPosition == null || !_showSlider) ? {} : {
                    Circle(
                      circleId: const CircleId('search_radius'),
                      center: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                      radius: _tempSearchRadius * 1000,
                      fillColor: Colors.blueAccent.withOpacity(0.15),
                      strokeColor: Colors.blueAccent,
                      strokeWidth: 2,
                    )
                  },
                  onCameraMove: (CameraPosition position) {
                    if (_selectedDriverLatLng != null) {
                      _updateInfoWindowPosition(_selectedDriverLatLng!);
                    }
                  },
                  onMapCreated: (GoogleMapController controller) {
                    controller.setMapStyle(_mapStyle);
                    _controller.complete(controller);
                  },
                  onTap: (latLng) {
                    setState(() {
                      _selectedDriverId = null;
                      _selectedDriverLatLng = null;
                      _driverFuture = null;
                      _infoWindowScreenCoordinate = null;
                      _showSlider = false; // close slider on map tap
                    });
                  },
                ),
                
          // Top Loading Progress Bar
          if (_isSearching)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
              ),
            ),
                
          // Right-side Controls
          Positioned(
            right: 16,
            bottom: _showSlider ? 220 : 32, // Move up if slider is shown
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Filter / Slider Toggle Button
                  FloatingActionButton(
                    heroTag: 'filterBtn',
                    backgroundColor: _showSlider ? Colors.blueAccent : Colors.white,
                    mini: true,
                    onPressed: () async {
                      setState(() {
                        if (!_showSlider) {
                          _tempSearchRadius = _searchRadius;
                        }
                        _showSlider = !_showSlider;
                      });
                      
                      if (_showSlider && _userPosition != null) {
                        final controller = await _controller.future;
                        controller.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(_userPosition!.latitude, _userPosition!.longitude), 13.5, 
                        ));
                      }
                    },
                    child: Icon(Icons.radar, color: _showSlider ? Colors.white : Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  
                  // Zoom Controls
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
                    ),
                    child: Column(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.black87),
                          onPressed: () => _zoom(true),
                        ),
                        Container(height: 1, width: 32, color: Colors.grey[200]),
                        IconButton(
                          icon: const Icon(Icons.remove, color: Colors.black87),
                          onPressed: () => _zoom(false),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // My Location
                  FloatingActionButton(
                    heroTag: 'myLocationBtn',
                    backgroundColor: Colors.white,
                    onPressed: () async {
                      final controller = await _controller.future;
                      try {
                        Position position = await Geolocator.getCurrentPosition(
                          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                        );
                        setState(() {
                          _userPosition = position;
                          _updateMarkers();
                        });
                        _listenToDrivers(); // Fetch new local drivers
                        controller.animateCamera(CameraUpdate.newLatLngZoom(
                          LatLng(position.latitude, position.longitude), 16,
                        ));
                      } catch(e) {}
                    },
                    child: const Icon(Icons.my_location, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ),
          
          // Custom Creative Info Window
          if (_selectedDriverId != null && _infoWindowScreenCoordinate != null)
            Builder(
              builder: (context) {
                final dpr = Platform.isAndroid ? MediaQuery.of(context).devicePixelRatio : 1.0;
                // Width = 260, so half width is 130 for centering.
                // Box height is ~148. Gap = 1px. Marker is ~60px tall. Total offset ~210.
                final double leftPos = (_infoWindowScreenCoordinate!.x / dpr) - 130;
                final double topPos = (_infoWindowScreenCoordinate!.y / dpr) - 210;

                return Positioned(
                  left: leftPos, 
                  top: topPos,  
              child: FutureBuilder<DocumentSnapshot>(
                future: _driverFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(width: 260, height: 170); // placeholder
                  }

                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox();
                  }

                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final name = data['name'] ?? 'Driver';
                  final vehicleNumber = data['vehicleNumber'] ?? '';
                  final phoneRaw = data['phone'] ?? '';
                  final profileUrl = data['profilePhotoUrl'] as String?;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The Info Card
                      Container(
                        width: 260,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _openImageFullScreen(profileUrl),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2), width: 2),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: Colors.grey[100],
                                      backgroundImage: profileUrl != null ? NetworkImage(profileUrl) : null,
                                      child: profileUrl == null ? const Icon(Icons.person, color: Colors.grey) : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (vehicleNumber.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            vehicleNumber,
                                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueGrey),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 44,
                              child: FilledButton.icon(
                                onPressed: () => _callDriver(_selectedDriverId!, phoneRaw),
                                icon: const Icon(Icons.phone, size: 18),
                                label: Text('Call Driver', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.black87,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Custom Triangle Pointer pointing down to the vehicle
                      CustomPaint(
                        size: const Size(20, 12),
                        painter: TrianglePainter(color: Colors.white),
                      ),
                    ],
                  );
                },
              ),
            );
           },
          ),
            
          // Bottom Slider Overlay
          if (_showSlider)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Search Radius', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_tempSearchRadius.toStringAsFixed(1)} km',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: Colors.blueAccent,
                        inactiveTrackColor: Colors.blueAccent.withOpacity(0.2),
                        thumbColor: Colors.blueAccent,
                        overlayColor: Colors.blueAccent.withOpacity(0.1),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _tempSearchRadius,
                        min: 0.5,
                        max: 5.0,
                        divisions: 45,
                        onChanged: (value) {
                          setState(() {
                            _tempSearchRadius = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () async {
                          setState(() {
                            _searchRadius = _tempSearchRadius;
                            _showSlider = false;
                            _isSearching = true;
                          });
                          _listenToDrivers();
                          // Simulating network delay for professional UX feel
                          await Future.delayed(const Duration(milliseconds: 1500));
                          if (mounted) {
                            setState(() {
                              _isSearching = false;
                            });
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black87,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          'Search Nearby Drivers',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
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

class TrianglePainter extends CustomPainter {
  final Color color;

  TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color..style = PaintingStyle.fill;
    
    // Add shadow
    Path shadowPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
      
    canvas.drawShadow(shadowPath, Colors.black, 4, false);

    Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
