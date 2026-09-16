import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/app_database.dart';
import '../domain/mqtt_settings.dart';

class SettingsRepository {
  SettingsRepository(this.database, this.secureStorage);
  final AppDatabase database;
  final FlutterSecureStorage secureStorage;

  static const _passwordKey = 'mqtt_password';

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
    final settings = MqttSettings(
      host: await _get('host') ?? d.host,
      port: int.tryParse(await _get('port') ?? '') ?? d.port,
      username: await _get('username') ?? d.username,
      subscribeTopic: await _get('subscribeTopic') ?? d.subscribeTopic,
      publishTopic: await _get('publishTopic') ?? d.publishTopic,
      sameTopic: (await _get('sameTopic')) == 'true',
      deviceId: await _get('deviceId') ?? d.deviceId,
    );
    return (settings, await secureStorage.read(key: _passwordKey) ?? '');
  }
}
