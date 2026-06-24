import 'dart:async';
import 'dart:io';
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
  String _search = '';

  @override
  void initState() { super.initState(); _tc = TabController(length: 4, vsync: this); }
  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filesAsync = ref.watch(audioFilesProvider);
    final playlist = ref.watch(audioPlaylistProvider);
    final idx = ref.watch(audioCurrentIndexProvider);
    final player = ref.watch(audioPlayerProvider);

    return Scaffold(appBar: AppBar(title: const Text('Audio Hi-Res'),
      actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(audioFilesProvider))],
      bottom: TabBar(controller: _tc, isScrollable: true, tabs: const [
        Tab(text: 'Bibliothèque'), Tab(text: 'Dossiers'), Tab(text: 'Lecteur'), Tab(text: 'Favoris'),
      ])),
      body: filesAsync.when(loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: FilledButton(onPressed: () => ref.invalidate(audioFilesProvider), child: Text('Erreur: $e'))),
        data: (files) => Column(children: [
          Expanded(child: TabBarView(controller: _tc, children: [
            _library(files, cs, player), _folders(files, cs, player), _player(files, cs, player, idx, playlist), _favorites(files, cs, player),
          ])),
          if (playlist.isNotEmpty) _miniPlayer(cs, player, idx, playlist),
        ])),
    );
  }

  // BIBLIOTHEQUE
  Widget _library(List<MediaFile> files, ColorScheme cs, AudioPlayer player) => Column(children: [
    Padding(padding: const EdgeInsets.all(8), child: TextField(decoration: InputDecoration(
      hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
    ), onChanged: (v) => setState(() => _search = v))),
    Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [
      Text('${files.length} morceaux', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const Spacer(),
      TextButton.icon(onPressed: () => _playAll(files, 0), icon: const Icon(Icons.play_circle, size: 16), label: const Text('Tout lire')),
      TextButton.icon(onPressed: () { final s = List<MediaFile>.from(files)..shuffle(); _playAll(s, 0); }, icon: const Icon(Icons.shuffle, size: 16), label: const Text('Aléatoire')),
    ])),
    Expanded(child: ListView.builder(itemCount: files.length, itemBuilder: (_, i) {
      final f = files[i];
      if (_search.isNotEmpty && !f.displayName.toLowerCase().contains(_search.toLowerCase()) && !f.artistDisplay.toLowerCase().contains(_search.toLowerCase())) return const SizedBox.shrink();
      final isCur = ref.watch(audioCurrentIndexProvider) == i && ref.watch(audioPlaylistProvider).isNotEmpty;
      return ListTile(selected: isCur, leading: Container(width: 44, height: 44,
        decoration: BoxDecoration(color: isCur ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: Icon(isCur ? Icons.equalizer : Icons.music_note, color: isCur ? cs.primary : cs.onSurfaceVariant, size: 22)),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: isCur ? FontWeight.w700 : FontWeight.normal)),
        subtitle: Text('${f.artistDisplay} • ${f.sizeFormatted}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        trailing: IconButton(icon: const Icon(Icons.play_circle_filled), onPressed: () => _playFile(files, i)),
        onTap: () => _playFile(files, i));
    })),
  ]);

  // DOSSIERS
  Widget _folders(List<MediaFile> files, ColorScheme cs, AudioPlayer player) {
    final scanner = ref.read(fileScannerProvider);
    final folders = scanner.getFilesByFolder('audio');
    return ListView(children: folders.entries.map((e) => ExpansionTile(
      leading: Icon(Icons.folder, color: cs.primary), title: Text(e.key), subtitle: Text('${e.value.length} morceaux'),
      children: e.value.map((f) => ListTile(
        leading: const Icon(Icons.music_note, size: 20), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(f.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
        onTap: () => _playFile(e.value, e.value.indexOf(f)),
      )).toList(),
    )).toList());
  }

  // LECTEUR
  Widget _player(List<MediaFile> files, ColorScheme cs, AudioPlayer player, int idx, List<MediaFile> playlist) {
    final speed = ref.watch(audioSpeedProvider);
    if (playlist.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.music_note, size: 80, color: cs.primary.withOpacity(0.3)), const SizedBox(height: 20),
      const Text('Sélectionnez un morceau', style: TextStyle(fontSize: 18)),
    ]));
    final track = idx < playlist.length ? playlist[idx] : playlist.first;
    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      Container(width: 220, height: 220, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: cs.surfaceContainerHighest,
        boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Icon(Icons.album, size: 72, color: cs.primary)),
      const SizedBox(height: 20),
      Text(track.displayName, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4), Text(track.artistDisplay, style: TextStyle(color: cs.onSurfaceVariant)),
      const SizedBox(height: 4), Chip(avatar: const Icon(Icons.high_quality, size: 14), label: Text(track.extension.toUpperCase().replaceAll('.', ''))),
      const SizedBox(height: 16),
      StreamBuilder<Duration?>(stream: player.positionStream, builder: (_, posSnap) {
        final pos = posSnap.data ?? Duration.zero;
        return StreamBuilder<Duration?>(stream: player.durationStream, builder: (_, durSnap) {
          final dur = durSnap.data ?? Duration.zero;
          final p = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
          return Column(children: [
            Slider(value: p, onChanged: (v) => player.seek(Duration(milliseconds: (v * dur.inMilliseconds).round()))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text(_fmt(pos), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                Text(_fmt(dur), style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant))])),
          ]);
        });
      }),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(icon: Icon(Icons.shuffle, color: ref.watch(audioShuffleProvider) ? cs.primary : null),
          onPressed: () { final v = !ref.read(audioShuffleProvider); ref.read(audioShuffleProvider.notifier).state = v; player.setShuffleModeEnabled(v); }),
        IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () => _skip(idx - 1)),
        StreamBuilder<bool>(stream: player.playingStream, builder: (_, s) {
          final playing = s.data ?? false;
          return FloatingActionButton.large(onPressed: () => playing ? player.pause() : _resumePlay(player, playlist, idx),
            child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40));
        }),
        IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () => _skip(idx + 1)),
        IconButton(icon: Icon([Icons.repeat, Icons.repeat, Icons.repeat_one][ref.watch(audioRepeatProvider)],
          color: ref.watch(audioRepeatProvider) > 0 ? cs.primary : null),
          onPressed: () { final v = (ref.read(audioRepeatProvider) + 1) % 3; ref.read(audioRepeatProvider.notifier).state = v;
            player.setLoopMode([LoopMode.off, LoopMode.all, LoopMode.one][v]); }),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) =>
        Padding(padding: const EdgeInsets.only(right: 4), child: ChoiceChip(label: Text('${s}x', style: const TextStyle(fontSize: 10)),
          selected: speed == s, onSelected: (_) { ref.read(audioSpeedProvider.notifier).state = s; player.setSpeed(s); }))).toList()),
      const SizedBox(height: 8),
      Row(children: [const Icon(Icons.volume_down, size: 18), Expanded(child: Slider(value: ref.watch(audioVolumeProvider),
        onChanged: (v) { ref.read(audioVolumeProvider.notifier).state = v; player.setVolume(v); })), const Icon(Icons.volume_up, size: 18)]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(icon: const Icon(Icons.favorite_border), onPressed: () => _toggleFav(track)),
        IconButton.filledTonal(icon: const Icon(Icons.info), onPressed: () => _showInfo(track)),
        IconButton.filledTonal(icon: const Icon(Icons.graphic_eq), onPressed: _eq),
        IconButton.filledTonal(icon: const Icon(Icons.timer), onPressed: _timer),
      ]),
    ]));
  }

  // FAVORIS
  Widget _favorites(List<MediaFile> files, ColorScheme cs, AudioPlayer player) {
    final favs = files.where((f) => ref.watch(favoritePathsProvider).contains(f.path)).toList();
    if (favs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.favorite_border, size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)), const SizedBox(height: 16), const Text('Aucun favori'),
    ]));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Text('${favs.length} favoris', style: TextStyle(color: cs.onSurfaceVariant)),
        const Spacer(), TextButton.icon(onPressed: () => _playAll(favs, 0), icon: const Icon(Icons.play_circle, size: 16), label: const Text('Tout lire')),
      ])),
      Expanded(child: ListView.builder(itemCount: favs.length, itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.favorite, color: Colors.red), title: Text(favs[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(favs[i].artistDisplay, style: const TextStyle(fontSize: 12)),
        onTap: () => _playFile(favs, i), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _toggleFav(favs[i])),
      ))),
    ]);
  }

  // MINI PLAYER
  Widget _miniPlayer(ColorScheme cs, AudioPlayer player, int idx, List<MediaFile> playlist) {
    final track = idx < playlist.length ? playlist[idx] : playlist.first;
    return Container(decoration: BoxDecoration(color: cs.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        StreamBuilder<Duration?>(stream: player.positionStream, builder: (_, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          return StreamBuilder<Duration?>(stream: player.durationStream, builder: (_, durSnap) {
            final dur = durSnap.data ?? Duration.zero;
            final p = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
            return LinearProgressIndicator(value: p, minHeight: 2, backgroundColor: cs.surfaceContainerHighest);
          });
        }),
        ListTile(dense: true, leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.music_note, color: cs.primary)),
          title: Text(track.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(track.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.skip_previous, size: 20), onPressed: () => _skip(idx - 1)),
            StreamBuilder<bool>(stream: player.playingStream, builder: (_, s) {
              final playing = s.data ?? false;
              return IconButton(icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, size: 32, color: cs.primary),
                onPressed: () => playing ? player.pause() : player.play());
            }),
            IconButton(icon: const Icon(Icons.skip_next, size: 20), onPressed: () => _skip(idx + 1)),
          ]),
          onTap: () => _tc.animateTo(2)),
      ]),
    );
  }

  // ACTIONS
  Future<void> _playFile(List<MediaFile> files, int index) async {
    if (index < 0 || index >= files.length) return;
    ref.read(audioCurrentIndexProvider.notifier).state = index;
    ref.read(audioPlaylistProvider.notifier).state = files;
    final player = ref.read(audioPlayerProvider);
    try { await player.setFilePath(files[index].path); await player.play();
      final recent = List<MediaFile>.from(ref.read(recentlyPlayedProvider));
      recent.removeWhere((f) => f.path == files[index].path); recent.insert(0, files[index]);
      if (recent.length > 50) recent.removeRange(50, recent.length);
      ref.read(recentlyPlayedProvider.notifier).state = recent;
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }
  }

  Future<void> _playAll(List<MediaFile> files, int start) async => _playFile(files, start);
  Future<void> _resumePlay(AudioPlayer p, List<MediaFile> pl, int idx) async {
    if (p.processingState == ProcessingState.idle) { await _playFile(pl, idx); } else { await p.play(); }
  }
  void _skip(int i) { final pl = ref.read(audioPlaylistProvider); if (pl.isNotEmpty) _playFile(pl, i.clamp(0, pl.length - 1)); }
  void _toggleFav(MediaFile f) { final favs = Set<String>.from(ref.read(favoritePathsProvider)); favs.contains(f.path) ? favs.remove(f.path) : favs.add(f.path); ref.read(favoritePathsProvider.notifier).state = favs; }

  void _showInfo(MediaFile f) => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Informations', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
    ...[('Titre', f.displayName), ('Artiste', f.artistDisplay), ('Album', f.album ?? '-'), ('Format', f.extension.replaceAll('.', '').toUpperCase()), ('Taille', f.sizeFormatted), ('Chemin', f.path)]
      .map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 80, child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w600))), Expanded(child: Text(r.$2, style: const TextStyle(fontSize: 13)))]))),
  ]));

  String _fmt(Duration d) { final h = d.inHours; final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60); return h > 0 ? '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}' : '$m:${s.toString().padLeft(2,'0')}'; }

  void _eq() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Égaliseur', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
    SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: ['Flat','Rock','Jazz','Classique','Bass+','Vocal+','Treble','Électro','Acoustique'].map((p) =>
      Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: Text(p), onSelected: (_){}))).toList())),
    const SizedBox(height: 20),
    SizedBox(height: 120, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(10, (i) { final h = [0.6,0.7,0.8,0.85,0.9,0.88,0.78,0.68,0.55,0.4][i];
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(height: h * 100,
          decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2))))); }))),
    SwitchListTile(title: const Text('ReplayGain Auto'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Gapless'), value: true, onChanged: (_){}),
  ]));

  void _timer() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Minuterie sommeil', style: Theme.of(context).textTheme.titleLarge),
    ...['15 min','30 min','45 min','60 min','90 min','Fin du morceau'].map((t) => ListTile(title: Text(t), onTap: () => Navigator.pop(context))),
  ]));
}
