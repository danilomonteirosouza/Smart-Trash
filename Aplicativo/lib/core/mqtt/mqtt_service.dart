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
  bool get isConnected =>
      _client?.connectionStatus?.state == MqttConnectionState.connected;

  Future<void> connect(MqttSettings settings, String password) async {
    await disconnect();

    if (settings.host.trim().isEmpty ||
        settings.username.trim().isEmpty ||
        password.isEmpty ||
        settings.subscribeTopic.trim().isEmpty ||
        settings.effectivePublishTopic.trim().isEmpty) {
      throw ArgumentError('Preencha host, usuário, senha e tópicos MQTT.');
    }
    if (settings.port < 1 || settings.port > 65535) {
      throw ArgumentError('A porta MQTT informada é inválida.');
    }

    // O rastreador utiliza TLS sobre TCP (porta 8883) e passa as credenciais
    // para connect(user, password). A porta 8884 usa WSS no caminho /mqtt.
    final configuredHost = settings.host.trim();
    final uri = Uri.tryParse(configuredHost.contains('://')
        ? configuredHost
        : 'mqtts://$configuredHost');
    if (uri == null || uri.host.isEmpty) {
      throw ArgumentError('Host HiveMQ inválido.');
    }
    final port = uri.hasPort ? uri.port : settings.port;
    final useWebSocket = port == 8884 ||
        uri.scheme == 'wss' || uri.scheme == 'ws';
    final server = useWebSocket
        ? 'wss://${uri.host}:$port${uri.path.isEmpty ? '/mqtt' : uri.path}'
        : uri.host;

    // ID MQTT curto e exclusivo (menos de 23 caracteres), para não colidir
    // com a conexão de outros dispositivos que usam as mesmas credenciais.
    final clientId = 'lx_${DateTime.now().microsecondsSinceEpoch}';
    final client = MqttServerClient.withPort(server, clientId, port);
    _client = client;
    _settings = settings;

    client.useWebSocket = useWebSocket;
    // mqtt_client usa a URL wss:// para TLS de WebSocket; secure=true é
    // reservado para o transporte TCP TLS.
    client.secure = !useWebSocket;
    if (!useWebSocket) {
      client.securityContext = SecurityContext.defaultContext;
    }
    client.keepAlivePeriod = 20;
    client.connectTimeoutPeriod = 10000;
    client.autoReconnect = true;
    client.resubscribeOnAutoReconnect = true;
    client.logging(on: false);

    client.onDisconnected = () {
      if (identical(_client, client)) _emitConnection(false);
    };
    client.onAutoReconnect = () {
      if (identical(_client, client)) _emitConnection(false);
    };
    client.onAutoReconnected = () {
      if (identical(_client, client)) _emitConnection(isConnected);
    };
    // Deixa o mqtt_client montar o CONNECT padrão (como no rastreador).
    // Antes havia Will QoS 1 sem Will Topic/Mensagem, o que pode gerar um
    // CONNECT inválido e fazer o broker encerrar sem enviar CONNACK.
    // A autenticação é enviada no client.connect(usuario, senha).

    try {
      // Mesmo padrão da implementação funcional no aplicativo rastreador.
      await client.connect(settings.username.trim(), password);
      if (client.connectionStatus?.state != MqttConnectionState.connected) {
        throw StateError('HiveMQ recusou a conexão: ${client.connectionStatus}');
      }

      _subscription = client.updates?.listen((batch) {
        if (!identical(_client, client) || _messages.isClosed) return;
        for (final item in batch) {
          final message = item.payload as MqttPublishMessage;
          final text = MqttPublishPayload.bytesToStringAsString(
            message.payload.message,
          );
          try {
            final decoded = jsonDecode(text);
            if (decoded is Map<String, dynamic>) {
              _messages.add(MqttEnvelope(item.topic, decoded));
            }
          } catch (_) {
            // Mensagens legadas/não JSON são ignoradas pelo domínio novo.
          }
        }
      });
      _subscribe(client, settings);
      _emitConnection(true);
    } catch (_) {
      // Evita um cliente parcialmente conectado e bloqueando novo login.
      await disconnect();
      rethrow;
    }
  }

  void _subscribe(MqttServerClient client, MqttSettings settings) {
    client.subscribe(settings.subscribeTopic, MqttQos.atLeastOnce);
    // Para instalações com tópicos distintos, mantém ACK/status irmãos.
    if (!settings.sameTopic) {
      final root = settings.subscribeTopic.contains('/')
          ? settings.subscribeTopic.substring(
              0, settings.subscribeTopic.lastIndexOf('/'))
          : settings.subscribeTopic;
      client.subscribe('$root/ack', MqttQos.atLeastOnce);
      client.subscribe('$root/status', MqttQos.atLeastOnce);
    }
  }

  void _emitConnection(bool connected) {
    if (!_connection.isClosed) _connection.add(connected);
  }

  Future<void> disconnect() async {
    final client = _client;
    _client = null;
    _settings = null;
    await _subscription?.cancel();
    _subscription = null;
    client?.disconnect();
    _emitConnection(false);
  }

  void publishJson(Map<String, dynamic> payload) {
    final client = _client;
    final settings = _settings;
    if (client == null || settings == null || !isConnected) {
      throw StateError('MQTT não conectado.');
    }
    final builder = MqttClientPayloadBuilder()..addString(jsonEncode(payload));
    client.publishMessage(
      settings.effectivePublishTopic,
      MqttQos.atLeastOnce,
      builder.payload!,
    );
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _connection.close();
  }
}
