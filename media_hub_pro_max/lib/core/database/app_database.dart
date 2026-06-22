/// Base de donnees GiovaPlayer - Stockage local uniquement
/// SECURITE: Aucune donnee n'est transmise en reseau.
/// Toutes les donnees personnelles restent sur l'appareil.
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
    _initSampleData();
  }

  void _initSampleData() {
    final tracks = [
      ('Ambiance Nocturne', 'DJ Giova', 'FLAC 24bit/96kHz', 'Rock', 128.0),
      ('Soleil Levant', 'Ama Giova', 'FLAC 24bit/192kHz', 'Jazz', 95.0),
      ('Rythme Urbain', 'Giova Crew', 'DSF 1bit/2.8MHz', 'Electro', 140.0),
      ('Melodie Douce', 'Orchestre Bamo', 'FLAC 16bit/44kHz', 'Classique', 72.0),
      ('Afro Beat', 'DJ Giova', 'WAV 24bit/48kHz', 'Afro', 110.0),
      ('Solitude', 'Piano Giova', 'FLAC 24bit/96kHz', 'Pop', 88.0),
      ('Energie Pure', 'Giova Bass', 'MP3 320kbps', 'Hip-Hop', 135.0),
      ('Horizon', 'Ama Giova', 'FLAC 24bit/96kHz', 'R&B', 120.0),
    ];
    for (int i = 0; i < tracks.length; i++) {
      _tables['media_items']!.add({
        'id': i + 1, 'title': tracks[i].$1, 'artist': tracks[i].$2,
        'path': '/storage/music/track_${i+1}.flac', 'type': 'audio',
        'duration': 180000 + i * 25000, 'size': 30000000 + i * 5000000,
        'format': tracks[i].$3, 'genre': tracks[i].$4, 'bpm': tracks[i].$5,
        'date_added': DateTime.now().subtract(Duration(days: i)).millisecondsSinceEpoch,
      });
    }
    final videos = [
      ('Film_4K_HDR.mkv', 'H.265 3840x2160 HDR10+ 23.976fps', 2500000000, '4K'),
      ('Serie_S01E01.mp4', 'H.264 1920x1080 AAC 5.1', 800000000, '1080p'),
      ('Clip_Musical.mkv', 'H.265 3840x2160 FLAC', 1200000000, '4K'),
      ('Docu_Nature.mp4', 'H.264 1920x1080 Dolby Vision', 500000000, '1080p'),
      ('Concert_Live.mkv', 'H.265 3840x2160 ATMOS', 3200000000, '4K'),
    ];
    for (int i = 0; i < videos.length; i++) {
      _tables['media_items']!.add({
        'id': 8 + i + 1, 'title': videos[i].$1, 'artist': null,
        'path': '/storage/video/film_${i+1}.mkv', 'type': 'video',
        'duration': 5400000 + i * 1800000, 'size': videos[i].$3,
        'format': videos[i].$2, 'date_added': DateTime.now().subtract(Duration(days: i*2)).millisecondsSinceEpoch,
      });
    }
  }

  List<Map<String, dynamic>> getRecentMedia({int limit = 20}) {
    final items = List.from(_tables['media_items'] ?? []);
    items.sort((a, b) => (b['date_added'] as int).compareTo(a['date_added'] as int));
    return items.cast<Map<String, dynamic>>().take(limit).toList();
  }
  List<Map<String, dynamic>> getMediaByType(String type) =>
    (_tables['media_items'] ?? []).where((m) => m['type'] == type).toList();
  List<Map<String, dynamic>> getVaultItems() => List.from(_tables['vault_items'] ?? []);
  Map<String, int> getStorageStats() {
    final stats = <String, int>{};
    for (final item in _tables['media_items'] ?? []) {
      final t = item['type'] as String? ?? 'other';
      stats[t] = (stats[t] ?? 0) + (item['size'] as int? ?? 0);
    }
    return stats;
  }
  int insert(String table, Map<String, dynamic> item) {
    final list = _tables.putIfAbsent(table, () => []);
    final id = list.isEmpty ? 1 : (list.last['id'] as int) + 1;
    item['id'] = id; list.add(item); return id;
  }
  void delete(String table, int id) => _tables[table]?.removeWhere((i) => i['id'] == id);
}
