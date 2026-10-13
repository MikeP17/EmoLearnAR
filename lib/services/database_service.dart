import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/emotion_log.dart';
import '../models/monitoring_session.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'emolearnar.db');
    _database = await openDatabase(
      path,
      version: 3,
      onCreate: _create,
      onUpgrade: _upgrade,
    );
    return _database!;
  }

  Future<void> _create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE sessions (
        id TEXT PRIMARY KEY,
        class_name TEXT NOT NULL DEFAULT '',
        started_at TEXT NOT NULL,
        ended_at TEXT,
        total_samples INTEGER NOT NULL DEFAULT 0,
        dominant_emotion TEXT NOT NULL DEFAULT 'Neutral',
        reflection_note TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE TABLE emotion_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        emotion TEXT NOT NULL,
        confidence REAL NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY(session_id) REFERENCES sessions(id)
      )
    ''');
  }

  Future<void> _upgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        "ALTER TABLE sessions ADD COLUMN class_name TEXT NOT NULL DEFAULT ''",
      );
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE sessions ADD COLUMN reflection_note TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> insertSession(MonitoringSession session) async {
    final db = await database;
    await db.insert(
      'sessions',
      session.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateSession(MonitoringSession session) async {
    final db = await database;
    await db.update(
      'sessions',
      session.toMap(),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<void> insertLog(EmotionLog log) async {
    final db = await database;
    await db.insert('emotion_logs', log.toMap());
  }

  Future<List<EmotionLog>> logsForSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      'emotion_logs',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
    return rows.map(EmotionLog.fromMap).toList();
  }

  Future<List<MonitoringSession>> allSessions() async {
    final db = await database;
    final rows = await db.query('sessions', orderBy: 'started_at DESC');
    return rows.map(MonitoringSession.fromMap).toList();
  }

  Future<void> deleteSession(String sessionId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'emotion_logs',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      await txn.delete(
        'sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );
    });
  }

  Future<MonitoringSession?> latestSession() async {
    final sessions = await allSessions();
    return sessions.isEmpty ? null : sessions.first;
  }
}
