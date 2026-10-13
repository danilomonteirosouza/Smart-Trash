import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/mqtt_settings.dart';

class SettingsRepository {
  SettingsRepository(this.database, this.secureStorage);
  final AppDatabase database;
  final FlutterSecureStorage secureStorage;

  static const _passwordKey = 'mqtt_password';
  static const _profileKey = 'mqtt_hivemq_profile';
  static const _profileVersion = 'lixeira_inteligente_2026_10';
  // Credencial fornecida para a configuração inicial do HiveMQ Cloud.
  // Após o primeiro uso, o armazenamento da senha fica no secure storage.
  // Em aplicações distribuídas, recomenda-se trocar essa senha no broker.
  static const _initialPassword = 'Vilarim/123';

  Future<void> ensureSchema() async {
    await database.db.execute("""CREATE TABLE IF NOT EXISTS settings(
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )""");
  }

  Future<void> _put(String key, String value) async => database.db.insert(
        'settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> _get(String key) async {
    final rows = await database.db.query('settings', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value']?.toString();
  }

  Future<void> save(MqttSettings s, String password) async {
    await ensureSchema();
    await _put('host', s.host);
    await _put('port', s.port.toString());
    await _put('username', s.username);
    await _put('subscribeTopic', s.subscribeTopic);
    await _put('publishTopic', s.publishTopic);
    await _put('sameTopic', s.sameTopic.toString());
    await _put('deviceId', s.deviceId);
    await secureStorage.write(key: _passwordKey, value: password);
  }

  Future<(MqttSettings, String)> load() async {
    await ensureSchema();
    final d = MqttSettings.defaults();

    // A atualização do perfil MQTT é executada uma só vez. Ela substitui
    // os tópicos e credenciais antigos, sem apagar o ID do dispositivo.
    // Alterações feitas pelo usuário após a migração são preservadas.
    if (await _get(_profileKey) != _profileVersion) {
      final existingDeviceId = await _get('deviceId');
      final settings = d.copyWith(
        deviceId: existingDeviceId?.trim().isNotEmpty == true
            ? existingDeviceId
            : d.deviceId,
      );
      await save(settings, _initialPassword);
      await _put(_profileKey, _profileVersion);
      return (settings, _initialPassword);
    }

    final sameTopicValue = await _get('sameTopic');
    final settings = MqttSettings(
      host: await _get('host') ?? d.host,
      port: int.tryParse(await _get('port') ?? '') ?? d.port,
      username: await _get('username') ?? d.username,
      subscribeTopic: await _get('subscribeTopic') ?? d.subscribeTopic,
      publishTopic: await _get('publishTopic') ?? d.publishTopic,
      sameTopic: sameTopicValue == null ? d.sameTopic : sameTopicValue == 'true',
      deviceId: await _get('deviceId') ?? d.deviceId,
    );
    return (settings, await secureStorage.read(key: _passwordKey) ?? '');
  }
}
