import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});
  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _url = TextEditingController();
  bool _loading = false;
  List<_DownloadTask> _activeTasks = [];
  List<_DownloadTask> _completedTasks = [];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _loadDownloadDir();
  }

  @override
  void dispose() {
    _tc.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _loadDownloadDir() async {
    // Charger les fichiers déjà dans le dossier Download
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          final files = downloadDir.listSync();
          for (final f in files) {
            if (f is File) {
              final stat = f.statSync();
              final name = f.path.substring(f.path.lastIndexOf('/') + 1);
              _completedTasks.add(_DownloadTask(
                name: name,
                size: stat.size,
                path: f.path,
                completed: true,
              ));
            }
          }
          setState(() {});
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Downloader'),
      bottom: TabBar(controller: _tc, tabs: const [
        Tab(text: 'Nouveau'),
        Tab(text: 'En cours'),
        Tab(text: 'Terminés'),
      ])),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _url,
          decoration: InputDecoration(hintText: 'Collez un lien YouTube, TikTok, IG...',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _analyze),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28))),
          onSubmitted: (_) => _analyze())),
        Expanded(child: TabBarView(controller: _tc, children: [
          // Nouveau
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Plateformes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Chip(avatar: const Icon(Icons.play_circle, size: 16), label: const Text('YouTube')),
              Chip(avatar: const Icon(Icons.music_note, size: 16), label: const Text('TikTok')),
              Chip(avatar: const Icon(Icons.camera, size: 16), label: const Text('Instagram')),
              Chip(avatar: const Icon(Icons.thumb_up, size: 16), label: const Text('Facebook')),
              Chip(avatar: const Icon(Icons.flutter_dash, size: 16), label: const Text('Twitter/X')),
            ]),
            const SizedBox(height: 20),
            Card(child: ListTile(
              leading: Icon(Icons.download, color: cs.primary),
              title: const Text('Dossier Download'),
              subtitle: Text('${_completedTasks.length} fichiers'),
              trailing: const Icon(Icons.folder_open),
              onTap: _openDownloadFolder,
            )),
          ]),
          // En cours
          _activeTasks.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.cloud_download, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun téléchargement en cours'),
              ]))
            : ListView(padding: const EdgeInsets.all(16), children: [
                ..._activeTasks.map((t) => _dl(t, cs)),
              ]),
          // Terminés
          _completedTasks.isEmpty
            ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun téléchargement terminé'),
              ]))
            : ListView(padding: const EdgeInsets.all(16), children: [
                Row(children: [
                  Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                    Text('${_completedTasks.length}', style: Theme.of(context).textTheme.headlineSmall),
                    Text('Fichiers', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ])))),
                  Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
                    Text(_fmtSize(_completedTasks.fold<int>(0, (s, t) => s + t.size)),
                      style: Theme.of(context).textTheme.headlineSmall),
                    Text('Total', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ])))),
                ]),
                ..._completedTasks.map((t) => ListTile(
                  leading: Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
                    child: Icon(_fileIcon(t.name), color: cs.onSurfaceVariant)),
                  title: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(_fmtSize(t.size)),
                )),
              ]),
        ])),
      ]),
    );
  }

  Widget _dl(_DownloadTask t, ColorScheme cs) => Card(margin: const EdgeInsets.only(bottom: 8),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${(t.progress * 100).round()}%', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600))]),
      const SizedBox(height: 8),
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: t.progress, minHeight: 6)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(_fmtSize((t.size * t.progress).round()), style: const TextStyle(fontSize: 12)),
        Row(children: [
          IconButton(icon: const Icon(Icons.pause, size: 18), onPressed: (){}),
          IconButton(icon: const Icon(Icons.cancel, size: 18), onPressed: (){}),
        ]),
      ]),
    ])));

  Future<void> _analyze() async {
    if (_url.text.isEmpty) return;
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _loading = false);
    if (mounted) showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) =>
      DraggableScrollableSheet(initialChildSize: 0.6, expand: false,
        builder: (c, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
          Text('Formats disponibles', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Vidéo', style: Theme.of(context).textTheme.titleMedium),
          ...['4K (2160p)', '1440p', '1080p', '720p', '480p'].map((q) =>
            Card(child: ListTile(title: Text(q), subtitle: Text('MP4 H.${q.contains('4K') ? '265' : '264'}'),
              trailing: q.startsWith('4K') ? const Icon(Icons.check_circle, color: Colors.blue) : null))),
          const SizedBox(height: 16),
          Text('Audio', style: Theme.of(context).textTheme.titleMedium),
          ...['FLAC', 'MP3 320k', 'M4A 256k', 'OPUS 128k'].map((q) =>
            Card(child: ListTile(title: Text(q)))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Téléchargement en cours de préparation...')),
              );
            },
            icon: const Icon(Icons.download), label: const Text('Télécharger'))),
        ])));
  }

  void _openDownloadFolder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Les fichiers sont dans /storage/emulated/0/Download')),
    );
  }

  IconData _fileIcon(String name) {
    final ext = name.substring(name.lastIndexOf('.') + 1).toLowerCase();
    if (['mp4', 'mkv', 'avi', 'mov'].contains(ext)) return Icons.movie;
    if (['mp3', 'flac', 'wav', 'm4a'].contains(ext)) return Icons.music_note;
    if (['jpg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
    return Icons.insert_drive_file;
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _DownloadTask {
  final String name;
  final int size;
  final String path;
  final double progress;
  final bool completed;

  _DownloadTask({
    required this.name,
    required this.size,
    required this.path,
    this.progress = 0.0,
    this.completed = false,
  });
}
