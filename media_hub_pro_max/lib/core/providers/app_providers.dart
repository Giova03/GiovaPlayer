// GiovaPlayer - Providers Riverpod globaux
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

/// Provider de la base de donnees SQLite
final dbProvider = Provider<AppDatabase>((ref) {
  return AppDatabase.instance;
});

/// Provider des medias recents
final recentMediaProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getRecentMedia();
});

/// Provider des elements du coffre-fort
final vaultItemsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getVaultItems();
});

/// Provider des telechargements actifs
final activeDownloadsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getActiveDownloads();
});

/// Provider des statistiques de stockage
final storageStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getStorageStats();
});

/// Provider du nom du theme actif
final themeNameProvider = StateProvider<String>((ref) => 'Violet Royal');

/// Provider du mode sombre
final isDarkModeProvider = StateProvider<bool>((ref) => false);

/// Provider du mode enfants
final kidsModeProvider = StateProvider<bool>((ref) => false);

/// Provider de la recherche globale
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider du verrouillage du coffre
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);

/// Provider de l'onglet audio actif
final audioTabProvider = StateProvider<int>((ref) => 0);

/// Provider de l'onglet telechargement actif
final downloadTabProvider = StateProvider<int>((ref) => 0);

/// Provider du volume audio
final volumeProvider = StateProvider<double>((ref) => 0.8);

/// Provider de la vitesse de lecture
final playbackSpeedProvider = StateProvider<double>((ref) => 1.0);

/// Provider de la file d'attente audio
final audioQueueProvider = StateProvider<List<Map<String, dynamic>>>((ref) => []);

/// Provider du mode shuffle
final shuffleModeProvider = StateProvider<bool>((ref) => false);

/// Provider du mode repetition
final repeatModeProvider = StateProvider<int>((ref) => 0);

/// Provider du preset EQ actif
final eqPresetProvider = StateProvider<String>((ref) => 'Normal');
