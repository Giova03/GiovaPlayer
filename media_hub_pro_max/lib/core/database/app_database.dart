/// Base de données GiovaPlayer - Stockage local uniquement
/// SECURITE: Aucune donnée n'est transmise en réseau.
class AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  AppDatabase._();

  // Stockage en mémoire pour les favoris, playlists, historique
  final Map<String, List<Map<String, dynamic>>> _tables = {};

  void _init() {
    _tables['favorites'] = [];
    _tables['playlists'] = [];
    _tables['history'] = [];
    _tables['vault_items'] = [];
    _tables['downloads'] = [];
  }

  List<Map<String, dynamic>> getFavorites() => _tables['favorites'] ?? [];
  List<Map<String, dynamic>> getHistory() => _tables['history'] ?? [];
  List<Map<String, dynamic>> getPlaylists() => _tables['playlists'] ?? [];

  int insert(String table, Map<String, dynamic> item) {
    final list = _tables.putIfAbsent(table, () => []);
    final id = list.isEmpty ? 1 : (list.last['id'] as int) + 1;
    item['id'] = id;
    list.add(item);
    return id;
  }

  void delete(String table, int id) {
    _tables[table]?.removeWhere((i) => i['id'] == id);
  }

  bool isFavorite(String path) {
    return (_tables['favorites'] ?? []).any((f) => f['path'] == path);
  }

  void toggleFavorite(String path, String name, String type) {
    if (isFavorite(path)) {
      (_tables['favorites'] ?? []).removeWhere((f) => f['path'] == path);
    } else {
      insert('favorites', {'path': path, 'name': name, 'type': type, 'date': DateTime.now().millisecondsSinceEpoch});
    }
  }

  void addToHistory(String path, String name, String type) {
    // Enlever l'ancien si existant
    (_tables['history'] ?? []).removeWhere((h) => h['path'] == path);
    insert('history', {'path': path, 'name': name, 'type': type, 'date': DateTime.now().millisecondsSinceEpoch});
    // Garder seulement les 100 derniers
    final hist = _tables['history'] ?? [];
    if (hist.length > 100) {
      hist.removeRange(0, hist.length - 100);
    }
  }
}
