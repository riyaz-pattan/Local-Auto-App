import 'package:geohash_plus/geohash_plus.dart';

void main() {
  var h = GeoHash.encode(20.0, 78.0, precision: 6);
  print(h.adjacent(Direction.northEast).hash);
}
