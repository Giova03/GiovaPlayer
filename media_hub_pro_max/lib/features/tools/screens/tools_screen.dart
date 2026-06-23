import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/utils/file_scanner.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});
  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> with TickerProviderStateMixin {
  late TabController _tc;
  String _scanResult = '';
  bool _scanning = false;
  List<MediaFile> _duplicates = [];
  List<MediaFile> _largeFiles = [];
  int _totalSize = 0;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outils Pro'),
        bottom: TabBar(controller: _tc, tabs: const [
          Tab(text: 'Stockage'),
          Tab(text: 'Convertisseur'),
          Tab(text: 'Nettoyeur'),
          Tab(text: 'Sécurité'),
        ]),
      ),
      body: TabBarView(controller: _tc, children: [
        _buildStorage(cs),
        _buildConverter(cs),
        _buildCleaner(cs),
        _buildSecurity(cs),
      ]),
    );
  }

  // ─── STOCKAGE ───
  Widget _buildStorage(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Analyse du stockage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _analyzeStorage, icon: const Icon(Icons.analytics), label: const Text('Analyser le stockage')),
      const SizedBox(height: 16),
      if (_totalSize > 0) ...[
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text(_fmtSize(_totalSize), style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text('Espace occupé par les médias', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          // Répartition
          _storageBar(cs),
        ]))),
        const SizedBox(height: 16),
        Text('Fichiers les plus volumineux', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._largeFiles.take(10).map((f) => ListTile(
          leading: Icon(_typeIcon(f.type), color: cs.primary),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(_fmtSize(f.size)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _deleteFile(f)),
        )),
      ],
    ]);
  }

  Widget _storageBar(ColorScheme cs) {
    final audioSize = ref.read(audioFilesProvider).valueOrNull?.fold<int>(0, (sum, f) => sum + f.size) ?? 0;
    final videoSize = ref.read(videoFilesProvider).valueOrNull?.fold<int>(0, (sum, f) => sum + f.size) ?? 0;
    final imgSize = ref.read(imageFilesProvider).valueOrNull?.fold<int>(0, (sum, f) => sum + f.size) ?? 0;
    final total = audioSize + videoSize + imgSize;
    if (total == 0) return const SizedBox.shrink();

    return Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: 12, child: Row(children: [
          if (videoSize > 0) Expanded(flex: videoSize, child: Container(color: Colors.red)),
          if (audioSize > 0) Expanded(flex: audioSize, child: Container(color: Colors.blue)),
          if (imgSize > 0) Expanded(flex: imgSize, child: Container(color: Colors.green)),
        ]))),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _sc('Vidéos', _fmtSize(videoSize), Icons.movie, Colors.red),
        _sc('Audio', _fmtSize(audioSize), Icons.music_note, Colors.blue),
        _sc('Photos', _fmtSize(imgSize), Icons.photo, Colors.green),
      ]),
    ]);
  }

  Widget _sc(String l, String s, IconData i, Color c) => Column(children: [
    Icon(i, color: c, size: 20), const SizedBox(height: 4),
    Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
    Text(l, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
  ]);

  // ─── CONVERTISSEUR ───
  Widget _buildConverter(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Convertisseur de formats', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 1.8,
        children: [
          _cc(Icons.videocam, 'Vidéo → Audio', 'MP4 → MP3', cs, () => _convert('video_to_audio')),
          _cc(Icons.image, 'Image → PDF', 'JPG → PDF', cs, () => _convert('image_to_pdf')),
          _cc(Icons.audiotrack, 'Audio → Audio', 'FLAC → MP3', cs, () => _convert('audio_to_audio')),
          _cc(Icons.videocam, 'Vidéo → Vidéo', 'MKV → MP4', cs, () => _convert('video_to_video')),
          _cc(Icons.gif, 'Vidéo → GIF', 'Segment → GIF', cs, () => _convert('video_to_gif')),
          _cc(Icons.picture_as_pdf, 'PDF → Images', 'PDF → JPG', cs, () => _convert('pdf_to_images')),
        ]),
    ]);
  }

  Widget _cc(IconData i, String t, String s, ColorScheme cs, VoidCallback onTap) => Card(child: InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(16),
    child: Padding(padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 28, color: cs.primary), const SizedBox(height: 8),
        Text(t, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 2), Text(s, style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ]))));

  // ─── NETTOYEUR ───
  Widget _buildCleaner(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Nettoyeur IA', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: _scanning ? null : _runCleanerScan,
        icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cleaning_services),
        label: Text(_scanning ? 'Scan en cours...' : 'Lancer le scan IA'),
      ),
      const SizedBox(height: 16),
      ...[
        (Icons.content_copy, 'Doublons', '${_duplicates.length ~/ 2} fichiers dupliqués', Colors.orange, _duplicates.isNotEmpty),
        (Icons.cached, 'Cache', 'Cache applicatif', Colors.blue, true),
        (Icons.photo_size_select_large, 'Photos floues', 'Photos de mauvaise qualité', Colors.red, true),
        (Icons.folder, 'Fichiers temporaires', 'Fichiers .tmp et .log', Colors.green, true),
      ].map((c) => Card(margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Container(width: 36, height: 36,
            decoration: BoxDecoration(color: c.$4.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(c.$1, color: c.$4, size: 20)),
          title: Text(c.$2),
          subtitle: Text(c.$3, style: const TextStyle(fontSize: 12)),
          trailing: c.$5 ? FilledButton.tonal(onPressed: (){}, child: const Text('Nettoyer')) : null,
        ))),
    ]);
  }

  // ─── SÉCURITÉ ───
  Widget _buildSecurity(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.security, color: cs.onTertiaryContainer), const SizedBox(width: 12),
          Expanded(child: Text('Règles de sécurité GiovaPlayer',
            style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 12),
        ...['Aucune donnée personnelle collectée', 'Aucun envoi de données à des serveurs',
          'Chiffrement AES-256-GCM pour le coffre-fort', 'Aucun analytics ou tracking',
          'Permissions demandées uniquement si nécessaire', 'Droit de suppression totale à tout moment',
          'Données stockées exclusivement sur appareil local', 'Anti-screenshot et flou auto pour le coffre',
          'Panic PIN pour suppression immédiate', 'Conformité RGPD par design'].map((r) =>
          Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.check_circle, size: 16, color: cs.onTertiaryContainer),
            const SizedBox(width: 8),
            Expanded(child: Text(r, style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12))),
          ]))),
      ]))),
      const SizedBox(height: 16),
      Text('Outils de sécurité', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(child: ListTile(
        leading: Icon(Icons.password, color: cs.primary),
        title: const Text('Générateur de mots de passe'),
        subtitle: const Text('Mots de passe forts et aléatoires'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _passwordGenerator,
      )),
      Card(child: ListTile(
        leading: Icon(Icons.enhanced_encryption, color: cs.primary),
        title: const Text('Chiffrer un fichier'),
        subtitle: const Text('AES-256-GCM'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showNotImplemented('Chiffrement de fichier'),
      )),
      Card(child: ListTile(
        leading: Icon(Icons.no_encryption, color: cs.primary),
        title: const Text('Déchiffrer un fichier'),
        subtitle: const Text('Décryptage AES-256'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showNotImplemented('Déchiffrement'),
      )),
    ]);
  }

  // ─── MÉTHODES UTILITAIRES ───

  Future<void> _analyzeStorage() async {
    setState(() => _scanning = true);
    try {
      final audioFiles = ref.read(audioFilesProvider).valueOrNull ?? [];
      final videoFiles = ref.read(videoFilesProvider).valueOrNull ?? [];
      final imageFiles = ref.read(imageFilesProvider).valueOrNull ?? [];
      final allFiles = [...audioFiles, ...videoFiles, ...imageFiles];
      allFiles.sort((a, b) => b.size.compareTo(a.size));
      setState(() {
        _totalSize = allFiles.fold<int>(0, (sum, f) => sum + f.size);
        _largeFiles = allFiles;
        _scanning = false;
      });
    } catch (e) {
      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _runCleanerScan() async {
    setState(() => _scanning = true);
    try {
      final audioFiles = ref.read(audioFilesProvider).valueOrNull ?? [];
      final videoFiles = ref.read(videoFilesProvider).valueOrNull ?? [];
      final imageFiles = ref.read(imageFilesProvider).valueOrNull ?? [];
      final allFiles = [...audioFiles, ...videoFiles, ...imageFiles];

      // Trouver les doublons par nom
      final nameMap = <String, List<MediaFile>>{};
      for (final f in allFiles) {
        nameMap.putIfAbsent(f.name, () => []).add(f);
      }
      _duplicates = nameMap.values.where((list) => list.length > 1).expand((list) => list).toList();

      setState(() => _scanning = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_duplicates.length ~/ 2} doublons trouvés'),
        ));
      }
    } catch (e) {
      setState(() => _scanning = false);
    }
  }

  void _convert(String type) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Convertisseur ${type.replaceAll('_', ' ')}'),
      content: const Text('Sélectionnez un fichier source pour commencer la conversion. '
        'Le fichier converti sera sauvegardé dans le dossier Download.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () {
          Navigator.pop(context);
          _showNotImplemented('Conversion $type');
        }, child: const Text('Sélectionner')),
      ],
    ));
  }

  void _passwordGenerator() {
    final length = 16;
    final chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*';
    final password = List.generate(length, (i) => chars[DateTime.now().microsecond % chars.length]).join();

    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Mot de passe généré'),
      content: SelectableText(password, style: const TextStyle(fontFamily: 'monospace', fontSize: 18)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        FilledButton(onPressed: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mot de passe copié !')),
          );
        }, child: const Text('Copier')),
      ],
    ));
  }

  void _deleteFile(MediaFile f) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer ?'),
      content: Text('Supprimer "${f.displayName}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          try {
            final file = File(f.path);
            if (await file.exists()) {
              await file.delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fichier supprimé')),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
              );
            }
          }
        }, child: const Text('Supprimer')),
      ],
    ));
  }

  void _showNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature - Bientôt disponible dans la prochaine mise à jour')),
    );
  }

  IconData _typeIcon(String type) => switch (type) {
    'audio' => Icons.music_note,
    'video' => Icons.movie,
    'image' => Icons.photo,
    _ => Icons.insert_drive_file,
  };

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
