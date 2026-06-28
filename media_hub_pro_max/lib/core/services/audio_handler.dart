import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Simple audio handler using just_audio directly.
/// No audio_service dependency — 100% reliable.
/// Singleton pattern: one AudioPlayer for the whole app.
class AudioHandler {
  static final AudioHandler _instance = AudioHandler._();
  static AudioHandler get instance => _instance;
  AudioHandler._();

  final AudioPlayer player = AudioPlayer();

  bool _disposed = false;

  /// Set a playlist from file paths and AUTO-PLAY.
  Future<void> setPlaylist(List<String> paths, {int startIndex = 0}) async {
    if (paths.isEmpty) return;
    if (startIndex < 0 || startIndex >= paths.length) startIndex = 0;

    final sources = paths.map((path) {
      final name = p.basenameWithoutExtension(path);
      String artist = '';
      String title = name;
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
      return AudioSource.file(
        path,
        tag: AudioMetadata(
          path: path,
          title: title,
          artist: artist,
        ),
      );
    }).toList();

    final playlist = ConcatenatingAudioSource(
      children: sources,
      useLazyPreparation: true,
    );

    try {
      await player.setAudioSource(playlist, initialIndex: startIndex);
      await player.play();
    } catch (e) {
      debugPrint('setPlaylist failed: $e');
      try { await player.stop(); } catch (_) {}
      rethrow;
    }
  }

  /// Play a single file
  Future<void> playFile(String path) async {
    final name = p.basenameWithoutExtension(path);
    String artist = '';
    String title = name;
    if (name.contains(' - ')) {
      final parts = name.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    }

    final source = AudioSource.file(
      path,
      tag: AudioMetadata(path: path, title: title, artist: artist),
    );

    try {
      await player.setAudioSource(source);
      await player.play();
    } catch (e) {
      debugPrint('playFile failed: $e');
      try { await player.stop(); } catch (_) {}
      rethrow;
    }
  }

  /// Insert a track to play next
  Future<void> playNext(String path) async {
    try {
      final source = player.audioSource;
      if (source is! ConcatenatingAudioSource) {
        await setPlaylist([path]);
        return;
      }
      final name = p.basenameWithoutExtension(path);
      String artist = '';
      String title = name;
      if (name.contains(' - ')) {
        final parts = name.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      }
      final newSource = AudioSource.file(
        path,
        tag: AudioMetadata(path: path, title: title, artist: artist),
      );
      final currentIndex = player.currentIndex ?? 0;
      await source.insert(currentIndex + 1, newSource);
    } catch (e) {
      debugPrint('playNext failed: $e');
      rethrow;
    }
  }

  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    try {
      if (player.playing) {
        await player.pause();
      } else {
        await player.play();
      }
    } catch (e) {
      debugPrint('togglePlayPause failed: $e');
    }
  }

  /// Stop playback
  Future<void> stop() async {
    try {
      await player.stop();
    } catch (e) {
      debugPrint('stop failed: $e');
    }
  }

  /// Get current metadata
  AudioMetadata? get currentMetadata {
    final seq = player.sequenceState;
    if (seq?.currentSource == null) return null;
    final tag = seq!.currentSource!.tag;
    return tag is AudioMetadata ? tag : null;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    player.dispose();
  }
}

/// Metadata for audio tracks
class AudioMetadata {
  final String path;
  final String title;
  final String artist;

  AudioMetadata({required this.path, required this.title, required this.artist});
}
