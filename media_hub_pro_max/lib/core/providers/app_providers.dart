import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/file_scanner.dart';

// Audio player
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

// Audio controls
final audioVolumeProvider = StateProvider<double>((ref) => 1.0);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioCurrentIndexProvider = StateProvider<int>((ref) => 0);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0);
final audioPlaylistProvider = StateProvider<List<MediaFile>>((ref) => []);
final favoritePathsProvider = StateProvider<Set<String>>((ref) => {});
final recentlyPlayedProvider = StateProvider<List<MediaFile>>((ref) => []);

// Vault
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);
final vaultDecoyProvider = StateProvider<bool>((ref) => false);

// Theme
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);
