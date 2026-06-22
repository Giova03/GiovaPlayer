import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN LECTEUR AUDIO GIOVAPLAYER ───
/// Interface complète du lecteur avec intégration just_audio
/// En production : remplacer _DummyAudioPlayer par AudioPlayer de just_audio

/// Provider du lecteur audio
final audioPlayerProvider = StateNotifierProvider<AudioPlayerNotifier, AudioState>((ref) {
  return AudioPlayerNotifier();
});

class AudioState {
  final bool isPlaying;
  final double progress;
  final double volume;
  final double speed;
  final int currentTrackIndex;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeatMode;

  const AudioState({
    this.isPlaying = false,
    this.progress = 0.0,
    this.volume = 0.8,
    this.speed = 1.0,
    this.currentTrackIndex = 0,
    this.position = Duration.zero,
    this.duration = const Duration(minutes: 3, seconds: 58),
    this.shuffle = false,
    this.repeatMode = RepeatMode.off,
  });

  AudioState copyWith({
    bool? isPlaying,
    double? progress,
    double? volume,
    double? speed,
    int? currentTrackIndex,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    RepeatMode? repeatMode,
  }) {
    return AudioState(
      isPlaying: isPlaying ?? this.isPlaying,
      progress: progress ?? this.progress,
      volume: volume ?? this.volume,
      speed: speed ?? this.speed,
      currentTrackIndex: currentTrackIndex ?? this.currentTrackIndex,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeatMode: repeatMode ?? this.repeatMode,
    );
  }
}

enum RepeatMode { off, all, one }

class AudioPlayerNotifier extends StateNotifier<AudioState> {
  AudioPlayerNotifier() : super(const AudioState());

  /// Lecture/pause
  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  /// Seek à une position
  void seek(double progress) {
    final pos = Duration(
      milliseconds: (state.duration.inMilliseconds * progress).round(),
    );
    state = state.copyWith(progress: progress, position: pos);
  }

  /// Volume
  void setVolume(double v) => state = state.copyWith(volume: v);

  /// Vitesse
  void setSpeed(double s) => state = state.copyWith(speed: s);

  /// Piste suivante
  void nextTrack() {
    final next = (state.currentTrackIndex + 1) % 8;
    state = state.copyWith(currentTrackIndex: next, progress: 0.0, position: Duration.zero);
  }

  /// Piste précédente
  void prevTrack() {
    final prev = (state.currentTrackIndex - 1).clamp(0, 7);
    state = state.copyWith(currentTrackIndex: prev, progress: 0.0, position: Duration.zero);
  }

  /// Shuffle
  void toggleShuffle() => state = state.copyWith(shuffle: !state.shuffle);

  /// Repeat
  void toggleRepeat() {
    final modes = RepeatMode.values;
    final idx = modes.indexOf(state.repeatMode);
    state = state.copyWith(repeatMode: modes[(idx + 1) % modes.length]);
  }
}

/// ─── ÉCRAN PRINCIPAL AUDIO ───
class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});

  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen>
    with TickerProviderStateMixin {
  late TabController _tabCtrl;

  final _tracks = [
    ('Ambiance Nocturne', 'DJ Giova', 'FLAC 24bit/96kHz', 128.0, '-3.2dB'),
    ('Soleil Levant', 'Ama Giova', 'FLAC 24bit/192kHz', 95.0, '-2.8dB'),
    ('Rythme Urbain', 'DJ Giova', 'DSF 1bit/2.8MHz', 140.0, '-4.1dB'),
    ('Mélodie Douce', 'Orchestre Bamo', 'FLAC 16bit/44.1kHz', 72.0, '-1.5dB'),
    ('Afro Beat', 'Giova Crew', 'WAV 24bit/48kHz', 110.0, '-3.8dB'),
    ('Solitude', 'Piano Giova', 'FLAC 24bit/96kHz', 88.0, '-2.2dB'),
    ('Énergie Pure', 'DJ Giova', 'MP3 320kbps', 135.0, '-5.0dB'),
    ('Horizon', 'Ama Giova', 'FLAC 24bit/96kHz', 120.0, '-3.5dB'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audio = ref.watch(audioPlayerProvider);
    final track = _tracks[audio.currentTrackIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Hi-Res'),
        actions: [
          IconButton(icon: const Icon(Icons.cast), onPressed: _showCast, tooltip: 'Cast'),
          IconButton(icon: const Icon(Icons.graphic_eq), onPressed: _showEq, tooltip: 'Égaliseur'),
          IconButton(icon: const Icon(Icons.timer), onPressed: _showSleepTimer, tooltip: 'Minuterie'),
        ],
        bottom: TabBar(controller: _tabCtrl, tabs: const [
          Tab(text: 'Lecteur'), Tab(text: 'Paroles'), Tab(text: 'Bibliothèque'),
        ]),
      ),
      body: TabBarView(controller: _tabCtrl, children: [
        _buildPlayer(cs, audio, track),
        _buildLyrics(cs),
        _buildLibrary(cs),
      ]),
    );
  }

  Widget _buildPlayer(ColorScheme cs, AudioState audio, (String, String, String, double, String) track) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        /// Pochette avec animation
        Container(
          width: 240, height: 240,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: cs.surfaceContainerHighest,
            boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Center(child: Icon(Icons.album, size: 80, color: cs.primary)),
        ),
        const SizedBox(height: 24),

        /// Info piste
        Text(track.$1, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('${track.$2} • ${track.$3}', style: TextStyle(color: cs.onSurfaceVariant)),

        /// Favori + Partage
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.playlist_add), onPressed: () {}),
        ]),
        const SizedBox(height: 16),

        /// Barre de progression
        Slider(
          value: audio.progress,
          onChanged: (v) => ref.read(audioPlayerProvider.notifier).seek(v),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(_formatDuration(audio.position), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
            Text(_formatDuration(audio.duration), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 8),

        /// Contrôles principaux
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
            icon: Icon(Icons.shuffle, color: audio.shuffle ? cs.primary : null),
            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleShuffle(),
          ),
          IconButton(icon: const Icon(Icons.skip_previous, size: 36),
            onPressed: () => ref.read(audioPlayerProvider.notifier).prevTrack()),
          const SizedBox(width: 8),
          FloatingActionButton.large(
            onPressed: () => ref.read(audioPlayerProvider.notifier).togglePlay(),
            child: Icon(audio.isPlaying ? Icons.pause : Icons.play_arrow, size: 40),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.skip_next, size: 36),
            onPressed: () => ref.read(audioPlayerProvider.notifier).nextTrack()),
          IconButton(
            icon: Icon(_repeatIcon(audio.repeatMode),
              color: audio.repeatMode != RepeatMode.off ? cs.primary : null),
            onPressed: () => ref.read(audioPlayerProvider.notifier).toggleRepeat(),
          ),
        ]),
        const SizedBox(height: 16),

        /// Volume + BPM + ReplayGain
        Row(children: [
          const Icon(Icons.volume_down, size: 20),
          Expanded(child: Slider(
            value: audio.volume,
            onChanged: (v) => ref.read(audioPlayerProvider.notifier).setVolume(v),
          )),
          const Icon(Icons.volume_up, size: 20),
          const SizedBox(width: 12),
          Chip(avatar: const Icon(Icons.speed, size: 16), label: Text('${track.$4.round()} BPM')),
          const SizedBox(width: 8),
          Chip(avatar: const Icon(Icons.equalizer, size: 16), label: Text('RG ${track.$5}')),
        ]),
        const SizedBox(height: 8),

        /// Vitesse de lecture
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('Vitesse', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(width: 8),
          ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text('${s}x', style: const TextStyle(fontSize: 11)),
              selected: audio.speed == s,
              onSelected: (_) => ref.read(audioPlayerProvider.notifier).setSpeed(s),
            ),
          )),
        ]),
      ]),
    );
  }

  IconData _repeatIcon(RepeatMode mode) => switch (mode) {
    RepeatMode.off => Icons.repeat,
    RepeatMode.all => Icons.repeat,
    RepeatMode.one => Icons.repeat_one,
  };

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildLyrics(ColorScheme cs) {
    return Padding(padding: const EdgeInsets.all(24), child: Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        FilterChip(label: const Text('Karaoké'), selected: false, onSelected: (_) {}),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Traduction'), selected: false, onSelected: (_) {}),
        const SizedBox(width: 8),
        FilterChip(label: const Text('Éditer'), selected: false, onSelected: (_) {}),
      ]),
      const SizedBox(height: 24),
      Expanded(child: ListView(children: [
        _lyricLine('Paroles synchronisées LRC', true, cs),
        _lyricLine('Surlignées en temps réel', false, cs),
        _lyricLine('Traduction disponible en bas', false, cs),
        _lyricLine('Glissez pour changer de langue', false, cs),
        _lyricLine('Mode karaoké avec suivi vocal', false, cs),
        _lyricLine('Export SRT / LRC possible', false, cs),
        _lyricLine('Recherche paroles en ligne si absent', false, cs),
        _lyricLine('Synchronisation auto via IA', false, cs),
      ])),
    ]));
  }

  Widget _lyricLine(String text, bool active, ColorScheme cs) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text, textAlign: TextAlign.center,
        style: TextStyle(fontSize: active ? 20 : 16, fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? cs.primary : cs.onSurfaceVariant)));
  }

  Widget _buildLibrary(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      TextField(decoration: InputDecoration(hintText: 'Rechercher morceaux, artistes...',
        prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)))),
      const SizedBox(height: 16),
      SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal,
        children: ['Tout', 'Rock', 'Jazz', 'Électro', 'Classique', 'Hip-Hop', 'Pop', 'R&B', 'Afro']
          .map((g) => Padding(padding: const EdgeInsets.only(right: 8),
            child: FilterChip(label: Text(g), onSelected: (_) {}))).toList())),
      const SizedBox(height: 16),
      ...List.generate(_tracks.length, (i) => ListTile(
        leading: Container(width: 48, height: 48,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.music_note, color: cs.primary)),
        title: Text(_tracks[i].$1),
        subtitle: Text('${_tracks[i].$2} • ${_tracks[i].$3}'),
        trailing: PopupMenuButton(itemBuilder: (_) => [
          const PopupMenuItem(value: 'tags', child: Text('Éditer tags')),
          const PopupMenuItem(value: 'lyrics', child: Text('Chercher paroles')),
          const PopupMenuItem(value: 'bpm', child: Text('Détection BPM')),
          const PopupMenuItem(value: 'ringtone', child: Text('Définir sonnerie')),
          const PopupMenuItem(value: 'info', child: Text('Infos fichier')),
        ]),
        onTap: () => ref.read(audioPlayerProvider.notifier).seek(0.0),
      )),
    ]);
  }

  void _showCast() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Diffuser vers...', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      ListTile(leading: const Icon(Icons.speaker), title: const Text('Enceinte Salon'), subtitle: const Text('Chromecast Audio • FLAC'), onTap: () => Navigator.pop(context)),
      ListTile(leading: const Icon(Icons.airplay), title: const Text('Apple TV'), subtitle: const Text('AirPlay • AAC'), onTap: () => Navigator.pop(context)),
      ListTile(leading: const Icon(Icons.bluetooth), title: const Text('Sony WH-1000XM5'), subtitle: const Text('Bluetooth LDAC'), onTap: () => Navigator.pop(context)),
      const Divider(),
      SwitchListTile(title: const Text('Double écoute BT'), subtitle: const Text('Synchroniser 2 appareils'), value: false, onChanged: (_) {}),
    ]));
  }

  void _showEq() {
    showModalBottomSheet(context: context, isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(initialChildSize: 0.6, maxChildSize: 0.9, expand: false,
        builder: (ctx, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
          Text('Égaliseur 32 bandes', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Presets IA détectés : Rock', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          const SizedBox(height: 16),
          SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal,
            children: ['Auto IA', 'Flat', 'Rock', 'Jazz', 'Classique', 'Bass Boost', 'Vocal Boost', 'Treble']
              .map((p) => Padding(padding: const EdgeInsets.only(right: 8),
                child: FilterChip(label: Text(p), onSelected: (_) {}))).toList())),
          const SizedBox(height: 24),
          SizedBox(height: 180, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(32, (i) {
              final h = [0.6,0.7,0.75,0.8,0.85,0.9,0.88,0.82,0.78,0.72,0.68,0.65,0.6,0.58,0.55,0.53,0.5,0.52,0.55,0.58,0.6,0.62,0.58,0.55,0.5,0.48,0.45,0.42,0.4,0.38,0.35,0.32][i];
              return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Container(height: h * 140, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))));
            }))),
          const SizedBox(height: 24),
          SwitchListTile(title: const Text('ReplayGain Auto'), subtitle: const Text('Normalise le volume'), value: true, onChanged: (_) {}),
          SwitchListTile(title: const Text('Gapless Playback'), subtitle: const Text('Sans silence entre morceaux'), value: true, onChanged: (_) {}),
          SwitchListTile(title: const Text('Crossfade'), subtitle: const Text('Fondu entre morceaux (3s)'), value: false, onChanged: (_) {}),
        ])));
  }

  void _showSleepTimer() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Minuterie sommeil', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      ...[('15 min', 15), ('30 min', 30), ('45 min', 45), ('60 min', 60), ('90 min', 90), ('Fin du morceau', -1)]
        .map((t) => ListTile(title: Text(t.$1), trailing: Radio(value: t.$2, groupValue: null, onChanged: (_) {}), onTap: () {})),
    ]));
  }
}
