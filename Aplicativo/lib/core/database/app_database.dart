import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../features/telemetry/domain/telemetry.dart';

class AppDatabase {
  Database? _db;

  Future<void> open() async {
    final base = await getDatabasesPath();
    _db = await openDatabase(
      p.join(base, 'lixeira_inteligente.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute("""CREATE TABLE telemetry(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id TEXT NOT NULL,
          weight_grams REAL NOT NULL,
          metal_detected INTEGER NOT NULL,
          presence INTEGER NOT NULL,
          fill_level REAL NOT NULL,
          gate_state TEXT NOT NULL,
          network TEXT NOT NULL,
          rssi INTEGER NOT NULL,
          received_at TEXT NOT NULL
        )""");
        await db.execute("""CREATE TABLE events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          kind TEXT NOT NULL,
          title TEXT NOT NULL,
          detail TEXT NOT NULL,
          created_at TEXT NOT NULL
        )""");
      },
    );
  }

  Database get db {
    final value = _db;
    if (value == null) throw StateError('Banco não inicializado');
    return value;
  }

  Future<void> insertTelemetry(Telemetry telemetry) async => db.insert('telemetry', telemetry.toDb());

  Future<void> insertEvent(String kind, String title, String detail) async {
    await db.insert('events', {
      'kind': kind,
      'title': title,
      'detail': detail,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, Object?>>> recentEvents({int limit = 100}) =>
      db.query('events', orderBy: 'id DESC', limit: limit);

  Future<void> close() async => _db?.close();
}
