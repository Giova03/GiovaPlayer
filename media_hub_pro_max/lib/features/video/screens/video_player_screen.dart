import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/file_scanner.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({super.key});
  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  int _selectedIndex = -1;
  double _playbackSpeed = 1.0;
  String _searchQuery = '';
  bool _showControls = true;
  bool _isFullscreen = false;
  double _volume = 1.0;
  double _brightness = 0.5;

  @override
  void dispose() {
    _controller?.dispose();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  Future<void> _initPlayer(String path) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(path));

    try {
      await _controller!.initialize();
      await WakelockPlus.enable();
      setState(() => _isInitialized = true);
      _controller!.play();

      _controller!.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      setState(() => _isInitialized = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lecture: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final videoFilesAsync = ref.watch(videoFilesProvider);

    if (_isFullscreen && _isInitialized && _controller != null) {
      return _buildFullscreenPlayer(cs);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Vidéo Pro'), actions: [
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(videoFilesProvider)),
      ]),
      body: videoFilesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.error_outline, size: 64, color: cs.error),
          const SizedBox(height: 16), Text('Erreur: $e', textAlign: TextAlign.center),
          const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider),
            icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ])),
        data: (files) => Column(children: [
          // Lecteur vidéo
          _buildInlinePlayer(cs),
          // Recherche
          Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: TextField(decoration: InputDecoration(
              hintText: 'Rechercher vidéos...', prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
            ), onChanged: (v) => setState(() => _searchQuery = v))),
          // Stats
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Text('${files.length} vidéos', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              const Spacer(),
              TextButton.icon(onPressed: (){},
                icon: const Icon(Icons.sort, size: 16), label: const Text('Trier')),
            ])),
          // Liste
          Expanded(child: _buildVideoList(files, cs)),
        ]),
      ),
    );
  }

  Widget _buildInlinePlayer(ColorScheme cs) {
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Container(
        height: 220, color: Colors.black,
        child: _selectedIndex >= 0 && _isInitialized && _controller != null
          ? Stack(alignment: Alignment.center, children: [
              AspectRatio(aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!)),
              if (_showControls) _buildControlsOverlay(cs, isFullscreen: false),
            ])
          : Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.play_circle_outline, size: 56, color: Colors.white54),
              const SizedBox(height: 8),
              Text('Sélectionnez une vidéo', style: TextStyle(color: Colors.white54)),
            ])),
      ),
    );
  }

  Widget _buildFullscreenPlayer(ColorScheme cs) {
    return Scaffold(backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        onDoubleTap: () {
          if (_controller != null) {
            final pos = _controller!.value.position;
            _controller!.seekTo(pos + const Duration(seconds: 10));
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          Center(child: AspectRatio(aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!))),
          if (_showControls) _buildControlsOverlay(cs, isFullscreen: true),
          // Gesture zones for seek/volume/brightness
          if (_showControls) Positioned.fill(child: Row(children: [
            // Tap left = rewind 10s
            Expanded(child: GestureDetector(onDoubleTap: () {
              final pos = _controller!.value.position;
              _controller!.seekTo(pos - const Duration(seconds: 10));
            })),
            // Tap right = forward 10s
            Expanded(child: GestureDetector(onDoubleTap: () {
              final pos = _controller!.value.position;
              _controller!.seekTo(pos + const Duration(seconds: 10));
            })),
          ])),
        ]),
      ),
    );
  }

  Widget _buildControlsOverlay(ColorScheme cs, {required bool isFullscreen}) {
    final pos = _controller?.value.position ?? Duration.zero;
    final dur = _controller?.value.duration ?? Duration.zero;
    final playing = _controller?.value.isPlaying ?? false;

    return Container(decoration: const BoxDecoration(gradient: LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black87])),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        // Top bar
        if (isFullscreen) Padding(padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
              onPressed: _toggleFullscreen),
            Expanded(child: Text('GiovaPlayer', style: TextStyle(color: Colors.white70, fontSize: 12))),
            IconButton(icon: const Icon(Icons.lock, color: Colors.white70), onPressed: (){}),
          ])),
        const Spacer(),
        // Center play/pause
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
            onPressed: () => _controller?.seekTo(pos - const Duration(seconds: 10))),
          const SizedBox(width: 16),
          GestureDetector(onTap: () => playing ? _controller?.pause() : _controller?.play(),
            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
              padding: const EdgeInsets.all(16),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 48, color: Colors.white))),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
            onPressed: () => _controller?.seekTo(pos + const Duration(seconds: 10))),
        ]),
        const Spacer(),
        // Progress bar
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: VideoProgressIndicator(_controller!, allowScrubbing: true,
            colors: const VideoProgressColors(playedColor: Colors.red, bufferedColor: Colors.redAccent))),
        // Bottom controls
        Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, isFullscreen ? 24 : 8),
          child: Row(children: [
            Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 8),
            Expanded(child: Text(_selectedFileName, style: const TextStyle(color: Colors.white70, fontSize: 11),
              maxLines: 1, overflow: TextOverflow.ellipsis)),
            IconButton(icon: Icon(Icons.speed, color: Colors.white70, size: 20), onPressed: _speedMenu),
            IconButton(icon: Icon(Icons.volume_up, color: Colors.white70, size: 20), onPressed: _volumeMenu),
            IconButton(icon: Icon(Icons.fullscreen, color: Colors.white70, size: 20),
              onPressed: _toggleFullscreen),
            const SizedBox(width: 4),
            Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),
      ]),
    );
  }

  Widget _buildVideoList(List<MediaFile> files, ColorScheme cs) {
    final filtered = _searchQuery.isEmpty ? files : files.where((f) =>
      f.displayName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (files.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.movie, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)),
        const SizedBox(height: 16), const Text('Aucune vidéo trouvée'),
        const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider),
          icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
      ]));
    }

    return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
      final f = filtered[i];
      final isSelected = i == _selectedIndex;
      return ListTile(
        selected: isSelected,
        selectedTileColor: cs.primaryContainer.withOpacity(0.2),
        leading: Container(width: 72, height: 44,
          decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: Stack(alignment: Alignment.center, children: [
            const Icon(Icons.movie, size: 20),
            if (isSelected) Container(decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.3), borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.play_circle, color: cs.primary)),
          ])),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${f.extension.toUpperCase().replaceAll('.', '')} • ${f.sizeFormatted}',
          style: const TextStyle(fontSize: 11)),
        trailing: PopupMenuButton(itemBuilder: (_) => [
          const PopupMenuItem(value: 'play', child: ListTile(leading: Icon(Icons.play_arrow), title: Text('Lire'))),
          const PopupMenuItem(value: 'fullscreen', child: ListTile(leading: Icon(Icons.fullscreen), title: Text('Plein écran'))),
          const PopupMenuItem(value: 'info', child: ListTile(leading: Icon(Icons.info), title: Text('Détails'))),
          const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('Partager'))),
          const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete), title: Text('Supprimer'))),
        ], onSelected: (v) => _onVideoAction(v, f, i)),
        onTap: () {
          setState(() { _selectedIndex = i; _isInitialized = false; });
          _initPlayer(f.path);
        },
      );
    });
  }

  String get _selectedFileName {
    final files = ref.read(videoFilesProvider).valueOrNull ?? [];
    if (_selectedIndex < 0 || _selectedIndex >= files.length) return '';
    return files[_selectedIndex].displayName;
  }

  void _onVideoAction(String action, MediaFile f, int index) {
    switch (action) {
      case 'play':
        setState(() { _selectedIndex = index; _isInitialized = false; });
        _initPlayer(f.path);
        break;
      case 'fullscreen':
        setState(() { _selectedIndex = index; _isInitialized = false; });
        _initPlayer(f.path).then((_) {
          if (_isInitialized) _toggleFullscreen();
        });
        break;
      case 'info':
        showModalBottomSheet(context: context, builder: (_) => ListView(
          padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
          Text('Informations vidéo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _infoRow('Nom', f.displayName),
          _infoRow('Format', f.extension.toUpperCase()),
          _infoRow('Taille', f.sizeFormatted),
          _infoRow('Chemin', f.path),
          _infoRow('Modifié', '${f.modified.day}/${f.modified.month}/${f.modified.year}'),
          if (_controller != null && _isInitialized) ...[
            _infoRow('Résolution', '${_controller!.value.size.width.toInt()}x${_controller!.value.size.height.toInt()}'),
            _infoRow('Durée', _fmt(_controller!.value.duration)),
          ],
        ]));
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage bientôt disponible')));
        break;
      case 'delete':
        _confirmDelete(f);
        break;
    }
  }

  void _confirmDelete(MediaFile f) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer ?'),
      content: Text('Supprimer "${f.displayName}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          try {
            await File(f.path).delete();
            ref.invalidate(videoFilesProvider);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vidéo supprimée')));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
          }
        }, child: const Text('Supprimer')),
      ],
    ));
  }

  Widget _infoRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(l, style: const TextStyle(fontWeight: FontWeight.w600))),
      Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
    ]));

  void _speedMenu() => showModalBottomSheet(context: context, builder: (_) => Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Vitesse de lecture', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((s) =>
        ChoiceChip(label: Text('${s}x'), selected: _playbackSpeed == s,
          onSelected: (_) {
            _playbackSpeed = s;
            _controller?.setPlaybackSpeed(s);
            Navigator.pop(context);
          })).toList()),
    ])));

  void _volumeMenu() => showModalBottomSheet(context: context, builder: (_) => Padding(
    padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Volume', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      Slider(value: _volume, onChanged: (v) {
        setState(() => _volume = v);
        _controller?.setVolume(v);
      }),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Icon(Icons.volume_mute), const Icon(Icons.volume_up),
      ]),
    ])));

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
