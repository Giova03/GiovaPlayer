import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/file_scanner.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});
  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> with TickerProviderStateMixin {
  late TabController _tc;
  String _searchQuery = '';
  String _genreFilter = 'Tout';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    // Lancer le scan
    Future.microtask(() => ref.read(audioFilesProvider));
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audioFilesAsync = ref.watch(audioFilesProvider);
    final currentIndex = ref.watch(audioCurrentIndexProvider);
    final speed = ref.watch(audioSpeedProvider);
    final player = ref.watch(audioPlayerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Hi-Res'),
        actions: [
          IconButton(icon: const Icon(Icons.graphic_eq), onPressed: _eq, tooltip: 'EQ'),
          IconButton(icon: const Icon(Icons.timer), onPressed: _timer, tooltip: 'Minuterie'),
        ],
        bottom: TabBar(controller: _tc, tabs: const [
          Tab(text: 'Bibliothèque'),
          Tab(text: 'Lecteur'),
          Tab(text: 'Favoris'),
        ]),
      ),
      body: audioFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _buildError(e, cs),
        data: (files) => TabBarView(controller: _tc, children: [
          _buildLibrary(files, cs, player),
          _buildPlayer(files, cs, player, currentIndex, speed),
          _buildFavorites(files, cs, player),
        ]),
      ),
    );
  }

  Widget _buildError(Object e, ColorScheme cs) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(Icons.error_outline, size: 64, color: cs.error),
      const SizedBox(height: 16),
      Text('Erreur de scan', style: TextStyle(color: cs.error, fontSize: 18)),
      const SizedBox(height: 8),
      Text('$e', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: () => ref.invalidate(audioFilesProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('Réessayer'),
      ),
    ],
  ));

  // ─── BIBLIOTHÈQUE ───
  Widget _buildLibrary(List<MediaFile> files, ColorScheme cs, AudioPlayer player) {
    final filtered = files.where((f) {
      if (_searchQuery.isNotEmpty && !f.displayName.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Column(children: [
      Padding(padding: const EdgeInsets.all(12),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Rechercher morceaux...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
      ),
      if (files.isEmpty)
        Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.music_note, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Aucun fichier audio trouvé'),
          const SizedBox(height: 8),
          Text('Vérifiez les permissions de stockage', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 16),
          FilledButton.icon(onPressed: () => ref.invalidate(audioFilesProvider),
            icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
        ])))
      else
        Expanded(child: ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final f = filtered[i];
            final ext = f.extension.toUpperCase().replaceAll('.', '');
            return ListTile(
              leading: Container(width: 48, height: 48,
                decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.music_note, color: cs.primary)),
              title: Text(f.displayName, style: const TextStyle(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('$ext • ${f.sizeFormatted}', style: const TextStyle(fontSize: 12)),
              trailing: IconButton(icon: const Icon(Icons.play_circle_filled), onPressed: () => _playFile(player, files, i)),
              onTap: () => _playFile(player, files, i),
            );
          },
        )),
    ]);
  }

  // ─── LECTEUR ───
  Widget _buildPlayer(List<MediaFile> files, ColorScheme cs, AudioPlayer player, int currentIndex, double speed) {
    if (files.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.music_note, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        const Text('Sélectionnez un morceau'),
      ]));
    }

    final track = currentIndex < files.length ? files[currentIndex] : files.first;

    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      // Pochette
      Container(width: 220, height: 220,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: cs.surfaceContainerHighest,
          boxShadow: [BoxShadow(color: cs.primary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Icon(Icons.album, size: 72, color: cs.primary)),
      const SizedBox(height: 20),
      Text(track.displayName, style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text('${track.extension.toUpperCase().replaceAll('.', '')} • ${track.sizeFormatted}',
        style: TextStyle(color: cs.onSurfaceVariant)),
      // Progression
      const SizedBox(height: 16),
      StreamBuilder<Duration?>(
        stream: player.positionStream,
        builder: (_, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          return StreamBuilder<Duration?>(
            stream: player.durationStream,
            builder: (_, durSnap) {
              final dur = durSnap.data ?? Duration.zero;
              final progress = dur.inMilliseconds > 0 ? pos.inMilliseconds / dur.inMilliseconds : 0.0;
              return Column(children: [
                Slider(value: progress.clamp(0.0, 1.0),
                  onChanged: (v) {
                    final ms = (v * dur.inMilliseconds).round();
                    player.seek(Duration(milliseconds: ms));
                  }),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                    Text(_fmt(dur), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ])),
              ]);
            });
        }),
      // Contrôles
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: Icon(Icons.shuffle,
          color: ref.watch(audioShuffleProvider) ? cs.primary : null),
          onPressed: () {
            final val = !ref.read(audioShuffleProvider);
            ref.read(audioShuffleProvider.notifier).state = val;
            player.setShuffleModeEnabled(val);
          }),
        IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () {
          if (currentIndex > 0) {
            ref.read(audioCurrentIndexProvider.notifier).state = currentIndex - 1;
            _playFile(player, files, currentIndex - 1);
          }
        }),
        const SizedBox(width: 8),
        StreamBuilder<bool>(
          stream: player.playingStream,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return FloatingActionButton.large(
              onPressed: () {
                if (playing) {
                  player.pause();
                } else {
                  if (player.currentIndex == null) {
                    _playFile(player, files, currentIndex);
                  } else {
                    player.play();
                  }
                }
              },
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40),
            );
          }),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () {
          if (currentIndex < files.length - 1) {
            ref.read(audioCurrentIndexProvider.notifier).state = currentIndex + 1;
            _playFile(player, files, currentIndex + 1);
          }
        }),
        IconButton(icon: Icon(
          [Icons.repeat, Icons.repeat, Icons.repeat_one][ref.watch(audioRepeatProvider)],
          color: ref.watch(audioRepeatProvider) > 0 ? cs.primary : null),
          onPressed: () {
            final val = (ref.read(audioRepeatProvider) + 1) % 3;
            ref.read(audioRepeatProvider.notifier).state = val;
            player.setLoopMode([LoopMode.off, LoopMode.all, LoopMode.one][val]);
          }),
      ]),
      // Vitesse
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) =>
          Padding(padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text('${s}x', style: const TextStyle(fontSize: 10)),
              selected: speed == s,
              onSelected: (_) {
                ref.read(audioSpeedProvider.notifier).state = s;
                player.setSpeed(s);
              }))).toList()),
      // Volume
      const SizedBox(height: 12),
      Row(children: [
        const Icon(Icons.volume_down, size: 18),
        Expanded(child: Slider(
          value: ref.watch(audioVolumeProvider),
          onChanged: (v) {
            ref.read(audioVolumeProvider.notifier).state = v;
            player.setVolume(v);
          })),
        const Icon(Icons.volume_up, size: 18),
      ]),
    ]);
  }

  // ─── FAVORIS ───
  Widget _buildFavorites(List<MediaFile> files, ColorScheme cs, AudioPlayer player) {
    // Pour l'instant, placeholder
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.favorite_border, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
      const SizedBox(height: 16),
      const Text('Aucun favori'),
      const SizedBox(height: 8),
      Text('Appuyez sur ♡ pour ajouter', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
    ]));
  }

  Future<void> _playFile(AudioPlayer player, List<MediaFile> files, int index) async {
    if (index < 0 || index >= files.length) return;
    ref.read(audioCurrentIndexProvider.notifier).state = index;
    try {
      final file = files[index];
      await player.setFilePath(file.path);
      await player.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _eq() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Égaliseur', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
      children: ['Flat', 'Rock', 'Jazz', 'Classique', 'Bass+', 'Vocal+', 'Treble'].map((p) =>
        Padding(padding: const EdgeInsets.only(right: 6),
          child: FilterChip(label: Text(p), onSelected: (_){}))).toList())),
    const SizedBox(height: 20),
    SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(10, (i) {
        final h = [0.6, 0.7, 0.8, 0.85, 0.9, 0.88, 0.78, 0.68, 0.55, 0.4][i];
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(height: h * 120, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))),
        ));
      }))),
    const SizedBox(height: 20),
    SwitchListTile(title: const Text('ReplayGain Auto'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Gapless Playback'), value: true, onChanged: (_){}),
  ]));

  void _timer() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Minuterie sommeil', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    ...['15 min', '30 min', '45 min', '60 min', '90 min', 'Fin du morceau'].map((t) =>
      ListTile(title: Text(t), onTap: () => Navigator.pop(context))),
  ]));
}
