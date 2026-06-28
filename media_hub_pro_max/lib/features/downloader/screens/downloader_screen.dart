import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:permission_handler/permission_handler.dart';
import '../../../core/database/app_database.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});
  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> with TickerProviderStateMixin {
  late TabController _tc;
  final _url = TextEditingController();
  final Dio _dio = Dio();
  final List<_DownloadTask> _activeTasks = [];
  List<Map<String, dynamic>> _history = [];
  String _saveDir = '/storage/emulated/0/Download';
  final _db = AppDatabase.instance;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 3, vsync: this);
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 30);
    _scanCompleted();
    _requestPerm();
  }
  @override
  void dispose() { _tc.dispose(); _url.dispose(); _dio.close(); super.dispose(); }

  Future<void> _requestPerm() async {
    if (Platform.isAndroid) {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> _scanCompleted() async {
    try {
      final history = await _db.getDownloadHistory();
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      debugPrint('_scanCompleted error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Downloader'),
      bottom: TabBar(controller: _tc, tabs: [
        const Tab(text: 'Nouveau'),
        Tab(text: 'En cours (${_activeTasks.length})'),
        Tab(text: 'Terminés (${_history.length})'),
      ])),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _url,
          decoration: InputDecoration(hintText: 'Collez un lien direct (vidéo, audio, fichier...)', prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(icon: const Icon(Icons.download), onPressed: _startDownload),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(28))),
          onSubmitted: (_) => _startDownload())),
        Expanded(child: TabBarView(controller: _tc, children: [
          _newTab(cs),
          _inProgressTab(cs),
          _completedTab(cs),
        ])),
      ]),
    );
  }

  Widget _newTab(ColorScheme cs) => ListView(padding: const EdgeInsets.all(16), children: [
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
  ]);

  Widget _inProgressTab(ColorScheme cs) {
    if (_activeTasks.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_download, size: 64, color: Colors.grey[400]), const SizedBox(height: 16), const Text('Aucun téléchargement en cours')]));
    }
    return ListView.builder(itemCount: _activeTasks.length, itemBuilder: (_, i) {
      final task = _activeTasks[i];
      return Card(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(task.isComplete ? Icons.check_circle : Icons.downloading, color: task.isComplete ? Colors.green : cs.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(task.fileName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
          if (!task.isComplete) IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => _cancelTask(i)),
        ]),
        const SizedBox(height: 8),
        if (task.isComplete)
          Text('Terminé - ${_fmtSize(task.downloadedBytes)}', style: const TextStyle(fontSize: 12, color: Colors.green))
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
    });
  }

  Widget _completedTab(ColorScheme cs) {
    if (_history.isEmpty) {
      return const Center(child: Text('Aucun téléchargement'));
    }
    return RefreshIndicator(onRefresh: _scanCompleted, child: ListView.builder(itemCount: _history.length, itemBuilder: (_, i) {
      final item = _history[i];
      final name = item['file_name'] as String? ?? 'Fichier';
      final size = item['file_size'] as int? ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(item['created_at'] as int);
      return Dismissible(
        key: Key('dl_${item['id']}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) async { await _db.deleteDownloadHistory(item['id'] as int); _scanCompleted(); },
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: ListTile(
          leading: Icon(Icons.download_done, color: cs.primary),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${_fmtSize(size)} • ${date.day}/${date.month}/${date.year}', style: const TextStyle(fontSize: 11)),
        ),
      );
    }));
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

    // Block private/localhost URLs (SSRF protection)
    if (url.contains('localhost') || url.contains('127.0.0.1') || url.contains('169.254.169.254') || RegExp(r'192\.168\.').hasMatch(url) || RegExp(r'10\.\d+\.').hasMatch(url)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('URL non autorisée (réseau privé)'), backgroundColor: Colors.red));
      return;
    }

    String fileName;
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isNotEmpty) {
        fileName = Uri.decodeComponent(pathSegments.last);
        // Sanitize filename (remove path traversal)
        fileName = fileName.replaceAll('..', '').replaceAll('/', '').replaceAll('\\', '');
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
    final cancelToken = CancelToken();
    final task = _DownloadTask(url: url, fileName: fileName, savePath: savePath, cancelToken: cancelToken);
    setState(() => _activeTasks.add(task));
    _url.clear();
    _tc.animateTo(1);

    try {
      await _dio.download(
        url, savePath,
        cancelToken: cancelToken,
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
        setState(() { task.isComplete = true; task.progress = 1.0; });
        final fileSize = await File(savePath).length();
        await _db.insertDownloadHistory(url, fileName, savePath, fileSize, 'completed');
        _scanCompleted();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Téléchargement terminé: $fileName')));
        // Remove from active after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _activeTasks.remove(task));
        });
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        if (mounted) setState(() => _activeTasks.remove(task));
      } else if (mounted) {
        setState(() { task.error = e.message ?? 'Erreur de téléchargement'; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.message}'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() { task.error = e.toString(); });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelTask(int index) {
    if (index >= 0 && index < _activeTasks.length) {
      _activeTasks[index].cancelToken.cancel();
      setState(() => _activeTasks.removeAt(index));
    }
  }

  Future<void> _changeSaveDir() async {
    final ctl = TextEditingController(text: _saveDir);
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Dossier de sauvegarde'),
      content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Chemin', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () { setState(() => _saveDir = ctl.text); Navigator.pop(context); }, child: const Text('OK'))],
    ));
  }

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
  final CancelToken cancelToken;
  double progress = 0;
  int downloadedBytes = 0;
  int totalBytes = 0;
  bool isComplete = false;
  String? error;

  _DownloadTask({required this.url, required this.fileName, required this.savePath, required this.cancelToken});
}
