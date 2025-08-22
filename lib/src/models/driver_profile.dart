// driver_profile.dart
class DriverProfile {
  final String id;
  final String user;
  final String? vehicle;
  final bool available;
  final double? currentLat;
  final double? currentLon;
  final DateTime? lastSeenAt;

  DriverProfile({
    required this.id,
    required this.user,
    this.vehicle,
    this.available = true,
    this.currentLat,
    this.currentLon,
    this.lastSeenAt,
  });

  factory DriverProfile.fromJson(Map<String, dynamic> json) {
    return DriverProfile(
      id: json['id'] ?? '',
      user: json['user'] ?? '',
      vehicle: json['vehicle'],
      available: json['available'] ?? true,
      currentLat: json['currentLat'] != null ? double.tryParse(json['currentLat']) : null,
      currentLon: json['currentLon'] != null ? double.tryParse(json['currentLon']) : null,
      lastSeenAt: json['lastSeenAt'] != null ? DateTime.parse(json['lastSeenAt']) : null,
    );
  }
}