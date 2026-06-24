import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'dart:convert';

class AppDatabase {
  static Database? _db;
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();
  AppDatabase._();

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      p.join(dbPath, 'giova_player.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''CREATE TABLE vault_notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, content TEXT, created_at INTEGER, updated_at INTEGER
        )''');
        await db.execute('''CREATE TABLE vault_passwords (
          id INTEGER PRIMARY KEY AUTOINCREMENT, service TEXT, username TEXT, password TEXT, url TEXT, notes TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE vault_cards (
          id INTEGER PRIMARY KEY AUTOINCREMENT, holder TEXT, number_encrypted TEXT, expiry TEXT, cvv_encrypted TEXT, card_type TEXT, notes TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE vault_photos (
          id INTEGER PRIMARY KEY AUTOINCREMENT, original_path TEXT, stored_path TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE vault_files (
          id INTEGER PRIMARY KEY AUTOINCREMENT, original_path TEXT, stored_path TEXT, file_name TEXT, file_size INTEGER, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT, file_type TEXT, display_name TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE playlists (
          id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE playlist_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT, playlist_id INTEGER, file_path TEXT, position INTEGER,
          FOREIGN KEY(playlist_id) REFERENCES playlists(id)
        )''');
        await db.execute('''CREATE TABLE download_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT, file_name TEXT, file_path TEXT, file_size INTEGER, status TEXT, created_at INTEGER
        )''');
        await db.execute('''CREATE TABLE break_in_log (
          id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, pin_used TEXT
        )''');
      },
    );
  }

  // ─── VAULT NOTES ───
  Future<List<Map<String, dynamic>>> getVaultNotes() async {
    final db = await database;
    return db.query('vault_notes', orderBy: 'updated_at DESC');
  }

  Future<int> insertVaultNote(String title, String content) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return db.insert('vault_notes', {'title': title, 'content': content, 'created_at': now, 'updated_at': now});
  }

  Future<int> updateVaultNote(int id, String title, String content) async {
    final db = await database;
    return db.update('vault_notes', {'title': title, 'content': content, 'updated_at': DateTime.now().millisecondsSinceEpoch}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteVaultNote(int id) async {
    final db = await database;
    return db.delete('vault_notes', where: 'id = ?', whereArgs: [id]);
  }

  // ─── VAULT PASSWORDS ───
  Future<List<Map<String, dynamic>>> getVaultPasswords() async {
    final db = await database;
    return db.query('vault_passwords', orderBy: 'created_at DESC');
  }

  Future<int> insertVaultPassword(String service, String username, String password, {String? url, String? notes}) async {
    final db = await database;
    return db.insert('vault_passwords', {
      'service': service, 'username': username, 'password': password,
      'url': url ?? '', 'notes': notes ?? '', 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> updateVaultPassword(int id, String service, String username, String password, {String? url, String? notes}) async {
    final db = await database;
    return db.update('vault_passwords', {
      'service': service, 'username': username, 'password': password,
      'url': url ?? '', 'notes': notes ?? '',
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteVaultPassword(int id) async {
    final db = await database;
    return db.delete('vault_passwords', where: 'id = ?', whereArgs: [id]);
  }

  // ─── VAULT CARDS ───
  Future<List<Map<String, dynamic>>> getVaultCards() async {
    final db = await database;
    return db.query('vault_cards', orderBy: 'created_at DESC');
  }

  Future<int> insertVaultCard(String holder, String numberEnc, String expiry, String cvvEnc, String cardType, {String? notes}) async {
    final db = await database;
    return db.insert('vault_cards', {
      'holder': holder, 'number_encrypted': numberEnc, 'expiry': expiry,
      'cvv_encrypted': cvvEnc, 'card_type': cardType, 'notes': notes ?? '', 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> deleteVaultCard(int id) async {
    final db = await database;
    return db.delete('vault_cards', where: 'id = ?', whereArgs: [id]);
  }

  // ─── VAULT PHOTOS ───
  Future<List<Map<String, dynamic>>> getVaultPhotos() async {
    final db = await database;
    return db.query('vault_photos', orderBy: 'created_at DESC');
  }

  Future<int> insertVaultPhoto(String originalPath, String storedPath) async {
    final db = await database;
    return db.insert('vault_photos', {
      'original_path': originalPath, 'stored_path': storedPath, 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> deleteVaultPhoto(int id) async {
    final db = await database;
    return db.delete('vault_photos', where: 'id = ?', whereArgs: [id]);
  }

  // ─── VAULT FILES ───
  Future<List<Map<String, dynamic>>> getVaultFiles() async {
    final db = await database;
    return db.query('vault_files', orderBy: 'created_at DESC');
  }

  Future<int> insertVaultFile(String originalPath, String storedPath, String fileName, int fileSize) async {
    final db = await database;
    return db.insert('vault_files', {
      'original_path': originalPath, 'stored_path': storedPath,
      'file_name': fileName, 'file_size': fileSize, 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<int> deleteVaultFile(int id) async {
    final db = await database;
    return db.delete('vault_files', where: 'id = ?', whereArgs: [id]);
  }

  // ─── FAVORITES ───
  Future<List<Map<String, dynamic>>> getFavorites() async {
    final db = await database;
    return db.query('favorites', orderBy: 'created_at DESC');
  }

  Future<bool> isFavorite(String filePath) async {
    final db = await database;
    final result = await db.query('favorites', where: 'file_path = ?', whereArgs: [filePath]);
    return result.isNotEmpty;
  }

  Future<void> toggleFavorite(String filePath, String fileType, String displayName) async {
    final db = await database;
    if (await isFavorite(filePath)) {
      await db.delete('favorites', where: 'file_path = ?', whereArgs: [filePath]);
    } else {
      await db.insert('favorites', {
        'file_path': filePath, 'file_type': fileType, 'display_name': displayName,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  // ─── BREAK-IN LOG ───
  Future<List<Map<String, dynamic>>> getBreakInLog() async {
    final db = await database;
    return db.query('break_in_log', orderBy: 'timestamp DESC');
  }

  Future<int> logBreakIn(String pinUsed) async {
    final db = await database;
    return db.insert('break_in_log', {'timestamp': DateTime.now().millisecondsSinceEpoch, 'pin_used': pinUsed});
  }

  Future<int> clearBreakInLog() async {
    final db = await database;
    return db.delete('break_in_log');
  }

  // ─── EMERGENCY WIPE ───
  Future<void> emergencyWipe() async {
    final db = await database;
    await db.delete('vault_notes');
    await db.delete('vault_passwords');
    await db.delete('vault_cards');
    await db.delete('vault_photos');
    await db.delete('vault_files');
    await db.delete('break_in_log');
  }
}
