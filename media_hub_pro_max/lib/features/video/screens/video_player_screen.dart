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
  bool _isInit = false;
  int _selIdx = -1;
  double _speed = 1.0;
  bool _showCtrl = true;
  bool _fullscreen = false;
  String _search = '';

  @override
  void dispose() { _controller?.dispose(); WakelockPlus.disable(); SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]); super.dispose(); }

  Future<void> _init(String path) async {
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(path));
    try {
      await _controller!.initialize();
      await WakelockPlus.enable();
      setState(() => _isInit = true);
      _controller!.play();
      _controller!.addListener(() { if (mounted) setState(() {}); });
    } catch (e) {
      setState(() => _isInit = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _toggleFS() {
    setState(() => _fullscreen = !_fullscreen);
    if (_fullscreen) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fullscreen && _isInit && _controller != null) return _fullPlayer();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Vidéo Pro'), actions: [
      IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(videoFilesProvider)),
    ]), body: ref.watch(videoFilesProvider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: FilledButton(onPressed: () => ref.invalidate(videoFilesProvider), child: Text('Erreur: $e'))),
      data: (files) => Column(children: [
        _inlinePlayer(cs),
        Padding(padding: const EdgeInsets.fromLTRB(8,4,8,0), child: TextField(decoration: InputDecoration(
          hintText: 'Rechercher...', prefixIcon: const Icon(Icons.search, size: 20), isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        ), onChanged: (v) => setState(() => _search = v))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2), child: Row(children: [
          Text('${files.length} vidéos', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ])),
        Expanded(child: _videoList(files, cs)),
      ]),
    ));
  }

  Widget _inlinePlayer(ColorScheme cs) => GestureDetector(onTap: () => setState(() => _showCtrl = !_showCtrl),
    child: Container(height: 220, color: Colors.black,
      child: _selIdx >= 0 && _isInit && _controller != null
        ? Stack(alignment: Alignment.center, children: [
            AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!)),
            if (_showCtrl) _controls(false),
          ])
        : Center(child: Icon(Icons.play_circle_outline, size: 56, color: Colors.white54))));

  Widget _fullPlayer() => Scaffold(backgroundColor: Colors.black, body: GestureDetector(
    onTap: () => setState(() => _showCtrl = !_showCtrl),
    child: Stack(fit: StackFit.expand, children: [
      Center(child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))),
      if (_showCtrl) _controls(true),
    ]),
  ));

  Widget _controls(bool fs) {
    final pos = _controller?.value.position ?? Duration.zero;
    final dur = _controller?.value.duration ?? Duration.zero;
    final playing = _controller?.value.isPlaying ?? false;
    return Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        if (fs) Padding(padding: const EdgeInsets.only(top: 20, left: 16), child: Row(children: [
          IconButton(icon: const Icon(Icons.fullscreen_exit, color: Colors.white), onPressed: _toggleFS),
        ])),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 28), onPressed: () => _controller?.seekTo(pos - const Duration(seconds: 10))),
          const SizedBox(width: 16),
          GestureDetector(onTap: () => playing ? _controller?.pause() : _controller?.play(),
            child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24), padding: const EdgeInsets.all(16),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 48, color: Colors.white))),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.forward_10, color: Colors.white, size: 28), onPressed: () => _controller?.seekTo(pos + const Duration(seconds: 10))),
        ]),
        const Spacer(),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
          child: VideoProgressIndicator(_controller!, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.red, bufferedColor: Colors.redAccent))),
        Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, fs ? 24 : 8), child: Row(children: [
          Text(_fmt(pos), style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(width: 8), Expanded(child: Text(_selName, style: const TextStyle(color: Colors.white70, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.speed, color: Colors.white70, size: 18), onPressed: _speedMenu),
          IconButton(icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 18), onPressed: _toggleFS),
          const SizedBox(width: 4), Text(_fmt(dur), style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ])),
      ]),
    );
  }

  Widget _videoList(List<MediaFile> files, ColorScheme cs) {
    final filtered = _search.isEmpty ? files : files.where((f) => f.displayName.toLowerCase().contains(_search.toLowerCase())).toList();
    if (files.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.movie, size: 64, color: cs.onSurfaceVariant.withOpacity(0.5)), const SizedBox(height: 16), const Text('Aucune vidéo'),
      const SizedBox(height: 16), FilledButton.icon(onPressed: () => ref.invalidate(videoFilesProvider), icon: const Icon(Icons.refresh), label: const Text('Rescanner')),
    ]));
    return ListView.builder(itemCount: filtered.length, itemBuilder: (_, i) {
      final f = filtered[i]; final sel = i == _selIdx;
      return ListTile(selected: sel, leading: Container(width: 64, height: 40,
        decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
        child: Stack(alignment: Alignment.center, children: [const Icon(Icons.movie, size: 18), if (sel) Icon(Icons.play_circle, color: cs.primary)])),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        subtitle: Text('${f.extension.toUpperCase().replaceAll('.', '')} • ${f.sizeFormatted}', style: const TextStyle(fontSize: 11)),
        onTap: () { setState(() { _selIdx = i; _isInit = false; }); _init(f.path); },
        trailing: IconButton(icon: const Icon(Icons.fullscreen), onPressed: () {
          setState(() { _selIdx = i; _isInit = false; }); _init(f.path).then((_) { if (_isInit) _toggleFS(); });
        }),
      );
    });
  }

  String get _selName { final f = ref.read(videoFilesProvider).valueOrNull ?? []; return _selIdx >= 0 && _selIdx < f.length ? f[_selIdx].displayName : ''; }

  void _speedMenu() => showModalBottomSheet(context: context, builder: (_) => Padding(padding: const EdgeInsets.all(24),
    child: Wrap(spacing: 8, runSpacing: 8, children: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) =>
      ChoiceChip(label: Text('${s}x'), selected: _speed == s, onSelected: (_) { _speed = s; _controller?.setPlaybackSpeed(s); Navigator.pop(context); })).toList())));

  String _fmt(Duration d) { final h = d.inHours; final m = d.inMinutes.remainder(60); final s = d.inSeconds.remainder(60); return h > 0 ? '$h:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}' : '$m:${s.toString().padLeft(2,'0')}'; }
}
