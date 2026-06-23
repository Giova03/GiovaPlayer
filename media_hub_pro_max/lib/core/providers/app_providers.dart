import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../utils/file_scanner.dart';

// Thème
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);

// Scan status
final scanStatusProvider = StateProvider<String>((ref) => 'En attente...');

// Audio player state
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

final audioPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.playingStream;
});

final audioProgressProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.positionStream;
});

final audioDurationProvider = StreamProvider<Duration?>((ref) {
  final player = ref.watch(audioPlayerProvider);
  return player.durationStream;
});

final audioVolumeProvider = StateProvider<double>((ref) => 0.8);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioCurrentIndexProvider = StateProvider<int>((ref) => 0);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0);

// Video state
final videoPlayingProvider = StateProvider<bool>((ref) => false);
final videoProgressProvider = StateProvider<double>((ref) => 0.0);
