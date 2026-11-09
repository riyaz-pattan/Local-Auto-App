import 'dart:io';

void main() {
  String code = File('lib/home_screen.dart').readAsStringSync();
  
  String oldListen = '''  void _listenToDrivers() {
    for (var sub in _geoSubscriptions) {
      sub.cancel();
    }
    _geoSubscriptions.clear();
    
    if (_userPosition == null) return;

    // Precision 6 is roughly 1.2km x 0.6km. 
    // We query the center + 8 neighbors to perfectly cover a strict 1-3km radius server-side.
    final mainHash = GeoHash.encode(_userPosition!.latitude, _userPosition!.longitude, precision: 6);''';

  String newListen = '''  void _listenToDrivers() {
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

    final mainHash = GeoHash.encode(_userPosition!.latitude, _userPosition!.longitude, precision: precision);''';

  if (code.contains(oldListen)) {
    code = code.replaceAll(oldListen, newListen);
    File('lib/home_screen.dart').writeAsStringSync(code);
    print('Patched _listenToDrivers precision');
  } else {
    print('Could not find old listenToDrivers block');
  }
}
