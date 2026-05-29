import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'dart:async';

class LocationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _updateTimer;

  /// Check and request location permissions
  Future<bool> checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current position once
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('LocationService.getCurrentPosition ERROR: $e');
      return null;
    }
  }

  /// Get address from coordinates
  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      print('LocationService.getAddressFromCoordinates ERROR: $e');
    }
    return 'Unknown location';
  }

  /// Start sharing location - updates Firestore every 10 seconds
  Future<void> startSharingLocation(String userId) async {
    try {
      final hasPermission = await checkPermissions();
      if (!hasPermission) {
        print('LocationService: No location permissions');
        return;
      }

      // Update immediately
      await _updateUserLocation(userId);

      // Then update every 10 seconds
      _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
        await _updateUserLocation(userId);
      });
    } catch (e) {
      print('LocationService.startSharingLocation ERROR: $e');
    }
  }

  /// Stop sharing location
  Future<void> stopSharingLocation(String userId) async {
    try {
      _updateTimer?.cancel();
      _updateTimer = null;

      await _firestore.collection('user_locations').doc(userId).update({
        'isSharing': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('LocationService.stopSharingLocation ERROR: $e');
    }
  }

  /// Update user location in Firestore
  Future<void> _updateUserLocation(String userId) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _firestore.collection('user_locations').doc(userId).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': FieldValue.serverTimestamp(),
        'isSharing': true,
      }, SetOptions(merge: true));

      print('Location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      print('LocationService._updateUserLocation ERROR: $e');
    }
  }

  /// Stream of friend locations (who are sharing)
  Stream<List<UserLocation>> watchFriendLocations(List<String> friendIds) {
    if (friendIds.isEmpty) {
      return Stream.value([]);
    }

    return _firestore
        .collection('user_locations')
        .where(FieldPath.documentId, whereIn: friendIds)
        .where('isSharing', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserLocation(
          userId: doc.id,
          lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
          lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isSharing: data['isSharing'] as bool? ?? false,
        );
      }).toList();
    });
  }

  /// Get single user location
  Future<UserLocation?> getUserLocation(String userId) async {
    try {
      final doc = await _firestore.collection('user_locations').doc(userId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      return UserLocation(
        userId: userId,
        lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
        lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
        timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        isSharing: data['isSharing'] as bool? ?? false,
      );
    } catch (e) {
      print('LocationService.getUserLocation ERROR: $e');
      return null;
    }
  }

  /// Cleanup
  void dispose() {
    _updateTimer?.cancel();
    _positionStreamSubscription?.cancel();
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// User Location Model
// ══════════════════════════════════════════════════════════════════════════════

class UserLocation {
  final String userId;
  final double lat;
  final double lng;
  final DateTime timestamp;
  final bool isSharing;

  UserLocation({
    required this.userId,
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.isSharing,
  });

  bool get isRecent {
    return DateTime.now().difference(timestamp).inMinutes < 5;
  }
}
