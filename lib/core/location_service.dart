import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'errors.dart';

/// The phone's current position. Every failure is a specific, explainable error.
class DeviceLocation {
  static Future<({double lat, double lng})> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) throw const AppException(AppErrorKind.locationOff);
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied) throw const AppException(AppErrorKind.locationDenied);
    if (perm == LocationPermission.deniedForever) throw const AppException(AppErrorKind.locationDeniedForever);
    try {
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 20));
      return (lat: p.latitude, lng: p.longitude);
    } on TimeoutException {
      throw const AppException(AppErrorKind.locationUnavailable);
    } on LocationServiceDisabledException {
      throw const AppException(AppErrorKind.locationOff);
    }
  }

  static Future<bool> openSettings() => Geolocator.openAppSettings();
}
