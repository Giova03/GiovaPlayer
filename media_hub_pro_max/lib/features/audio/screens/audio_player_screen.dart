import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
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
  String _folderFilter = 'Tout';
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    Future.microtask(() => ref.read(audioFilesProvider));
  }

  @override
  void dispose() {
    _tc.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audioFilesAsync = ref.watch(audioFilesProvider);
    final playlist = ref.watch(audioPlaylistProvider);
    final currentIndex = ref.watch(audioCurrentIndexProvider);
    final handlerAsync = ref.watch(audioHandlerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Hi-Res'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () {
            ref.invalidate(audioFilesProvider);
          }, tooltip: 'Rescanner'),
          IconButton(icon: const Icon(Icons.graphic_eq), onPressed: _eq, tooltip: 'Égaliseur'),
          IconButton(icon: const Icon(Icons.timer), onPressed: _timer, tooltip: 'Minuterie'),
        ],
        bottom: TabBar(controller: _tc, isScrollable: true, tabs: const [
          Tab(text: 'Bibliothèque', icon: Icon(Icons.library_music, size: 18)),
          Tab(text: 'Dossiers', icon: Icon(Icons.folder, size: 18)),
          Tab(text: 'Lecteur', icon: Icon(Icons.play_circle, size: 18)),
          Tab(text: 'Favoris', icon: Icon(Icons.favorite, size: 18)),
        ]),
      ),
      body: audioFilesAsync.when(
        loading: () => const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Scan des fichiers en cours...'),
        ])),
        error: (e, _) => _buildError(e, cs),
        data: (files) => Column(children: [
          Expanded(child: TabBarView(controller: _tc, children: [
            _buildLibrary(files, cs),
            _buildFolders(files, cs),
            _buildPlayer(files, cs, handlerAsync, currentIndex, playlist),
            _buildFavorites(files, cs),
          ])),
          // Mini-player persistant
          if (playlist.isNotEmpty) _buildMiniPlayer(cs, handlerAsync, currentIndex, playlist),
        ]),
      ),
    );
  }

  Widget _buildError(Object e, ColorScheme cs) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.error_outline, size: 64, color: cs.error),
      const SizedBox(height: 16),
      const Text('Erreur de scan'),
      const SizedBox(height: 16),
      FilledButton.icon(onPressed: () => ref.invalidate(audioFilesProvider),
        icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
    ],
  ));

  // ─── BIBLIOTHÈQUE ───
  Widget _buildLibrary(List<MediaFile> files, ColorScheme cs) {
    final filtered = files.where((f) {
      if (_searchQuery.isNotEmpty && !f.displayName.toLowerCase().contains(_searchQuery.toLowerCase())
        && !f.artistDisplay.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();

    return Column(children: [
      // Barre de recherche
      Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: TextField(decoration: InputDecoration(
          hintText: 'Rechercher artiste, titre...',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _searchQuery.isNotEmpty ? IconButton(
            icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchQuery = '')) : null,
          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        ), onChanged: (v) => setState(() => _searchQuery = v))),
      // Stats
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Text('${files.length} morceaux', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          const Spacer(),
          TextButton.icon(onPressed: () => _playAll(files, 0),
            icon: const Icon(Icons.play_circle, size: 16), label: const Text('Tout lire')),
          TextButton.icon(onPressed: () => _shuffleAll(files),
            icon: const Icon(Icons.shuffle, size: 16), label: const Text('Aléatoire')),
        ])),
      // Liste
      Expanded(child: filtered.isEmpty
        ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.music_off, size: 48, color: cs.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(_searchQuery.isEmpty ? 'Aucun fichier audio trouvé' : 'Aucun résultat'),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 8),
              FilledButton.icon(onPressed: () => ref.invalidate(audioFilesProvider),
                icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
            ],
          ]))
        : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
            final f = filtered[i];
            final isPlaying = ref.watch(audioCurrentIndexProvider) == files.indexOf(f)
              && ref.watch(audioPlaylistProvider).isNotEmpty;
            return ListTile(
              selected: isPlaying,
              leading: Container(width: 48, height: 48,
                decoration: BoxDecoration(color: isPlaying ? cs.primaryContainer : cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8)),
                child: isPlaying
                  ? Icon(Icons.equalizer, color: cs.primary)
                  : Icon(Icons.music_note, color: cs.onSurfaceVariant)),
              title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: isPlaying ? FontWeight.w700 : FontWeight.normal)),
              subtitle: Text('${f.artistDisplay} • ${f.sizeFormatted}', maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: PopupMenuButton(itemBuilder: (_) => [
                const PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Lire'))),
                const PopupMenuItem(value: 'next', child: ListTile(leading: Icon(Icons.queue_music), title: Text('Lire ensuite'))),
                const PopupMenuItem(value: 'fav', child: ListTile(leading: Icon(Icons.favorite_border), title: Text('Favori'))),
                const PopupMenuItem(value: 'info', child: ListTile(leading: Icon(Icons.info), title: Text('Détails'))),
                const PopupMenuItem(value: 'ringtone', child: ListTile(leading: Icon(Icons.notifications), title: Text('Sonnerie'))),
              ], onSelected: (v) => _onMenuAction(v, f, files)),
              onTap: () => _playFile(files, files.indexOf(f)),
            );
          }),
      ),
    ]);
  }

  // ─── DOSSIERS ───
  Widget _buildFolders(List<MediaFile> files, ColorScheme cs) {
    final scanner = ref.read(fileScannerProvider);
    final folders = scanner.getFilesByFolder('audio');
    if (folders.isEmpty) {
      return const Center(child: Text('Aucun dossier trouvé'));
    }
    return ListView(children: folders.entries.map((entry) => ExpansionTile(
      leading: Icon(Icons.folder, color: cs.primary),
      title: Text(entry.key),
      subtitle: Text('${entry.value.length} morceaux'),
      children: entry.value.map((f) => ListTile(
        leading: Container(width: 40, height: 40,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
          child: Icon(Icons.music_note, size: 20, color: cs.onSurfaceVariant)),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(f.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => _playFile(entry.value, entry.value.indexOf(f)),
      )).toList(),
    )).toList());
  }

  // ─── LECTEUR ───
  Widget _buildPlayer(List<MediaFile> files, ColorScheme cs, AsyncValue<GiovaAudioHandler> handlerAsync,
    int currentIndex, List<MediaFile> playlist) {
    final player = ref.watch(audioPlayerProvider);
    final speed = ref.watch(audioSpeedProvider);

    if (playlist.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.music_note, size: 80, color: cs.primary.withOpacity(0.3)),
        const SizedBox(height: 20),
        Text('Sélectionnez un morceau', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('Votre musique apparaîtra ici', style: TextStyle(color: cs.onSurfaceVariant)),
      ]));
    }

    final track = currentIndex < playlist.length ? playlist[currentIndex] : playlist.first;

    return SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(children: [
      // Pochette animée
      Container(width: 240, height: 240,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: cs.surfaceContainerHighest,
          gradient: LinearGradient(colors: [cs.primaryContainer, cs.surfaceContainerHighest],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: cs.primary.withOpacity(0.3), blurRadius: 30, offset: const Offset(0, 12))]),
        child: StreamBuilder<bool>(stream: player.playingStream,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return AnimatedContainer(duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
                border: playing ? Border.all(color: cs.primary, width: 3) : null),
              child: Icon(Icons.album, size: 80, color: cs.primary.withOpacity(0.7)));
          })),
      const SizedBox(height: 24),
      // Titre
      Text(track.displayName, style: Theme.of(context).textTheme.headlineSmall,
        textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      Text(track.artistDisplay, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15)),
      const SizedBox(height: 4),
      Chip(avatar: const Icon(Icons.high_quality, size: 14),
        label: Text('${track.extension.toUpperCase().replaceAll('.', '')} • ${track.sizeFormatted}'),
        visualDensity: VisualDensity.compact),
      // Progression
      const SizedBox(height: 20),
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
                SliderTheme(data: SliderThemeData(
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  trackHeight: 3,
                ), child: Slider(value: progress.clamp(0.0, 1.0),
                  onChanged: (v) => player.seek(Duration(milliseconds: (v * dur.inMilliseconds).round())))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(pos), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                    Text(_fmt(dur), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
                  ])),
              ]);
            });
        }),
      // Contrôles principaux
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        IconButton(icon: Icon(Icons.shuffle, size: 24,
          color: ref.watch(audioShuffleProvider) ? cs.primary : cs.onSurfaceVariant),
          onPressed: () {
            final val = !ref.read(audioShuffleProvider);
            ref.read(audioShuffleProvider.notifier).state = val;
            player.setShuffleModeEnabled(val);
          }),
        IconButton(icon: const Icon(Icons.skip_previous, size: 36),
          onPressed: () => _skipTo(currentIndex - 1)),
        StreamBuilder<bool>(stream: player.playingStream,
          builder: (_, snap) {
            final playing = snap.data ?? false;
            return Container(decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary),
              child: IconButton(iconSize: 40, color: cs.onPrimary,
                icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                onPressed: () => playing ? player.pause() : player.play()));
          }),
        IconButton(icon: const Icon(Icons.skip_next, size: 36),
          onPressed: () => _skipTo(currentIndex + 1)),
        IconButton(icon: Icon(
          [Icons.repeat, Icons.repeat, Icons.repeat_one][ref.watch(audioRepeatProvider)],
          size: 24, color: ref.watch(audioRepeatProvider) > 0 ? cs.primary : cs.onSurfaceVariant),
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
            child: ChoiceChip(label: Text('${s}x', style: const TextStyle(fontSize: 10)),
              selected: speed == s,
              onSelected: (_) {
                ref.read(audioSpeedProvider.notifier).state = s;
                player.setSpeed(s);
                handlerAsync.whenData((h) => h.setSpeed(s));
              }))).toList()),
      // Volume
      const SizedBox(height: 8),
      Row(children: [
        const Icon(Icons.volume_down, size: 18),
        Expanded(child: Slider(value: ref.watch(audioVolumeProvider),
          onChanged: (v) { ref.read(audioVolumeProvider.notifier).state = v; player.setVolume(v); })),
        const Icon(Icons.volume_up, size: 18),
      ]),
      // Actions
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton.filledTonal(icon: const Icon(Icons.favorite_border), onPressed: () => _toggleFav(track)),
        IconButton.filledTonal(icon: const Icon(Icons.share), onPressed: () {}),
        IconButton.filledTonal(icon: const Icon(Icons.playlist_add), onPressed: () {}),
        IconButton.filledTonal(icon: const Icon(Icons.info), onPressed: () => _showInfo(track)),
      ]),
    ]));
  }

  // ─── FAVORIS ───
  Widget _buildFavorites(List<MediaFile> files, ColorScheme cs) {
    final favPaths = ref.watch(favoritePathsProvider);
    final favs = files.where((f) => favPaths.contains(f.path)).toList();
    if (favs.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.favorite_border, size: 64, color: cs.onSurfaceVariant.withOpacity(0.4)),
        const SizedBox(height: 16),
        const Text('Aucun favori'),
        const SizedBox(height: 8),
        Text('Appuyez sur ♡ pour ajouter', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
      ]));
    }
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [
          Text('${favs.length} favoris', style: TextStyle(color: cs.onSurfaceVariant)),
          const Spacer(),
          TextButton.icon(onPressed: () => _playAll(favs, 0),
            icon: const Icon(Icons.play_circle, size: 16), label: const Text('Tout lire')),
        ])),
      Expanded(child: ListView.builder(itemCount: favs.length, itemBuilder: (_, i) => ListTile(
        leading: Container(width: 44, height: 44,
          decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.favorite, color: Colors.red)),
        title: Text(favs[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(favs[i].artistDisplay),
        onTap: () => _playFile(favs, i),
        trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _toggleFav(favs[i])),
      ))),
    ]);
  }

  // ─── MINI PLAYER ───
  Widget _buildMiniPlayer(ColorScheme cs, AsyncValue<GiovaAudioHandler> handlerAsync,
    int currentIndex, List<MediaFile> playlist) {
    if (playlist.isEmpty) return const SizedBox.shrink();
    final track = currentIndex < playlist.length ? playlist[currentIndex] : playlist.first;
    final player = ref.watch(audioPlayerProvider);

    return Container(decoration: BoxDecoration(
      color: ElevationOverlay.applySurfaceTint(cs.surface, cs.surfaceTint, 3),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, -2))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Barre de progression fine
        StreamBuilder<Duration?>(
          stream: player.positionStream,
          builder: (_, posSnap) {
            final pos = posSnap.data ?? Duration.zero;
            return StreamBuilder<Duration?>(
              stream: player.durationStream,
              builder: (_, durSnap) {
                final dur = durSnap.data ?? Duration.zero;
                final p = dur.inMilliseconds > 0 ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0) : 0.0;
                return LinearProgressIndicator(value: p, minHeight: 2, backgroundColor: cs.surfaceContainerHighest);
              });
          }),
        // Infos + contrôles
        ListTile(dense: true,
          leading: Container(width: 44, height: 44,
            decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.music_note, color: cs.primary)),
          title: Text(track.displayName, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(track.artistDisplay, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.skip_previous, size: 22),
              onPressed: () => _skipTo(currentIndex - 1)),
            StreamBuilder<bool>(stream: player.playingStream,
              builder: (_, snap) {
                final playing = snap.data ?? false;
                return IconButton(icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  size: 36, color: cs.primary),
                  onPressed: () => playing ? player.pause() : player.play());
              }),
            IconButton(icon: const Icon(Icons.skip_next, size: 22),
              onPressed: () => _skipTo(currentIndex + 1)),
          ]),
          onTap: () => _tc.animateTo(2), // Aller au lecteur
        ),
      ]),
    );
  }

  // ─── ACTIONS ───
  Future<void> _playFile(List<MediaFile> files, int index) async {
    if (index < 0 || index >= files.length) return;
    ref.read(audioCurrentIndexProvider.notifier).state = index;
    ref.read(audioPlaylistProvider.notifier).state = files;
    final player = ref.read(audioPlayerProvider);
    try {
      await player.setFilePath(files[index].path);
      await player.play();
      // Mettre à jour le handler audio pour l'arrière-plan
      ref.read(audioHandlerProvider).whenData((handler) async {
        await handler.setPlaylist(files, startIndex: index);
        await handler.play();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _playAll(List<MediaFile> files, int startIndex) async {
    await _playFile(files, startIndex);
  }

  Future<void> _shuffleAll(List<MediaFile> files) async {
    final shuffled = List<MediaFile>.from(files)..shuffle();
    await _playFile(shuffled, 0);
    ref.read(audioShuffleProvider.notifier).state = true;
    ref.read(audioPlayerProvider).setShuffleModeEnabled(true);
  }

  void _skipTo(int index) {
    final playlist = ref.read(audioPlaylistProvider);
    if (playlist.isEmpty) return;
    final newIndex = index.clamp(0, playlist.length - 1);
    _playFile(playlist, newIndex);
  }

  void _toggleFav(MediaFile f) {
    final favs = ref.read(favoritePathsProvider);
    final newFavs = Set<String>.from(favs);
    if (newFavs.contains(f.path)) {
      newFavs.remove(f.path);
    } else {
      newFavs.add(f.path);
    }
    ref.read(favoritePathsProvider.notifier).state = newFavs;
  }

  void _onMenuAction(String action, MediaFile file, List<MediaFile> allFiles) {
    switch (action) {
      case 'play': _playFile(allFiles, allFiles.indexOf(file)); break;
      case 'next': /* TODO: queue */ break;
      case 'fav': _toggleFav(file); break;
      case 'info': _showInfo(file); break;
      case 'ringtone':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fonctionnalité sonnerie bientôt disponible')));
        break;
    }
  }

  void _showInfo(MediaFile f) => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Informations', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    _infoRow('Titre', f.displayName),
    _infoRow('Artiste', f.artistDisplay),
    _infoRow('Album', f.album ?? 'Inconnu'),
    _infoRow('Format', f.extension.toUpperCase().replaceAll('.', '')),
    _infoRow('Taille', f.sizeFormatted),
    _infoRow('Durée', f.durationFormatted),
    _infoRow('Chemin', f.path),
    _infoRow('Modifié', '${f.modified.day}/${f.modified.month}/${f.modified.year}'),
  ]));

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
    ]));

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _eq() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Égaliseur', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
      children: ['Flat', 'Rock', 'Jazz', 'Classique', 'Bass+', 'Vocal+', 'Treble', 'Électro', 'Acoustique'].map((p) =>
        Padding(padding: const EdgeInsets.only(right: 6),
          child: FilterChip(label: Text(p), onSelected: (_){}))).toList())),
    const SizedBox(height: 20),
    SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(10, (i) {
        final h = [0.6, 0.7, 0.8, 0.85, 0.9, 0.88, 0.78, 0.68, 0.55, 0.4][i];
        return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Container(height: h * 120, decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(2)))));
      }))),
    const SizedBox(height: 20),
    SwitchListTile(title: const Text('ReplayGain Auto'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Gapless Playback'), value: true, onChanged: (_){}),
    SwitchListTile(title: const Text('Normalisation volume'), value: false, onChanged: (_){}),
  ]));

  void _timer() => showModalBottomSheet(context: context, builder: (_) => ListView(
    padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Minuterie sommeil', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    ...['15 min', '30 min', '45 min', '60 min', '90 min', 'Fin du morceau'].map((t) =>
      ListTile(title: Text(t), onTap: () => Navigator.pop(context))),
  ]));
}
