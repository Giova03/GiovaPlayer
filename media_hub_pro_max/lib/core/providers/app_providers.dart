import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../services/audio_handler.dart';
import '../utils/file_scanner.dart';

// Audio handler (background service) — eagerly initialized in main()
final audioHandlerProvider = FutureProvider<GiovaAudioHandler>((ref) async {
  return await AudioService.init(
    builder: () => GiovaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.giovaplayer.giova_player.audio',
      androidNotificationChannelName: 'GiovaPlayer Audio',
      androidNotificationChannelDescription: 'Lecture audio en arrière-plan',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
});

// Current audio file (for mini-player)
final currentAudioFileProvider = StateProvider<MediaFile?>((ref) => null);

// Vault
final vaultUnlockedProvider = StateProvider<bool>((ref) => false);
final vaultDecoyProvider = StateProvider<bool>((ref) => false);
final antiScreenshotProvider = StateProvider<bool>((ref) => true);
final autoBlurProvider = StateProvider<bool>((ref) => true);
final autoLockProvider = StateProvider<bool>((ref) => true);

// Theme
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
