import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';

/// ─── PROVIDER BASE DE DONNÉES DRIFT/SQLITE ───
/// Instance unique partagée via Riverpod
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// ─── PROVIDER MÉDIAS RÉCENTS ───
final recentMediaProvider = FutureProvider<List<MediaItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  final items = await (db.select(db.mediaItems)
    ..orderBy([(t) => OrderingTerm.desc(t.lastAccessed)])
    ..limit(20))
    .get();
  return items;
});

/// ─── PROVIDER ALBUMS ───
final albumsProvider = FutureProvider<List<Album>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.albums)).get();
});

/// ─── PROVIDER VAULT ITEMS ───
final vaultItemsProvider = FutureProvider<List<VaultItem>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.vaultItems)).get();
});

/// ─── PROVIDER DOWNLOADS ACTIFS ───
final activeDownloadsProvider = StreamProvider<List<DownloadTask>>((ref) async* {
  final db = ref.watch(databaseProvider);
  /// Polling toutes les 2 secondes pour les downloads actifs
  while (true) {
    await Future.delayed(const Duration(seconds: 2));
    final tasks = await (db.select(db.downloadTasks)
      ..where((t) => t.status.equals('active')))
    .get();
    yield tasks;
  }
});

/// ─── PROVIDER STATISTIQUES STOCKAGE ───
final storageStatsProvider = FutureProvider<StorageStats>((ref) async {
  final db = ref.watch(databaseProvider);

  final allMedia = await db.select(db.mediaItems).get();
  final audioCount = allMedia.where((m) => m.type == 'audio').length;
  final videoCount = allMedia.where((m) => m.type == 'video').length;
  final imageCount = allMedia.where((m) => m.type == 'image').length;
  final totalSize = allMedia.fold<int>(0, (sum, m) => sum + m.size);

  return StorageStats(
    audioCount: audioCount,
    videoCount: videoCount,
    imageCount: imageCount,
    totalSizeBytes: totalSize,
  );
});

class StorageStats {
  final int audioCount;
  final int videoCount;
  final int imageCount;
  final int totalSizeBytes;

  const StorageStats({
    required this.audioCount,
    required this.videoCount,
    required this.imageCount,
    required this.totalSizeBytes,
  });

  String get totalSizeFormatted {
    if (totalSizeBytes < 1024) return '$totalSizeBytes B';
    if (totalSizeBytes < 1048576) return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    if (totalSizeBytes < 1073741824) return '${(totalSizeBytes / 1048576).toStringAsFixed(1)} MB';
    return '${(totalSizeBytes / 1073741824).toStringAsFixed(1)} GB';
  }
}
