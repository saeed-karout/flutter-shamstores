import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/constants.dart';

class LocationService extends ChangeNotifier {
  Position? _currentPosition;
  bool _isTracking = false;
  bool _hasPermission = false;
  StreamSubscription<Position>? _positionStream;
  Timer? _uploadTimer;

  Position? get currentPosition => _currentPosition;
  bool get isTracking => _isTracking;
  bool get hasPermission => _hasPermission;

  late final Dio _dio;
  String? _authHeader;

  LocationService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: AppConfig.connectTimeout,
    ));
    _checkPermission();
  }

  void setAuthHeader(String authHeader) {
    _authHeader = authHeader;
    _dio.options.headers['Authorization'] = authHeader;
  }

  Future<bool> _checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _hasPermission = false;
      notifyListeners();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _hasPermission = false;
        notifyListeners();
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _hasPermission = false;
      notifyListeners();
      return false;
    }

    _hasPermission = true;
    notifyListeners();
    return true;
  }

  Future<void> startTracking() async {
    final hasPermission = await _checkPermission();
    if (!hasPermission) {
      debugPrint('Location permission not granted');
      return;
    }

    if (_isTracking) return;
    _isTracking = true;
    notifyListeners();

    // Get initial position
    try {
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      notifyListeners();
      await _uploadLocation();
    } catch (e) {
      debugPrint('Error getting initial position: $e');
    }

    // Start position stream
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      _currentPosition = position;
      notifyListeners();
    });

    // Upload location every 15 seconds
    _uploadTimer = Timer.periodic(
      Duration(seconds: AppConfig.locationUpdateInterval),
      (_) => _uploadLocation(),
    );
  }

  Future<void> stopTracking() async {
    _isTracking = false;
    await _positionStream?.cancel();
    _uploadTimer?.cancel();
    _positionStream = null;
    _uploadTimer = null;
    notifyListeners();
  }

  Future<void> _uploadLocation() async {
    if (_currentPosition == null || _authHeader == null) return;
    try {
      await _dio.patch('/delivery/driver/location', data: {
        'lat': _currentPosition!.latitude,
        'lng': _currentPosition!.longitude,
        'accuracy': _currentPosition!.accuracy,
        'speed': _currentPosition!.speed,
        'heading': _currentPosition!.heading,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Location upload error: $e');
    }
  }

  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkPermission();
      if (!hasPermission) return null;

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      notifyListeners();
      return _currentPosition;
    } catch (e) {
      debugPrint('getCurrentPosition error: $e');
      return null;
    }
  }

  double? distanceTo(double lat, double lng) {
    if (_currentPosition == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      lat,
      lng,
    );
  }

  String? formattedDistanceTo(double lat, double lng) {
    final dist = distanceTo(lat, lng);
    if (dist == null) return null;
    if (dist < 1000) return '${dist.toStringAsFixed(0)} م';
    return '${(dist / 1000).toStringAsFixed(1)} كم';
  }

  @override
  void dispose() {
    stopTracking();
    super.dispose();
  }
}
