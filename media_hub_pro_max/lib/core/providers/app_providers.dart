import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';

final dbProvider = Provider<AppDatabase>((ref) => AppDatabase.instance);
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);

// Audio state
final audioPlayingProvider = StateProvider<bool>((ref) => false);
final audioProgressProvider = StateProvider<double>((ref) => 0.0);
final audioVolumeProvider = StateProvider<double>((ref) => 0.8);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioTrackIndexProvider = StateProvider<int>((ref) => 0);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0); // 0=off,1=all,2=one

// Video state
final videoPlayingProvider = StateProvider<bool>((ref) => false);
final videoProgressProvider = StateProvider<double>((ref) => 0.0);
