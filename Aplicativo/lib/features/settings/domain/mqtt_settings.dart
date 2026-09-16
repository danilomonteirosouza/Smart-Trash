class MqttSettings {
  const MqttSettings({
    required this.host,
    required this.port,
    required this.username,
    required this.subscribeTopic,
    required this.publishTopic,
    required this.sameTopic,
    required this.deviceId,
  });

  final String host;
  final int port;
  final String username;
  final String subscribeTopic;
  final String publishTopic;
  final bool sameTopic;
  final String deviceId;

  String get effectivePublishTopic => sameTopic ? subscribeTopic : publishTopic;

  factory MqttSettings.defaults() => const MqttSettings(
        host: '',
        port: 8883,
        username: '',
        subscribeTopic: 'lixeira/telemetry',
        publishTopic: 'lixeira/command',
        sameTopic: false,
        deviceId: 'LIXEIRA-01',
      );

  MqttSettings copyWith({
    String? host,
    int? port,
    String? username,
    String? subscribeTopic,
    String? publishTopic,
    bool? sameTopic,
    String? deviceId,
  }) =>
      MqttSettings(
        host: host ?? this.host,
        port: port ?? this.port,
        username: username ?? this.username,
        subscribeTopic: subscribeTopic ?? this.subscribeTopic,
        publishTopic: publishTopic ?? this.publishTopic,
        sameTopic: sameTopic ?? this.sameTopic,
        deviceId: deviceId ?? this.deviceId,
      );
}
