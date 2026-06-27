import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../utils/file_scanner.dart';

// Audio handler (background service)
final audioHandlerProvider = FutureProvider<GiovaAudioHandler>((ref) async {
  return await AudioService.init(
    builder: () => GiovaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.giovaplayer.giova_player.audio',
      androidNotificationChannelName: 'GiovaPlayer Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
});

// Audio player (from handler)
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final handlerAsync = ref.watch(audioHandlerProvider);
  return handlerAsync.when(
    data: (handler) => handler.player,
    loading: () => AudioPlayer(),
    error: (_, __) => AudioPlayer(),
  );
});

// Audio controls
final audioVolumeProvider = StateProvider<double>((ref) => 1.0);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioCurrentIndexProvider = StateProvider<int>((ref) => 0);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0); // 0=off, 1=all, 2=one
final audioPlaylistProvider = StateProvider<List<MediaFile>>((ref) => []);
final favoritePathsProvider = StateProvider<Set<String>>((ref) => {});
final recentlyPlayedProvider = StateProvider<List<MediaFile>>((ref) => []);
final showMiniPlayerProvider = StateProvider<bool>((ref) => false);
final currentAudioFileProvider = StateProvider<MediaFile?>((ref) => null);

// Vault
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);
final vaultDecoyProvider = StateProvider<bool>((ref) => false);

// Theme
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);
