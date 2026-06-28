import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/file_scanner.dart';
import '../../../core/database/app_database.dart';

class AudioPlayerScreen extends ConsumerStatefulWidget {
  const AudioPlayerScreen({super.key});
  @override
  ConsumerState<AudioPlayerScreen> createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends ConsumerState<AudioPlayerScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _searchCtl = TextEditingController();
  String _search = '';
  final _db = AppDatabase.instance;
  List<Map<String, dynamic>> _playlists = [];
  List<Map<String, dynamic>> _recentlyPlayed = [];
  List<Map<String, dynamic>> _favorites = [];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
    _loadPlaylistData();
  }
  @override
  void dispose() { _tc.dispose(); _searchCtl.dispose(); super.dispose(); }

  Future<void> _loadPlaylistData() async {
    try {
      final pl = await _db.getPlaylists();
      final rp = await _db.getRecentlyPlayed();
      final fav = await _db.getFavorites();
      if (mounted) {
        setState(() { _playlists = pl; _recentlyPlayed = rp; _favorites = fav; });
      }
    } catch (e) {
      debugPrint('_loadPlaylistData error: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final audioAsync = ref.watch(audioFilesProvider);
    final currentFile = ref.watch(currentAudioFileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: () async => forceRescanAll(ref)),
        ],
        bottom: TabBar(controller: _tc, tabs: const [
          Tab(text: 'Bibliothèque'), Tab(text: 'Dossiers'),
          Tab(text: 'Lecteur'), Tab(text: 'Playlists'),
        ]),
      ),
      body: Column(children: [
        Expanded(child: TabBarView(controller: _tc, children: [
          _libraryTab(audioAsync, cs),
          _foldersTab(audioAsync, cs),
          _playerTab(cs, currentFile),
          _playlistsTab(cs),
        ])),
        if (currentFile != null) _miniPlayer(cs, currentFile),
      ]),
    );
  }

  // ═══ BIBLIOTHÈQUE ═══
  Widget _libraryTab(AsyncValue<List<MediaFile>> audioAsync, ColorScheme cs) {
    return audioAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 8),
        Text('Erreur: $e', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton(onPressed: () => forceRescanAll(ref), child: const Text('Réessayer')),
      ]))),
      data: (files) {
        final filtered = _search.isEmpty ? files : files.where((f) => f.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
        final currentPath = ref.watch(currentAudioFileProvider)?.path;
        return Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: TextField(controller: _searchCtl, decoration: InputDecoration(
              hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
              suffixIcon: _search.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtl.clear(); setState(() => _search = ''); }) : null,
            ), onChanged: (v) => setState(() => _search = v))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(children: [
              Text('${files.length} titres', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(onPressed: () => _playAll(files), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Tout lire')),
              TextButton.icon(onPressed: () => _shuffleAll(files), icon: const Icon(Icons.shuffle, size: 16), label: const Text('Aléatoire')),
            ])),
          Expanded(child: filtered.isEmpty ? const Center(child: Text('Aucun fichier audio'))
            : ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
              final f = filtered[i];
              final isCurrent = currentPath == f.path;
              return ListTile(
                selected: isCurrent,
                leading: Container(width: 48, height: 48, decoration: BoxDecoration(
                  color: isCurrent ? cs.primaryContainer : cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                  child: isCurrent ? Icon(Icons.music_note, color: cs.primary) : const Icon(Icons.music_note, color: Colors.grey)),
                title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)),
                subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 12)),
                trailing: PopupMenuButton(itemBuilder: (_) => [
                  const PopupMenuItem(value: 'play', child: Text('Lire')),
                  const PopupMenuItem(value: 'next', child: Text('Lire ensuite')),
                  const PopupMenuItem(value: 'playlist', child: Text('Ajouter à une playlist')),
                  const PopupMenuItem(value: 'favorite', child: Text('Ajouter aux favoris')),
                  const PopupMenuItem(value: 'info', child: Text('Informations')),
                ], onSelected: (v) => _onSongAction(v, f, files)),
                onTap: () => _playFile(f, files),
              );
            })),
        ]);
      },
    );
  }

  // ═══ DOSSIERS ═══
  Widget _foldersTab(AsyncValue<List<MediaFile>> audioAsync, ColorScheme cs) {
    return audioAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (files) {
        final folders = <String, List<MediaFile>>{};
        for (final f in files) {
          final dir = f.path.substring(0, f.path.lastIndexOf('/'));
          final name = dir.substring(dir.lastIndexOf('/') + 1);
          folders.putIfAbsent(name, () => []).add(f);
        }
        if (folders.isEmpty) return const Center(child: Text('Aucun dossier'));
        return ListView(children: folders.entries.map((e) => ExpansionTile(
          leading: Icon(Icons.folder, color: cs.primary),
          title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${e.value.length} titres'),
          children: e.value.map((f) => ListTile(
            leading: const Icon(Icons.music_note, size: 20),
            title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)),
            onTap: () => _playFile(f, e.value),
          )).toList(),
        )).toList());
      },
    );
  }

  // ═══ LECTEUR ═══
  Widget _playerTab(ColorScheme cs, MediaFile? currentFile) {
    final playerAsync = ref.watch(audioHandlerProvider);
    return playerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 8),
        Text('Service audio indisponible: $e', textAlign: TextAlign.center),
      ]))),
      data: (handler) {
        final player = handler.player;
        return ListView(padding: const EdgeInsets.all(24), children: [
          Container(height: 240, decoration: BoxDecoration(
            color: cs.primaryContainer, borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(colors: [cs.primaryContainer, cs.tertiaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            child: Center(child: Icon(Icons.music_note, size: 80, color: cs.onPrimaryContainer))),
          const SizedBox(height: 24),
          // Title — listen to mediaItem stream so notification-skip updates UI
          StreamBuilder<MediaItem?>(stream: handler.mediaItem, builder: (_, snap) {
            final item = snap.data;
            final title = item?.title ?? currentFile?.displayName ?? 'Aucun titre';
            final artist = item?.artist ?? currentFile?.artistDisplay ?? '';
            return Column(children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(artist, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]);
          }),
          const SizedBox(height: 24),
          // Progress bar
          StreamBuilder<Duration>(stream: player.positionStream, builder: (_, snap) {
            final p = snap.data ?? Duration.zero;
            final d = player.duration ?? Duration.zero;
            return Column(children: [
              Slider(value: d.inMilliseconds > 0 ? p.inMilliseconds.toDouble().clamp(0, d.inMilliseconds.toDouble()) : 0,
                min: 0, max: d.inMilliseconds.toDouble() > 0 ? d.inMilliseconds.toDouble() : 1,
                onChanged: (v) => player.seek(Duration(milliseconds: v.round()))),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(_fmt(p), style: const TextStyle(fontSize: 12)),
                Text(_fmt(d), style: const TextStyle(fontSize: 12)),
              ]),
            ]);
          }),
          // Controls
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            StreamBuilder<bool>(stream: player.shuffleModeEnabledStream, initialData: player.shuffleModeEnabled, builder: (_, snap) {
              return IconButton(icon: const Icon(Icons.shuffle, size: 22),
                color: snap.data == true ? cs.primary : cs.onSurfaceVariant,
                onPressed: () => player.setShuffleModeEnabled(!(snap.data ?? false)));
            }),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.skip_previous, size: 32), onPressed: () => handler.skipToPrevious()),
            const SizedBox(width: 16),
            StreamBuilder<bool>(stream: player.playingStream, initialData: player.playing, builder: (_, snap) {
              final playing = snap.data ?? false;
              return GestureDetector(onTap: () => playing ? handler.pause() : handler.play(),
                child: Container(decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primary), padding: const EdgeInsets.all(20),
                  child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 40, color: cs.onPrimary)));
            }),
            const SizedBox(width: 16),
            IconButton(icon: const Icon(Icons.skip_next, size: 32), onPressed: () => handler.skipToNext()),
            const SizedBox(width: 8),
            StreamBuilder<LoopMode>(stream: player.loopModeStream, initialData: player.loopMode, builder: (_, snap) {
              final mode = snap.data ?? LoopMode.off;
              return IconButton(icon: Icon(mode == LoopMode.one ? Icons.repeat_one : Icons.repeat, size: 22),
                color: mode != LoopMode.off ? cs.primary : cs.onSurfaceVariant,
                onPressed: () => player.setLoopMode(switch(mode) { LoopMode.off => LoopMode.all, LoopMode.all => LoopMode.one, _ => LoopMode.off }));
            }),
          ]),
          const SizedBox(height: 16),
          // Volume + Speed
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.volume_up, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            StreamBuilder<double>(stream: player.volumeStream, initialData: player.volume, builder: (_, snap) {
              return SizedBox(width: 120, child: Slider(value: snap.data ?? 1.0, min: 0, max: 1, onChanged: (v) => player.setVolume(v)));
            }),
            const SizedBox(width: 16),
            StreamBuilder<double>(stream: player.speedStream, initialData: player.speed, builder: (_, snap) {
              final speed = snap.data ?? 1.0;
              return Text('${speed}x', style: const TextStyle(fontSize: 12));
            }),
            const SizedBox(width: 4),
            PopupMenuButton<double>(itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) =>
              PopupMenuItem(value: s, child: Text('${s}x'))).toList(),
              onSelected: (s) => player.setSpeed(s),
              child: const Icon(Icons.speed, size: 20)),
          ]),
          const SizedBox(height: 24),
          if (currentFile != null) Center(child: FutureBuilder<bool>(
            future: _db.isFavorite(currentFile.path),
            builder: (_, snap) => IconButton.filledTonal(
              icon: Icon(snap.data == true ? Icons.favorite : Icons.favorite_border),
              onPressed: () async {
                try {
                  await _db.toggleFavorite(currentFile.path, 'audio', currentFile.displayName);
                  if (!mounted) return;
                  setState(() {});
                  _showSuccess(snap.data == true ? 'Retiré des favoris' : 'Ajouté aux favoris');
                } catch (e) {
                  _showError('Erreur: $e');
                }
              },
            ),
          )),
        ]);
      },
    );
  }

  // ═══ PLAYLISTS ═══
  Widget _playlistsTab(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.tonalIcon(onPressed: _createPlaylist, icon: const Icon(Icons.add), label: const Text('Nouvelle playlist')),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: Icon(Icons.favorite, color: Colors.red), title: const Text('Favoris', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_favorites.length} titres'), trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPlaylistContent('Favoris', _favorites.map((f) => f['file_path'] as String).toList()))),
      const SizedBox(height: 8),
      Card(child: ListTile(leading: Icon(Icons.history, color: cs.primary), title: const Text('Récemment écoutés', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${_recentlyPlayed.length} titres'), trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPlaylistContent('Récents', _recentlyPlayed.map((f) => f['file_path'] as String).toList()))),
      const SizedBox(height: 12),
      Text('Mes playlists', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      if (_playlists.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Aucune playlist créée')))
      else ..._playlists.map((pl) => Card(child: ListTile(
        leading: Icon(Icons.queue_music, color: cs.primary),
        title: Text(pl['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: FutureBuilder<int>(future: _db.getPlaylistCount(pl['id'] as int), builder: (_, snap) => Text('${snap.data ?? 0} titres')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(icon: const Icon(Icons.play_arrow, size: 20), onPressed: () => _playPlaylist(pl)),
          IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _confirmDeletePlaylist(pl)),
        ]),
        onTap: () => _showPlaylistDetail(pl),
      ))),
    ]);
  }

  // ═══ MINI PLAYER ═══
  Widget _miniPlayer(ColorScheme cs, MediaFile file) {
    final playerAsync = ref.watch(audioHandlerProvider);
    return playerAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (handler) {
        final player = handler.player;
        return Container(decoration: BoxDecoration(color: cs.surfaceContainerHigh, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, -2))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            StreamBuilder<Duration>(stream: player.positionStream, builder: (_, snap) {
              final p = snap.data ?? Duration.zero;
              final d = player.duration ?? Duration.zero;
              return LinearProgressIndicator(value: d.inMilliseconds > 0 ? p.inMilliseconds / d.inMilliseconds : 0, backgroundColor: cs.surfaceContainerHighest);
            }),
            ListTile(
              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.music_note, color: cs.primary)),
              title: Text(file.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text(file.artistDisplay, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StreamBuilder<bool>(stream: player.playingStream, initialData: player.playing, builder: (_, snap) {
                  final playing = snap.data ?? false;
                  return IconButton(icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 28), onPressed: () => playing ? handler.pause() : handler.play());
                }),
                IconButton(icon: const Icon(Icons.skip_next, size: 22), onPressed: () => handler.skipToNext()),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () async {
                  try { await handler.stop(); } catch (e) { debugPrint('stop error: $e'); }
                  ref.read(currentAudioFileProvider.notifier).state = null;
                }),
              ]),
              onTap: () => _tc.animateTo(2),
            ),
          ]),
        );
      },
    );
  }

  // ═══ ACTIONS — ALL with try/catch ═══
  Future<void> _playFile(MediaFile file, List<MediaFile> allFiles) async {
    try {
      final handler = await ref.read(audioHandlerProvider.future);
      final index = allFiles.indexWhere((f) => f.path == file.path);
      final paths = allFiles.map((f) => f.path).toList();
      await handler.setPlaylist(paths, startIndex: index >= 0 ? index : 0);
      ref.read(currentAudioFileProvider.notifier).state = file;
      await _db.addRecentlyPlayed(file.path, file.displayName);
      _loadPlaylistData();
    } catch (e) {
      debugPrint('_playFile error: $e');
      _showError('Lecture impossible: $e');
    }
  }

  Future<void> _playAll(List<MediaFile> files) async {
    if (files.isEmpty) return;
    try {
      final handler = await ref.read(audioHandlerProvider.future);
      await handler.setPlaylist(files.map((f) => f.path).toList());
      ref.read(currentAudioFileProvider.notifier).state = files.first;
    } catch (e) {
      debugPrint('_playAll error: $e');
      _showError('Lecture impossible: $e');
    }
  }

  Future<void> _shuffleAll(List<MediaFile> files) async {
    if (files.isEmpty) return;
    try {
      final handler = await ref.read(audioHandlerProvider.future);
      final shuffled = List<MediaFile>.from(files)..shuffle();
      await handler.setPlaylist(shuffled.map((f) => f.path).toList());
      await handler.player.setShuffleModeEnabled(true);
      ref.read(currentAudioFileProvider.notifier).state = shuffled.first;
    } catch (e) {
      debugPrint('_shuffleAll error: $e');
      _showError('Lecture impossible: $e');
    }
  }

  Future<void> _onSongAction(String action, MediaFile file, List<MediaFile> allFiles) async {
    try {
      switch (action) {
        case 'play': await _playFile(file, allFiles); break;
        case 'next': await _addToNext(file); break;
        case 'playlist': if (mounted) showDialog(context: context, builder: (_) => _PlaylistPickerDialog(file: file, db: _db, onClose: _loadPlaylistData)); break;
        case 'favorite':
          await _db.toggleFavorite(file.path, 'audio', file.displayName);
          _loadPlaylistData();
          _showSuccess('Favori mis à jour');
          break;
        case 'info': _showFileInfo(file); break;
      }
    } catch (e) {
      _showError('Erreur: $e');
    }
  }

  Future<void> _addToNext(MediaFile file) async {
    try {
      final handler = await ref.read(audioHandlerProvider.future);
      await handler.playNext(file.path);
      _showSuccess('Lire ensuite: ${file.displayName}');
    } catch (e) {
      debugPrint('_addToNext error: $e');
      _showError('Impossible d\'ajouter: $e');
    }
  }

  void _createPlaylist() {
    final ctl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Nouvelle playlist'),
      content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Nom', border: OutlineInputBorder()), autofocus: true),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () async { if (ctl.text.isNotEmpty) { await _db.createPlaylist(ctl.text); if (mounted) Navigator.pop(context); _loadPlaylistData(); } }, child: const Text('Créer'))],
    ));
  }

  void _confirmDeletePlaylist(Map<String, dynamic> pl) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer la playlist ?'),
      content: Text('${pl["name"]} sera définitivement supprimée.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async { await _db.deletePlaylist(pl['id'] as int); if (mounted) Navigator.pop(context); _loadPlaylistData(); }, child: const Text('Supprimer'))],
    ));
  }

  void _showFileInfo(MediaFile file) => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Informations', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 12),
    _info('Nom', file.displayName), _info('Artiste', file.artistDisplay),
    _info('Format', file.extension.toUpperCase()), _info('Taille', file.sizeFormatted),
    _info('Chemin', file.path), _info('Modifié', '${file.modified.day}/${file.modified.month}/${file.modified.year}'),
  ]));

  Widget _info(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
  ]));

  Future<void> _showPlaylistContent(String name, List<String> paths) async {
    if (paths.isEmpty) { _showError('Aucun titre à lire'); return; }
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.95, expand: false,
      builder: (_, sc) => Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: Row(children: [
          Expanded(child: Text(name, style: Theme.of(context).textTheme.titleLarge)),
          FilledButton.tonal(onPressed: () async {
            try {
              final h = await ref.read(audioHandlerProvider.future);
              await h.setPlaylist(paths);
              // Find the MediaFile for the first path to update mini-player
              final allAudio = ref.read(audioFilesProvider).valueOrNull ?? [];
              final firstFile = allAudio.where((f) => f.path == paths.first).firstOrNull;
              if (firstFile != null) ref.read(currentAudioFileProvider.notifier).state = firstFile;
              if (mounted) Navigator.pop(context);
            } catch (e) {
              _showError('Lecture impossible: $e');
            }
          }, child: const Text('Tout lire')),
        ])),
        Expanded(child: ListView.builder(controller: sc, itemCount: paths.length, itemBuilder: (_, i) {
          final fname = p.basenameWithoutExtension(paths[i]).replaceAll(RegExp(r'[_\-]+'), ' ').trim();
          return ListTile(leading: const Icon(Icons.music_note, size: 20), title: Text(fname, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            onTap: () async {
              try {
                final h = await ref.read(audioHandlerProvider.future);
                await h.setPlaylist(paths, startIndex: i);
                final allAudio = ref.read(audioFilesProvider).valueOrNull ?? [];
                final file = allAudio.where((f) => f.path == paths[i]).firstOrNull;
                if (file != null) ref.read(currentAudioFileProvider.notifier).state = file;
                if (mounted) Navigator.pop(context);
              } catch (e) {
                _showError('Lecture impossible: $e');
              }
            });
        })),
      ]),
    ));
  }

  Future<void> _showPlaylistDetail(Map<String, dynamic> playlist) async {
    final items = await _db.getPlaylistItems(playlist['id'] as int);
    if (!mounted) return;
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => StatefulBuilder(builder: (ctx, setS) => Column(mainAxisSize: MainAxisSize.min, children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: Text(playlist['name'] as String, style: Theme.of(context).textTheme.titleLarge)),
        FilledButton.tonal(onPressed: () async {
          try {
            final paths = items.map((i) => i['file_path'] as String).toList();
            if (paths.isEmpty) { _showError('Playlist vide'); return; }
            final h = await ref.read(audioHandlerProvider.future);
            await h.setPlaylist(paths);
            final allAudio = ref.read(audioFilesProvider).valueOrNull ?? [];
            final firstFile = allAudio.where((f) => f.path == paths.first).firstOrNull;
            if (firstFile != null) ref.read(currentAudioFileProvider.notifier).state = firstFile;
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            _showError('Lecture impossible: $e');
          }
        }, child: const Text('Tout lire')),
      ])),
      SizedBox(height: 300, child: items.isEmpty ? const Center(child: Text('Playlist vide'))
        : ListView.builder(itemCount: items.length, itemBuilder: (_, i) {
          final item = items[i];
          return ListTile(leading: const Icon(Icons.music_note, size: 20),
            title: Text(item['display_name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
            trailing: IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18), onPressed: () async { await _db.removeFromPlaylist(item['id'] as int); items.removeAt(i); setS(() {}); _loadPlaylistData(); }),
            onTap: () async {
              try {
                final paths = items.map((it) => it['file_path'] as String).toList();
                final h = await ref.read(audioHandlerProvider.future);
                await h.setPlaylist(paths, startIndex: i);
                final allAudio = ref.read(audioFilesProvider).valueOrNull ?? [];
                final file = allAudio.where((f) => f.path == paths[i]).firstOrNull;
                if (file != null) ref.read(currentAudioFileProvider.notifier).state = file;
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                _showError('Lecture impossible: $e');
              }
            });
        })),
    ])));
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist) async {
    try {
      final items = await _db.getPlaylistItems(playlist['id'] as int);
      final paths = items.map((i) => i['file_path'] as String).toList();
      if (paths.isEmpty) { _showError('Playlist vide'); return; }
      final handler = await ref.read(audioHandlerProvider.future);
      await handler.setPlaylist(paths);
      final allAudio = ref.read(audioFilesProvider).valueOrNull ?? [];
      final firstFile = allAudio.where((f) => f.path == paths.first).firstOrNull;
      if (firstFile != null) ref.read(currentAudioFileProvider.notifier).state = firstFile;
      _showSuccess('Lecture: ${playlist['name']}');
    } catch (e) {
      _showError('Lecture impossible: $e');
    }
  }

  String _fmt(Duration d) { final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60); return '$m:${s.toString().padLeft(2, '0')}'; }
}

class _PlaylistPickerDialog extends StatelessWidget {
  final MediaFile file;
  final AppDatabase db;
  final VoidCallback onClose;
  const _PlaylistPickerDialog({required this.file, required this.db, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajouter "${file.displayName}"'),
      content: FutureBuilder(
        future: db.getPlaylists(),
        builder: (_, AsyncSnapshot snap) {
          final playlists = snap.data ?? [];
          if (playlists.isEmpty) return const Text('Créez d\'abord une playlist');
          return SizedBox(width: double.maxFinite, child: ListView.builder(
            shrinkWrap: true, itemCount: playlists.length, itemBuilder: (_, i) {
            final pl = playlists[i];
            return ListTile(leading: const Icon(Icons.queue_music), title: Text(pl['name'] as String),
              onTap: () async {
                final pos = await db.getNextPlaylistPosition(pl['id'] as int);
                await db.addToPlaylist(pl['id'] as int, file.path, file.displayName, pos);
                if (context.mounted) Navigator.pop(context);
                onClose();
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajouté à ${pl['name']}')));
              });
          }));
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))],
    );
  }
}
