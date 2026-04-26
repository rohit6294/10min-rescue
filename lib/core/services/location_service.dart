import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/firestore_paths.dart';
import 'dart:async';
import 'dart:math' as math;

class LocationService {
  StreamSubscription<Position>? _positionStream;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<bool> requestPermissions() async {
    final location = await Permission.location.request();
    if (!location.isGranted) return false;

    // Request background location (needed for tracking while app is in background)
    final background = await Permission.locationAlways.request();
    return background.isGranted || location.isGranted;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (_) {
      return null;
    }
  }

  void startTracking({
    required String driverId,
    required String requestId,
    required void Function(Position) onPosition,
  }) {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((position) {
      onPosition(position);
      _updateLocationInFirestore(driverId, position, requestId);
    });
  }

  void stopTracking() {
    _positionStream?.cancel();
    _positionStream = null;
  }

  Future<void> _updateLocationInFirestore(
    String driverId,
    Position position,
    String requestId,
  ) async {
    try {
      await _db.doc(FirestorePaths.locationUpdate(driverId)).set({
        'driverId': driverId,
        'location': GeoPoint(position.latitude, position.longitude),
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': FieldValue.serverTimestamp(),
        'requestId': requestId,
      });
      // Also update driver's own document for geo-queries
      await _db.doc(FirestorePaths.driver(driverId)).update({
        'location': GeoPoint(position.latitude, position.longitude),
        'geohash': encodeGeohash(position.latitude, position.longitude),
        'lastLocationUpdate': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Simple geohash encoding (precision 6 = ~1.2km accuracy)
  static String encodeGeohash(double lat, double lng, {int precision = 6}) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    var minLat = -90.0, maxLat = 90.0;
    var minLng = -180.0, maxLng = 180.0;
    final result = StringBuffer();
    var bits = 0, hashValue = 0;
    var isEven = true;

    while (result.length < precision) {
      if (isEven) {
        final mid = (minLng + maxLng) / 2;
        if (lng >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLng = mid;
        } else {
          hashValue = hashValue << 1;
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (lat >= mid) {
          hashValue = (hashValue << 1) + 1;
          minLat = mid;
        } else {
          hashValue = hashValue << 1;
          maxLat = mid;
        }
      }
      isEven = !isEven;
      bits++;
      if (bits == 5) {
        result.write(base32[hashValue]);
        bits = 0;
        hashValue = 0;
      }
    }
    return result.toString();
  }

  // Haversine distance in km
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
