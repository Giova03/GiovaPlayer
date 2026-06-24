import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});
  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _url = TextEditingController();
  List<File> _completedFiles = [];
  final List<_DownloadTask> _activeTasks = [];
  String _saveDir = '/storage/emulated/0/Download';

  @override
  void initState() { super.initState(); _tc = TabController(length: 3, vsync: this); _scanCompleted(); _requestPerm(); }
  @override
  void dispose() { _tc.dispose(); _url.dispose(); super.dispose(); }

  Future<void> _requestPerm() async {
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _scanCompleted() async {
    try {
      final dir = Directory(_saveDir);
      if (await dir.exists()) {
        final list = dir.listSync().whereType<File>().toList();
        list.sort((a, b) => b.lastAccessedSync().compareTo(a.lastAccessedSync()));
        setState(() => _completedFiles = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Downloader'),
      bottom: TabBar(controller: _tc, tabs: [
        const Tab(text: 'Nouveau'),
        Tab(text: 'En cours (${_activeTasks.length})'),
        Tab(text: 'Terminés'),
      ])),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _url,
          decoration: InputDecoration(hintText: 'Collez un lien direct (vidéo, audio, fichier...)', prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(icon: const Icon(Icons.download), onPressed: _startDownload),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28))),
          onSubmitted: (_) => _startDownload())),
        Expanded(child: TabBarView(controller: _tc, children: [
          // NEW tab
          ListView(padding: const EdgeInsets.all(16), children: [
            Text('Plateformes supportées', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              'Liens directs', 'MP4/AVI/MKV', 'MP3/FLAC/WAV', 'Images', 'Documents', 'Archives ZIP/RAR',
            ].map((p) => Chip(label: Text(p, style: const TextStyle(fontSize: 12)))).toList()),
            const SizedBox(height: 20),
            Card(child: ListTile(
              leading: Icon(Icons.folder_open, color: cs.primary),
              title: const Text('Dossier de sauvegarde'),
              subtitle: Text(_saveDir),
              trailing: const Icon(Icons.edit, size: 18),
              onTap: _changeSaveDir,
            )),
            const SizedBox(height: 12),
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.info_outline, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('Comment télécharger', style: Theme.of(context).textTheme.titleSmall)),
              ]),
              const SizedBox(height: 8),
              const Text('1. Copiez le lien direct du fichier', style: TextStyle(fontSize: 13)),
              const Text('2. Collez-le dans le champ ci-dessus', style: TextStyle(fontSize: 13)),
              const Text('3. Appuyez sur le bouton télécharger', style: TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Text('Note: Les liens directs se terminent par une extension (.mp4, .mp3, etc.)', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ]))),
          ]),

          // IN PROGRESS tab
          _activeTasks.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_download, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), const Text('Aucun téléchargement en cours')]))
            : ListView.builder(itemCount: _activeTasks.length, itemBuilder: (_, i) {
              final task = _activeTasks[i];
              return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(task.isComplete ? Icons.check_circle : Icons.downloading, color: task.isComplete ? Colors.green : cs.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                  if (task.isComplete) IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => _openFile(task.savePath)),
                  if (!task.isComplete) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _cancelTask(i)),
                ]),
                const SizedBox(height: 8),
                if (task.isComplete)
                  Text('Terminé - ${_fmtSize(task.downloadedBytes)}', style: TextStyle(fontSize: 12, color: Colors.green))
                else if (task.error != null)
                  Text('Erreur: ${task.error}', style: const TextStyle(fontSize: 12, color: Colors.red))
                else ...[
                  LinearProgressIndicator(value: task.progress > 0 ? task.progress : null),
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('${(task.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11)),
                    Text('${_fmtSize(task.downloadedBytes)}${task.totalBytes > 0 ? ' / ${_fmtSize(task.totalBytes)}' : ''}', style: const TextStyle(fontSize: 11)),
                  ]),
                ],
              ])));
            }),

          // COMPLETED tab
          _completedFiles.isEmpty
            ? const Center(child: Text('Aucun fichier téléchargé'))
            : RefreshIndicator(onRefresh: _scanCompleted, child: ListView.builder(itemCount: _completedFiles.length, itemBuilder: (_, i) {
              final f = _completedFiles[i];
              final name = f.path.substring(f.path.lastIndexOf('/') + 1);
              final ext = name.contains('.') ? name.substring(name.lastIndexOf('.') + 1).toUpperCase() : '?';
              return ListTile(
                leading: Icon(_fileIcon(ext), color: cs.primary),
                title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text('${_fmtSize(f.lengthSync())} • $ext'),
                trailing: IconButton(icon: const Icon(Icons.open_in_new, size: 18), onPressed: () => _openFile(f.path)),
              );
            })),
        ])),
      ]),
    );
  }

  Future<void> _startDownload() async {
    final url = _url.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Veuillez entrer un lien')));
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le lien doit commencer par http:// ou https://'), backgroundColor: Colors.red));
      return;
    }

    // Determine filename from URL
    String fileName;
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        fileName = Uri.decodeComponent(pathSegments.last);
        if (!fileName.contains('.') || fileName.length < 3) {
          fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
        }
      } else {
        fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (_) {
      fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    final savePath = p.join(_saveDir, fileName);

    // Create download task
    final task = _DownloadTask(url: url, fileName: fileName, savePath: savePath);
    setState(() => _activeTasks.add(task));
    _url.clear();

    // Switch to "In Progress" tab
    _tc.animateTo(1);

    // Start download
    try {
      final dio = Dio();
      dio.options.connectTimeout = const Duration(seconds: 30);
      dio.options.receiveTimeout = const Duration(minutes: 30);

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              task.downloadedBytes = received;
              task.totalBytes = total;
              task.progress = total > 0 ? received / total : 0;
            });
          }
        },
        deleteOnError: true,
      );

      if (mounted) {
        setState(() {
          task.isComplete = true;
          task.progress = 1.0;
        });
        _scanCompleted();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Téléchargement terminé: $fileName')));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          task.error = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelTask(int index) {
    if (index >= 0 && index < _activeTasks.length) {
      setState(() { _activeTasks.removeAt(index); });
    }
  }

  void _openFile(String path) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier: $path')));
  }

  Future<void> _changeSaveDir() async {
    final ctl = TextEditingController(text: _saveDir);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Dossier de sauvegarde'),
      content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Chemin', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () { setState(() => _saveDir = ctl.text); Navigator.pop(context); _scanCompleted(); }, child: const Text('OK'))],
    ));
  }

  IconData _fileIcon(String ext) => switch (ext.toUpperCase()) {
    'MP4' || 'AVI' || 'MKV' || 'MOV' || 'WEBM' || 'FLV' || 'WMV' || '3GP' => Icons.movie,
    'MP3' || 'FLAC' || 'WAV' || 'AAC' || 'OGG' || 'M4A' || 'WMA' || 'OPUS' => Icons.music_note,
    'JPG' || 'JPEG' || 'PNG' || 'GIF' || 'BMP' || 'WEBP' || 'SVG' || 'HEIC' => Icons.image,
    'PDF' => Icons.picture_as_pdf,
    'ZIP' || 'RAR' || '7Z' || 'TAR' || 'GZ' => Icons.archive,
    'APK' => Icons.android,
    _ => Icons.insert_drive_file,
  };

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    if (b < 1073741824) return '${(b / 1048576).toStringAsFixed(1)} MB';
    return '${(b / 1073741824).toStringAsFixed(1)} GB';
  }
}

class _DownloadTask {
  final String url;
  final String fileName;
  final String savePath;
  double progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool isComplete = false;
  String? error;

  _DownloadTask({required this.url, required this.fileName, required this.savePath});
}
