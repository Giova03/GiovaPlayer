import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import '../utils/file_scanner.dart';

// ─── Thème ───
final isDarkModeProvider = StateProvider<bool>((ref) => true);
final themeSeedProvider = StateProvider<int>((ref) => 0xFF6750A4);
final kidsModeProvider = StateProvider<bool>((ref) => false);

// ─── Audio Handler (arrière-plan) ───
class GiovaAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final _playlist = ConcatenatingAudioSource(children: []);

  GiovaAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.durationStream.listen((d) {
      if (d != null && mediaItem.value != null) {
        mediaItem.add(mediaItem.value!.copyWith(duration: d));
      }
    });
    _initAudioSession();
  }

  Future<void> _initAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    session.interruptionEventStream.listen((event) {
      if (event.beginning) _player.pause();
    });
    session.becomingNoisyEventStream.listen((_) => _player.pause());
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: _mapProcessingState(_player.processingState),
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    return switch (state) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };
  }

  Future<void> setPlaylist(List<MediaFile> files, {int startIndex = 0}) async {
    final sources = files.map((f) => AudioSource.uri(
      Uri.file(f.path),
      tag: MediaItem(
        id: f.path,
        title: f.displayName,
        artist: f.artistDisplay,
        album: f.album ?? '',
        duration: f.durationMs != null ? Duration(milliseconds: f.durationMs!) : null,
      ),
    )).toList();

    await _playlist.clear();
    await _playlist.addAll(sources);
    await _player.setAudioSource(_playlist, initialIndex: startIndex, initialPosition: Duration.zero);
    queue.add(sources.map((s) => s.tag as MediaItem).toList());
    if (sources.isNotEmpty) mediaItem.add(sources[startIndex].tag as MediaItem);
  }

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() async { await _player.stop(); await super.stop(); }
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) {
    _player.setLoopMode(switch(repeatMode) {
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.one => LoopMode.one,
      _ => LoopMode.off,
    });
    return Future.value();
  }
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode mode) async {
    await _player.setShuffleModeEnabled(mode == AudioServiceShuffleMode.all);
  }

  AudioPlayer get player => _player;
  Future<void> dispose() async { await _player.dispose(); }
}

// ─── Audio Providers ───
final audioHandlerProvider = FutureProvider<GiovaAudioHandler>((ref) async {
  final handler = await AudioService.init<GiovaAudioHandler>(
    builder: () => GiovaAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.giovaplayer.giova_player.audio',
      androidNotificationChannelName: 'GiovaPlayer Audio',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    ),
  );
  ref.onDispose(() => handler.dispose());
  return handler;
});

final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final handlerAsync = ref.watch(audioHandlerProvider);
  return handlerAsync.when(
    data: (handler) => handler.player,
    loading: () => AudioPlayer(),
    error: (_, __) => AudioPlayer(),
  );
});

final audioVolumeProvider = StateProvider<double>((ref) => 0.8);
final audioSpeedProvider = StateProvider<double>((ref) => 1.0);
final audioCurrentIndexProvider = StateProvider<int>((ref) => 0);
final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<int>((ref) => 0);
final audioPlaylistProvider = StateProvider<List<MediaFile>>((ref) => []);
final favoritePathsProvider = StateProvider<Set<String>>((ref) => {});

// ─── Video ───
final videoPlayingProvider = StateProvider<bool>((ref) => false);
final videoProgressProvider = StateProvider<double>((ref) => 0.0);
