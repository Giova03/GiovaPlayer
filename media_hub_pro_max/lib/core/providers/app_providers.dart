import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/audio_handler.dart';
import '../utils/file_scanner.dart';

// Audio handler — singleton, no async init needed
final audioHandlerProvider = Provider<AudioHandler>((ref) {
  final handler = AudioHandler.instance;
  ref.onDispose(() {
    // Don't dispose the singleton — it lives for the app's lifetime
  });
  return handler;
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
