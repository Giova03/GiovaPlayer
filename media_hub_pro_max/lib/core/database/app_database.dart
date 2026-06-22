/// ─── BASE DE DONNÉES PERSISTANTE ───
/// Utilise sqflite + path_provider en production
/// Mode démo : stockage en mémoire (Map) avec interface compatible
/// Pour activer sqflite : ajouter les dépendances au pubspec.yaml

import 'dart:convert';

class AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  final Map<String, List<Map<String, dynamic>>> _tables = {};

  AppDatabase._() {
    _tables['media_items'] = [];
    _tables['vault_items'] = [];
    _tables['download_tasks'] = [];
    _tables['notes'] = [];
    _tables['passwords'] = [];
    _tables['eq_presets'] = [];
    _initSampleData();
  }

  /// Initialise des données d'exemple pour la démo
  void _initSampleData() {
    // Médias audio
    for (int i = 1; i <= 8; i++) {
      _tables['media_items']!.add({
        'id': i,
        'title': 'Morceau $i',
        'artist': 'Artiste $i',
        'album': 'Album ${((i - 1) ~/ 3) + 1}',
        'path': '/storage/music/track_$i.flac',
        'type': 'audio',
        'duration': 180000 + (i * 30000),
        'size': 35000000 + (i * 5000000),
        'bitrate': [1411, 320, 1411, 969, 1411, 320, 969, 1411][i - 1],
        'sample_rate': [96000, 44100, 96000, 48000, 96000, 44100, 48000, 96000][i - 1],
        'format': ['FLAC', 'MP3', 'FLAC', 'DSF', 'FLAC', 'MP3', 'WAV', 'FLAC'][i - 1],
        'genre': ['Rock', 'Jazz', 'Électro', 'Classique', 'Hip-Hop', 'Pop', 'Rock', 'Jazz'][i - 1],
        'bpm': [128.0, 95.0, 140.0, 72.0, 110.0, 120.0, 135.0, 88.0][i - 1],
        'date_added': DateTime.now().subtract(Duration(days: i)).millisecondsSinceEpoch,
      });
    }
    // Médias vidéo
    for (int i = 1; i <= 5; i++) {
      _tables['media_items']!.add({
        'id': 8 + i,
        'title': 'Vidéo $i',
        'artist': null,
        'path': '/storage/video/film_$i.mkv',
        'type': 'video',
        'duration': 5400000 + (i * 1800000),
        'size': [2500000000, 5100000000, 1800000000, 900000000, 3200000000][i - 1],
        'format': ['MKV', 'MP4', 'MKV', 'MP4', 'MKV'][i - 1],
        'date_added': DateTime.now().subtract(Duration(days: i * 2)).millisecondsSinceEpoch,
      });
    }
    // Items vault
    _tables['vault_items']!.addAll([
      {'id': 1, 'original_name': 'photo_vacances.jpg', 'type': 'photo', 'size': 4500000, 'is_decoy': 0, 'date_added': DateTime.now().millisecondsSinceEpoch},
      {'id': 2, 'original_name': 'document_secret.pdf', 'type': 'file', 'size': 1200000, 'is_decoy': 0, 'date_added': DateTime.now().millisecondsSinceEpoch},
      {'id': 3, 'original_name': 'note_privee.txt', 'type': 'note', 'size': 5000, 'is_decoy': 0, 'date_added': DateTime.now().millisecondsSinceEpoch},
    ]);
  }

  /// Opérations CRUD génériques
  List<Map<String, dynamic>> query(String table) =>
      List.from(_tables[table] ?? []);

  int insert(String table, Map<String, dynamic> item) {
    final list = _tables.putIfAbsent(table, () => []);
    final id = list.isEmpty ? 1 : (list.last['id'] as int) + 1;
    item['id'] = id;
    list.add(item);
    return id;
  }

  void delete(String table, int id) {
    _tables[table]?.removeWhere((item) => item['id'] == id);
  }

  void update(String table, int id, Map<String, dynamic> values) {
    final list = _tables[table];
    if (list == null) return;
    final idx = list.indexWhere((item) => item['id'] == id);
    if (idx >= 0) list[idx].addAll(values);
  }

  /// Raccourcis métier
  List<Map<String, dynamic>> getRecentMedia({int limit = 20}) {
    final items = query('media_items');
    items.sort((a, b) =>
        (b['date_added'] as int).compareTo(a['date_added'] as int));
    return items.take(limit).toList();
  }

  List<Map<String, dynamic>> getMediaByType(String type) {
    return query('media_items')
        .where((m) => m['type'] == type)
        .toList();
  }

  List<Map<String, dynamic>> getVaultItems() => query('vault_items');

  List<Map<String, dynamic>> getActiveDownloads() =>
      query('download_tasks')
          .where((d) => d['status'] == 'active')
          .toList();

  Map<String, int> getStorageStats() {
    final stats = <String, int>{};
    for (final item in query('media_items')) {
      final type = item['type'] as String? ?? 'other';
      final size = item['size'] as int? ?? 0;
      stats[type] = (stats[type] ?? 0) + size;
    }
    return stats;
  }

  int get totalCount =>
      _tables.values.fold(0, (sum, list) => sum + list.length);
}
