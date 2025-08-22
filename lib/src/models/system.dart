// system.dart
class SystemHealth {
  final String status;
  final DateTime time;

  SystemHealth({
    required this.status,
    required this.time,
  });

  factory SystemHealth.fromJson(Map<String, dynamic> json) {
    return SystemHealth(
      status: json['status'] ?? 'unknown',
      time: DateTime.parse(json['time'] ?? DateTime.now().toString()),
    );
  }
}