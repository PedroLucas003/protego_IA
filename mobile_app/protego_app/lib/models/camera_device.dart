class CameraDevice {
  final int id;
  final String deviceId;
  final String status;
  final DateTime? ultimoHeartbeat;
  final bool online;

  CameraDevice({
    required this.id,
    required this.deviceId,
    required this.status,
    this.ultimoHeartbeat,
    required this.online,
  });

  factory CameraDevice.fromJson(
    Map<String, dynamic> json, {
    DateTime? ultimoHeartbeat,
    bool online = false,
  }) {
    return CameraDevice(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      ultimoHeartbeat: ultimoHeartbeat,
      online: online,
    );
  }
}

class HeartbeatEntry {
  final int id;
  final String deviceId;
  final String timestamp;
  final String status;

  HeartbeatEntry({
    required this.id,
    required this.deviceId,
    required this.timestamp,
    required this.status,
  });

  factory HeartbeatEntry.fromJson(Map<String, dynamic> json) {
    return HeartbeatEntry(
      id: json['id'] as int,
      deviceId: json['device_id'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      status: json['status'] as String? ?? '',
    );
  }

  DateTime? get dateTime {
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }
}
