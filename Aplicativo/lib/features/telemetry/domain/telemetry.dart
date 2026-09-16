class Telemetry {
  const Telemetry({
    required this.deviceId,
    required this.weightGrams,
    required this.metalDetected,
    required this.presence,
    required this.fillLevel,
    required this.gate,
    required this.network,
    required this.rssi,
    required this.receivedAt,
  });

  final String deviceId;
  final double weightGrams;
  final bool metalDetected;
  final bool presence;
  final double fillLevel;
  final String gate;
  final String network;
  final int rssi;
  final DateTime receivedAt;

  factory Telemetry.fromJson(Map<String, dynamic> json) => Telemetry(
        deviceId: json['deviceId']?.toString() ?? 'desconhecido',
        weightGrams: (json['weightGrams'] as num?)?.toDouble() ?? 0,
        metalDetected: json['metalDetected'] == true,
        presence: json['presence'] == true,
        fillLevel: (json['fillLevel'] as num?)?.toDouble() ?? 0,
        gate: json['gate']?.toString() ?? 'unknown',
        network: json['network']?.toString() ?? 'unknown',
        rssi: (json['rssi'] as num?)?.toInt() ?? -999,
        receivedAt: DateTime.now(),
      );

  Map<String, Object?> toDb() => {
        'device_id': deviceId,
        'weight_grams': weightGrams,
        'metal_detected': metalDetected ? 1 : 0,
        'presence': presence ? 1 : 0,
        'fill_level': fillLevel,
        'gate_state': gate,
        'network': network,
        'rssi': rssi,
        'received_at': receivedAt.toIso8601String(),
      };
}
