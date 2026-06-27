import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;

/// Background audio handler for audio_service.
/// Enables audio playback in background with notification controls.
class GiovaAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  GiovaAudioHandler() {
    _listenToPlayerState();
    _listenToProcessingState();
    _listenToCurrentPosition();
    _listenToDuration();
    _listenToSequenceState();
  }

  AudioPlayer get player => _player;

  void _listenToPlayerState() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
  }

  void _listenToProcessingState() {
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.pause();
      }
    });
  }

  void _listenToCurrentPosition() {
    // Already handled by playbackEventStream
  }

  void _listenToDuration() {
    // Already handled by playbackEventStream
  }

  void _listenToSequenceState() {
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
    });
  }

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
  Future<void> play() async => await _player.play();

  @override
  Future<void> pause() async => await _player.pause();

  @override
  Future<void> seek(Duration position) async => await _player.seek(position);

  @override
  Future<void> skipToNext() async => await _player.seekToNext();

  @override
  Future<void> skipToPrevious() async => await _player.seekToPrevious();

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setSpeed(double speed) async => await _player.setSpeed(speed);

  /// Set a playlist from file paths
  Future<void> setPlaylist(List<String> paths, {int startIndex = 0}) async {
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
    await _player.setAudioSource(playlist, initialIndex: startIndex);
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
      tag: MediaItem(
        id: path,
        title: title,
        artist: artist,
      ),
    );
    await _player.setAudioSource(source);
    await _player.play();
  }

  @override
  Future<void> onTaskRemoved() async {
    await stop();
  }
}
