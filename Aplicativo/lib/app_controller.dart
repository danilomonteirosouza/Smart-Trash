import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'core/database/app_database.dart';
import 'core/mqtt/mqtt_service.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/settings/domain/mqtt_settings.dart';
import 'features/telemetry/domain/telemetry.dart';
import 'features/actuator/domain/device_ack.dart';

class AppController extends ChangeNotifier {
  AppController({required this.database, required this.settingsRepository, required this.mqtt});
  final AppDatabase database;
  final SettingsRepository settingsRepository;
  final MqttService mqtt;
  final _uuid = const Uuid();

  MqttSettings settings = MqttSettings.defaults();
  String password = '';
  Telemetry? telemetry;
  DeviceAck? lastAck;
  bool mqttConnected = false;
  bool busy = false;
  String? error;
  StreamSubscription<MqttEnvelope>? _messageSub;
  StreamSubscription<bool>? _connectionSub;

  Future<void> initialize() async {
    final loaded = await settingsRepository.load();
    settings = loaded.$1;
    password = loaded.$2;
    _messageSub = mqtt.messages.listen(_onMessage);
    _connectionSub = mqtt.connectionChanges.listen((value) {
      mqttConnected = value;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> connect() async {
    busy = true; error = null; notifyListeners();
    try {
      await mqtt.connect(settings, password);
    } catch (e) {
      error = e.toString();
    } finally {
      busy = false; notifyListeners();
    }
  }

  Future<void> disconnect() async => mqtt.disconnect();

  Future<void> saveSettings(MqttSettings value, String newPassword) async {
    settings = value;
    password = newPassword;
    await settingsRepository.save(value, newPassword);
    notifyListeners();
  }

  Future<void> _onMessage(MqttEnvelope envelope) async {
    final type = envelope.data['type']?.toString();
    if (type == 'telemetry') {
      telemetry = Telemetry.fromJson(envelope.data);
      await database.insertTelemetry(telemetry!);
    } else if (type == 'ack') {
      lastAck = DeviceAck.fromJson(envelope.data);
      await database.insertEvent('ack', '${lastAck!.action}: ${lastAck!.status}', lastAck!.detail);
    } else if (type == 'status') {
      await database.insertEvent('status', 'Estado do dispositivo', envelope.data.toString());
    }
    notifyListeners();
  }

  Future<void> sendAction(String action) async {
    final id = _uuid.v4();
    mqtt.publishJson({'type': 'command', 'deviceId': settings.deviceId, 'commandId': id, 'action': action});
    await database.insertEvent('command', 'Comando $action enviado', id);
  }

  Future<void> disposeAsync() async {
    await _messageSub?.cancel();
    await _connectionSub?.cancel();
    await mqtt.dispose();
  }
}
