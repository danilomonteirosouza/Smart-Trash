import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../../features/settings/domain/mqtt_settings.dart';

class MqttEnvelope {
  const MqttEnvelope(this.topic, this.data);
  final String topic;
  final Map<String, dynamic> data;
}

class MqttService {
  MqttServerClient? _client;
  StreamSubscription<List<MqttReceivedMessage<MqttMessage>>>? _subscription;
  final _messages = StreamController<MqttEnvelope>.broadcast();
  final _connection = StreamController<bool>.broadcast();
  MqttSettings? _settings;

  Stream<MqttEnvelope> get messages => _messages.stream;
  Stream<bool> get connectionChanges => _connection.stream;
  bool get isConnected => _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect(MqttSettings settings, String password) async {
    await disconnect();
    if (settings.host.trim().isEmpty || settings.username.trim().isEmpty || password.isEmpty) {
      throw ArgumentError('Preencha host, usuário e senha MQTT.');
    }
    _settings = settings;
    final clientId = 'lixeira_app_${DateTime.now().millisecondsSinceEpoch}';
    final client = MqttServerClient.withPort(settings.host.trim(), clientId, settings.port);
    _client = client;
    client.secure = true;
    client.securityContext = SecurityContext.defaultContext;
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 10000;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);
    client.onConnected = () => _connection.add(true);
    client.onDisconnected = () => _connection.add(false);
    client.onAutoReconnect = () => _connection.add(false);
    client.onAutoReconnected = () => _connection.add(true);
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .authenticateAs(settings.username.trim(), password)
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    try {
      await client.connect();
    } catch (_) {
      client.disconnect();
      rethrow;
    }
    if (client.connectionStatus?.state != MqttConnectionState.connected) {
      throw StateError('HiveMQ recusou a conexão: ${client.connectionStatus}');
    }
    client.subscribe(settings.subscribeTopic, MqttQos.atLeastOnce);
    // ACK/status podem estar em tópicos irmãos quando o padrão recomendado é usado.
    final root = settings.subscribeTopic.contains('/')
        ? settings.subscribeTopic.substring(0, settings.subscribeTopic.lastIndexOf('/'))
        : settings.subscribeTopic;
    if (!settings.sameTopic) {
      client.subscribe('$root/ack', MqttQos.atLeastOnce);
      client.subscribe('$root/status', MqttQos.atLeastOnce);
    }
    _subscription = client.updates?.listen((batch) {
      for (final item in batch) {
        final message = item.payload as MqttPublishMessage;
        final text = MqttPublishPayload.bytesToStringAsString(message.payload.message);
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) _messages.add(MqttEnvelope(item.topic, decoded));
        } catch (_) {
          // Mensagens legadas/não JSON são ignoradas pelo domínio novo.
        }
      }
    });
    _connection.add(true);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    _client?.disconnect();
    _client = null;
    _connection.add(false);
  }

  void publishJson(Map<String, dynamic> payload) {
    final client = _client;
    final settings = _settings;
    if (client == null || settings == null || !isConnected) throw StateError('MQTT não conectado.');
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    client.publishMessage(settings.effectivePublishTopic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _connection.close();
  }
}
