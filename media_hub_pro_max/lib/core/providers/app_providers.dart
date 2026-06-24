import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/file_scanner.dart';

// Audio player
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() {
    player.dispose();
  });
  return player;
});

// Audio controls
final audioVolumeProvider = StateProvider<double>((ref) => 1.0);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioCurrentIndexProvider = StateProvider<int>((ref) => -1);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0); // 0=off, 1=all, 2=one

// Playlist
final audioPlaylistProvider = StateProvider<List<MediaFile>>((ref) => []);

// Favorites
final favoritePathsProvider = StateProvider<Set<String>>((ref) => {});

// Recently played
final recentlyPlayedProvider = StateProvider<List<MediaFile>>((ref) => []);

// Vault
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);
final vaultDecoyProvider = StateProvider<bool>((ref) => false);

// Theme
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);

// Playback state
final isPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.playingStream;
});

final positionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.positionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.durationStream;
});

// Theme seeds list
final themeSeedsProvider = Provider<List<int>>((ref) => [
  0xFF6750A4,
  0xFFE91E63,
  0xFF9C27B0,
  0xFF009688,
  0xFFFF5722,
  0xFF795548,
  0xFF607D8B,
  0xFF4CAF50,
  0xFFFF9800,
  0xFF3F51B5,
]);

// SharedPreferences provider
final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});
