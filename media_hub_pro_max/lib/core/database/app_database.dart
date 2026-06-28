import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../utils/vault_crypto.dart';

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
      version: 3,
      onCreate: (db, version) async {
        await _createTables(db);
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try { await db.execute('ALTER TABLE playlist_items ADD COLUMN display_name TEXT'); } catch (_) {}
          await db.execute('''CREATE TABLE IF NOT EXISTS recently_played (
            id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT, display_name TEXT, played_at INTEGER
          )''');
        }
        if (oldVersion < 3) {
          await _createIndexes(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
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
      id INTEGER PRIMARY KEY AUTOINCREMENT, playlist_id INTEGER, file_path TEXT, display_name TEXT, position INTEGER,
      FOREIGN KEY(playlist_id) REFERENCES playlists(id)
    )''');
    await db.execute('''CREATE TABLE download_history (
      id INTEGER PRIMARY KEY AUTOINCREMENT, url TEXT, file_name TEXT, file_path TEXT, file_size INTEGER, status TEXT, created_at INTEGER
    )''');
    await db.execute('''CREATE TABLE break_in_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp INTEGER, pin_used TEXT
    )''');
    await db.execute('''CREATE TABLE recently_played (
      id INTEGER PRIMARY KEY AUTOINCREMENT, file_path TEXT, display_name TEXT, played_at INTEGER
    )''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_path ON favorites(file_path)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_playlist_items_pid ON playlist_items(playlist_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_recently_played_path ON recently_played(file_path)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_download_history_url ON download_history(url)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_break_in_log_ts ON break_in_log(timestamp)');
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

  // ─── VAULT PASSWORDS (encrypted) ───
  Future<List<Map<String, dynamic>>> getVaultPasswords() async {
    final db = await database;
    final rows = await db.query('vault_passwords', orderBy: 'created_at DESC');
    // Decrypt passwords before returning
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      try {
        if (map['password'] != null && (map['password'] as String).isNotEmpty) {
          map['password'] = await VaultCrypto.decryptString(map['password'] as String);
        }
      } catch (_) {}
      result.add(map);
    }
    return result;
  }
  Future<int> insertVaultPassword(String service, String username, String password, {String? url, String? notes}) async {
    final db = await database;
    final encPassword = await VaultCrypto.encryptString(password);
    return db.insert('vault_passwords', {
      'service': service, 'username': username, 'password': encPassword,
      'url': url ?? '', 'notes': notes ?? '', 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  Future<int> deleteVaultPassword(int id) async {
    final db = await database;
    return db.delete('vault_passwords', where: 'id = ?', whereArgs: [id]);
  }

  // ─── VAULT CARDS (encrypted) ───
  Future<List<Map<String, dynamic>>> getVaultCards() async {
    final db = await database;
    final rows = await db.query('vault_cards', orderBy: 'created_at DESC');
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final map = Map<String, dynamic>.from(row);
      try {
        if (map['number_encrypted'] != null && (map['number_encrypted'] as String).isNotEmpty) {
          map['number_encrypted'] = await VaultCrypto.decryptString(map['number_encrypted'] as String);
        }
        if (map['cvv_encrypted'] != null && (map['cvv_encrypted'] as String).isNotEmpty) {
          map['cvv_encrypted'] = await VaultCrypto.decryptString(map['cvv_encrypted'] as String);
        }
      } catch (_) {}
      result.add(map);
    }
    return result;
  }
  Future<int> insertVaultCard(String holder, String numberEnc, String expiry, String cvvEnc, String cardType, {String? notes}) async {
    final db = await database;
    final encNumber = await VaultCrypto.encryptString(numberEnc);
    final encCvv = await VaultCrypto.encryptString(cvvEnc);
    return db.insert('vault_cards', {
      'holder': holder, 'number_encrypted': encNumber, 'expiry': expiry,
      'cvv_encrypted': encCvv, 'card_type': cardType, 'notes': notes ?? '', 'created_at': DateTime.now().millisecondsSinceEpoch,
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
    return db.insert('vault_photos', {'original_path': originalPath, 'stored_path': storedPath, 'created_at': DateTime.now().millisecondsSinceEpoch});
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

  // ─── PLAYLISTS ───
  Future<List<Map<String, dynamic>>> getPlaylists() async {
    final db = await database;
    return db.query('playlists', orderBy: 'created_at DESC');
  }
  Future<int> createPlaylist(String name) async {
    final db = await database;
    return db.insert('playlists', {'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch});
  }
  Future<int> renamePlaylist(int id, String name) async {
    final db = await database;
    return db.update('playlists', {'name': name}, where: 'id = ?', whereArgs: [id]);
  }
  Future<int> deletePlaylist(int id) async {
    final db = await database;
    await db.delete('playlist_items', where: 'playlist_id = ?', whereArgs: [id]);
    return db.delete('playlists', where: 'id = ?', whereArgs: [id]);
  }
  Future<List<Map<String, dynamic>>> getPlaylistItems(int playlistId) async {
    final db = await database;
    return db.query('playlist_items', where: 'playlist_id = ?', whereArgs: [playlistId], orderBy: 'position ASC');
  }
  Future<int> addToPlaylist(int playlistId, String filePath, String displayName, int position) async {
    final db = await database;
    return db.insert('playlist_items', {
      'playlist_id': playlistId, 'file_path': filePath, 'display_name': displayName, 'position': position,
    });
  }
  Future<int> removeFromPlaylist(int id) async {
    final db = await database;
    return db.delete('playlist_items', where: 'id = ?', whereArgs: [id]);
  }
  Future<int> getPlaylistCount(int playlistId) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM playlist_items WHERE playlist_id = ?', [playlistId]);
    return result.first['count'] as int? ?? 0;
  }
  Future<int> getNextPlaylistPosition(int playlistId) async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(position) as max_pos FROM playlist_items WHERE playlist_id = ?', [playlistId]);
    final maxPos = result.first['max_pos'] as int? ?? -1;
    return maxPos + 1;
  }

  // ─── RECENTLY PLAYED ───
  Future<List<Map<String, dynamic>>> getRecentlyPlayed({int limit = 30}) async {
    final db = await database;
    return db.query('recently_played', orderBy: 'played_at DESC', limit: limit);
  }
  Future<void> addRecentlyPlayed(String filePath, String displayName) async {
    final db = await database;
    await db.delete('recently_played', where: 'file_path = ?', whereArgs: [filePath]);
    await db.insert('recently_played', {
      'file_path': filePath, 'display_name': displayName, 'played_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ─── DOWNLOAD HISTORY ───
  Future<List<Map<String, dynamic>>> getDownloadHistory() async {
    final db = await database;
    return db.query('download_history', orderBy: 'created_at DESC');
  }
  Future<int> insertDownloadHistory(String url, String fileName, String filePath, int fileSize, String status) async {
    final db = await database;
    return db.insert('download_history', {
      'url': url, 'file_name': fileName, 'file_path': filePath, 'file_size': fileSize,
      'status': status, 'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }
  Future<int> deleteDownloadHistory(int id) async {
    final db = await database;
    return db.delete('download_history', where: 'id = ?', whereArgs: [id]);
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
