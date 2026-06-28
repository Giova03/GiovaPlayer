import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// Background audio handler for audio_service.
/// Enables audio playback in background with notification controls.
class GiovaAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  GiovaAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Respect LoopMode.all — only pause if NOT looping
        if (_player.loopMode != LoopMode.all) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      }
    });
    _player.sequenceStateStream.listen((seqState) {
      if (seqState == null) return;
      final items = seqState.sequence.map((source) {
        final tag = source.tag as MediaItem?;
        return tag ?? MediaItem(
          id: source.hashCode.toString(),
          title: 'Titre inconnu',
          artist: 'Artiste inconnu',
        );
      }).toList();
      queue.add(items);
      // Update mediaItem when current source changes (fixes BUG-12)
      final current = seqState.currentSource;
      if (current != null) {
        final tag = current.tag as MediaItem?;
        if (tag != null) {
          mediaItem.add(tag);
        }
      }
    });
  }

  AudioPlayer get player => _player;

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle: return AudioProcessingState.idle;
      case ProcessingState.loading: return AudioProcessingState.loading;
      case ProcessingState.buffering: return AudioProcessingState.buffering;
      case ProcessingState.ready: return AudioProcessingState.ready;
      case ProcessingState.completed: return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    try {
      await _player.play();
    } catch (e) {
      debugPrint('play() error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('pause() error: $e');
    }
  }

  @override
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('seek() error: $e');
    }
  }

  @override
  Future<void> skipToNext() async {
    try {
      await _player.seekToNext();
    } catch (e) {
      debugPrint('skipToNext() error: $e');
    }
  }

  @override
  Future<void> skipToPrevious() async {
    try {
      await _player.seekToPrevious();
    } catch (e) {
      debugPrint('skipToPrevious() error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _player.stop();
      await super.stop();
    } catch (e) {
      debugPrint('stop() error: $e');
    }
  }

  @override
  Future<void> setSpeed(double speed) async {
    try {
      await _player.setSpeed(speed);
    } catch (e) {
      debugPrint('setSpeed() error: $e');
    }
  }

  /// Set a playlist from file paths and AUTO-PLAY.
  /// Throws on failure so caller can show error.
  Future<void> setPlaylist(List<String> paths, {int startIndex = 0}) async {
    if (paths.isEmpty) return;

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
        tag: MediaItem(
          id: path,
          title: title,
          artist: artist,
          album: '',
        ),
      );
    }).toList();

    final playlist = ConcatenatingAudioSource(children: sources);
    try {
      await _player.setAudioSource(playlist, initialIndex: startIndex);
      await _player.play(); // AUTO-PLAY
    } catch (e) {
      debugPrint('setAudioSource failed for $paths: $e');
      try { await _player.stop(); } catch (_) {}
      rethrow; // Let caller handle
    }
  }

  /// Insert a track to play next (after current position)
  Future<void> playNext(String path) async {
    try {
      final source = _player.audioSource;
      if (source is! ConcatenatingAudioSource) {
        // If no playlist, just play the file
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
      final newSource = AudioSource.file(path, tag: MediaItem(id: path, title: title, artist: artist));
      final currentIndex = _player.currentIndex ?? 0;
      await source.insert(currentIndex + 1, newSource);
    } catch (e) {
      debugPrint('playNext() error: $e');
      rethrow;
    }
  }

  @override
  Future<void> onTaskRemoved() async {
    // Keep playing in background when app is swiped away
    if (!_player.playing) {
      await stop();
    }
  }
}
