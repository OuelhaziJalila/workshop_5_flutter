import 'package:geolocator/geolocator.dart';
class GeolocationService {
  Future<Position?> getCurrentPosition() async {
    // 1. Check & request permission
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission != LocationPermission.whileInUse && permission != LocationPermission.always) {
      return null;
    }
    // 2. Ensure location services are enabled
    if (!(await Geolocator.isLocationServiceEnabled())) {
      return null;
    }
    // 3. Fetch position
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Geolocation error: $e');
      // 🆕 Return fake Tunis location for testing
      return Position(
        latitude: 36.8065,
        longitude: 10.1815,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }
  }
}