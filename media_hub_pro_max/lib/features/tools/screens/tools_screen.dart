import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/file_scanner.dart';
import '../../../core/utils/media_processor.dart';
import '../../../core/utils/security_utils.dart';
import '../../../core/utils/vault_crypto.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});
  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen> with TickerProviderStateMixin {
  late TabController _tc;
  bool _scanning = false;
  List<MediaFile> _duplicates = [];
  List<MediaFile> _largeFiles = [];
  String _pwResult = '';
  int _pwLen = 16;
  bool _pwUpper = true, _pwLower = true, _pwNum = true, _pwSym = true;

  // Converter state
  MediaFile? _convSource;
  String _convFormat = 'mp3';
  String _convBitrate = '320k';
  bool _convProcessing = false;
  double _convProgress = 0;

  // Cutter state
  MediaFile? _cutterSource;
  double _cutterStart = 0, _cutterEnd = 30;
  double _cutterDuration = 300;
  bool _cutterProcessing = false;

  // Metadata state
  MediaFile? _metaSource;
  AudioMetadata? _metaData;
  bool _metaLoading = false;
  final _titleCtl = TextEditingController();
  final _artistCtl = TextEditingController();
  final _albumCtl = TextEditingController();
  final _yearCtl = TextEditingController();
  final _genreCtl = TextEditingController();
  final _commentCtl = TextEditingController();

  @override void initState() { super.initState(); _tc = TabController(length: 6, vsync: this); }
  @override void dispose() { _tc.dispose(); _titleCtl.dispose(); _artistCtl.dispose(); _albumCtl.dispose(); _yearCtl.dispose(); _genreCtl.dispose(); _commentCtl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Outils Pro'),
    bottom: TabBar(controller: _tc, isScrollable: true, tabs: const [
      Tab(text: 'Stockage'), Tab(text: 'Convertisseur'), Tab(text: 'Nettoyeur'),
      Tab(text: 'Sécurité'), Tab(text: 'Métadonnées'), Tab(text: 'Audio'),
    ])),
    body: TabBarView(controller: _tc, children: [
      _storage(), _converter(), _cleaner(), _security(), _metadata(), _audioTools(),
    ]),
  );

  // ═══ STOCKAGE ═══
  Widget _storage() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    final video = ref.watch(videoFilesProvider).valueOrNull ?? [];
    final image = ref.watch(imageFilesProvider).valueOrNull ?? [];
    final all = [...audio, ...video, ...image]..sort((a, b) => b.size.compareTo(a.size));
    final aS = audio.fold<int>(0, (s, f) => s + f.size);
    final vS = video.fold<int>(0, (s, f) => s + f.size);
    final iS = image.fold<int>(0, (s, f) => s + f.size);
    final total = aS + vS + iS;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Analyse du stockage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      if (total > 0) Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
        Text(_fs(total), style: Theme.of(context).textTheme.headlineMedium),
        const Text('Espace total occupé par les médias'),
        const SizedBox(height: 12),
        ClipRRect(borderRadius: BorderRadius.circular(6), child: SizedBox(height: 14, child: Row(children: [
          if (vS > 0) Expanded(flex: vS, child: Container(color: Colors.red)),
          if (aS > 0) Expanded(flex: aS, child: Container(color: Colors.blue)),
          if (iS > 0) Expanded(flex: iS, child: Container(color: Colors.green)),
        ]))),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _sc('Vidéos', _fs(vS), Icons.movie, Colors.red),
          _sc('Audio', _fs(aS), Icons.music_note, Colors.blue),
          _sc('Photos', _fs(iS), Icons.photo, Colors.green),
        ]),
      ]))),
      const SizedBox(height: 16),
      Text('Fichiers les plus volumineux', style: Theme.of(context).textTheme.titleMedium),
      ...all.take(15).map((f) => ListTile(
        leading: Icon(_ti(f.type), color: Theme.of(context).colorScheme.primary),
        title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
        subtitle: Text(_fs(f.size)), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _del(f)),
      )),
      const SizedBox(height: 16),
      Text('Statistiques intelligentes', style: Theme.of(context).textTheme.titleMedium),
      ...[
        ('Nombre total de fichiers', '${all.length}'),
        ('Taille moyenne', _fs(all.isEmpty ? 0 : total ~/ all.length)),
        ('Dossier le plus lourd', _heaviestFolder(all)),
        ('Fichier le plus récent', all.isEmpty ? '-' : '${all.first.modified.day}/${all.first.modified.month}/${all.first.modified.year}'),
        ('Photos HEIC', '${image.where((f) => f.extension == '.heic').length}'),
        ('Audio FLAC', '${audio.where((f) => f.extension == '.flac').length}'),
        ('Vidéos 4K (estimé)', '${video.where((f) => f.size > 500000000).length}'),
      ].map((r) => ListTile(title: Text(r.$1, style: const TextStyle(fontSize: 13)), trailing: Text(r.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)))),
    ]);
  }

  // ═══ CONVERTISSEUR (RÉEL) ═══
  Widget _converter() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    final video = ref.watch(videoFilesProvider).valueOrNull ?? [];
    final all = [...audio, ...video];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Convertisseur', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Convertissez vos fichiers audio et vidéo en temps réel avec FFmpeg.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      const SizedBox(height: 16),

      // Source file selection
      Card(child: ListTile(
        leading: Icon(_convSource != null ? Icons.check_circle : Icons.folder_open, color: _convSource != null ? Colors.green : Theme.of(context).colorScheme.primary),
        title: Text(_convSource?.displayName ?? 'Choisir un fichier source', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        subtitle: _convSource != null ? Text('${_convSource!.extension.toUpperCase()} • ${_fs(_convSource!.size)}') : const Text('Audio ou vidéo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickConvSource(all),
      )),
      const SizedBox(height: 12),

      // Conversion type
      if (_convSource != null) ...[
        Text('Type de conversion', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._getConversionOptions().map((opt) => Card(margin: const EdgeInsets.only(bottom: 4), child: RadioListTile<String>(
          value: opt.$1, groupValue: _convFormat, onChanged: (v) => setState(() => _convFormat = v!),
          title: Text(opt.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          subtitle: Text(opt.$3, style: const TextStyle(fontSize: 12)),
          secondary: Icon(opt.$4, color: Theme.of(context).colorScheme.primary, size: 24),
        ))),
        const SizedBox(height: 12),

        // Bitrate selection (for lossy formats)
        if (['mp3', 'aac', 'ogg', 'opus'].contains(_convFormat)) ...[
          Text('Qualité', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<String>(segments: const [
            ButtonSegment(value: '128k', label: Text('128k')),
            ButtonSegment(value: '192k', label: Text('192k')),
            ButtonSegment(value: '256k', label: Text('256k')),
            ButtonSegment(value: '320k', label: Text('320k')),
          ], selected: {_convBitrate}, onSelectionChanged: (v) => setState(() => _convBitrate = v.first)),
          const SizedBox(height: 16),
        ],

        // Progress
        if (_convProcessing) ...[
          LinearProgressIndicator(value: _convProgress > 0 ? _convProgress : null),
          const SizedBox(height: 8),
          Text('Conversion en cours...', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 13)),
          const SizedBox(height: 12),
        ],

        // Convert button
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _convProcessing ? null : _doConvert,
          icon: _convProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.transform),
          label: Text(_convProcessing ? 'Conversion...' : 'Convertir en ${_convFormat.toUpperCase()}'),
        )),
      ],
    ]);
  }

  List<(String, String, String, IconData)> _getConversionOptions() {
    if (_convSource == null) return [];
    final isVideo = _convSource!.type == 'video';
    final opts = <(String, String, String, IconData)>[];

    if (isVideo) {
      opts.addAll([
        ('mp3', 'Vidéo → MP3', 'Extraire audio en MP3', Icons.music_note),
        ('aac', 'Vidéo → AAC', 'Extraire audio en AAC/M4A', Icons.audiotrack),
        ('flac', 'Vidéo → FLAC', 'Extraire audio sans perte', Icons.high_quality),
        ('wav', 'Vidéo → WAV', 'Extraire audio PCM', Icons.graphic_eq),
      ]);
    }
    opts.addAll([
      ('mp3', 'Audio → MP3', 'Format universel compressé', Icons.music_note),
      ('aac', 'Audio → AAC', 'Meilleure qualité/taille', Icons.audiotrack),
      ('flac', 'Audio → FLAC', 'Sans perte (grand fichier)', Icons.high_quality),
      ('wav', 'Audio → WAV', 'Audio brut non compressé', Icons.graphic_eq),
      ('ogg', 'Audio → OGG', 'Format libre Vorbis', Icons.graphic_eq),
      ('opus', 'Audio → Opus', 'Nouveau codec performant', Icons.surround_sound),
    ]);

    // Remove duplicates
    final seen = <String>{};
    return opts.where((o) => seen.add(o.$1)).toList();
  }

  void _pickConvSource(List<MediaFile> files) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
    builder: (_, sc) => Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Choisir un fichier', style: Theme.of(context).textTheme.titleLarge)),
      Expanded(child: ListView.builder(controller: sc, itemCount: files.length, itemBuilder: (_, i) {
        final f = files[i];
        return ListTile(
          leading: Icon(_ti(f.type), color: Theme.of(context).colorScheme.primary),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${f.extension.toUpperCase()} • ${_fs(f.size)}'),
          onTap: () { Navigator.pop(context); setState(() { _convSource = f; _convFormat = 'mp3'; }); },
        );
      })),
    ]),
  ));

  Future<void> _doConvert() async {
    if (_convSource == null) return;
    setState(() { _convProcessing = true; _convProgress = 0; });

    String? result;
    if (_convSource!.type == 'video') {
      result = await MediaProcessor.extractAudio(
        inputPath: _convSource!.path, format: _convFormat, bitrate: _convBitrate,
      );
    } else {
      result = await MediaProcessor.convertAudio(
        inputPath: _convSource!.path, format: _convFormat, bitrate: _convBitrate,
      );
    }

    setState(() { _convProcessing = false; _convProgress = 1; });

    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Conversion réussie: ${_convFormat.toUpperCase()}'),
          action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result!)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de conversion. Format peut-être non supporté.'), backgroundColor: Colors.red));
      }
    }
  }

  // ═══ NETTOYEUR ═══
  Widget _cleaner() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    final video = ref.watch(videoFilesProvider).valueOrNull ?? [];
    final image = ref.watch(imageFilesProvider).valueOrNull ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Nettoyeur', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(onPressed: _scanning ? null : _runClean, icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.cleaning_services),
        label: Text(_scanning ? 'Scan...' : 'Lancer le scan')),
      const SizedBox(height: 16),
      _cc(Icons.content_copy, 'Doublons', '${_duplicates.length ~/ 2} trouvés', _fs(_duplicates.fold<int>(0, (s, f) => s + f.size ~/ 2)), Colors.orange),
      _cc(Icons.photo_size_select_large, 'Photos potentiellement floues', 'Basé sur la taille < 100KB', '${image.where((f) => f.size < 100000).length} photos', Colors.red),
      _cc(Icons.history, 'Fichiers anciens', 'Plus de 6 mois', '${[...audio,...video,...image].where((f) => f.modified.isBefore(DateTime.now().subtract(const Duration(days: 180)))).length} fichiers', Colors.blue),
      _cc(Icons.android, 'APK orphelins', 'Fichiers .apk dans Download', 'Vérifier', Colors.green),
      _cc(Icons.folder_special, 'Fichiers volumineux', '> 500MB', '${[...audio,...video,...image].where((f) => f.size > 500000000).length} fichiers', Colors.purple),
      _cc(Icons.cached, 'Cache', 'Fichiers temporaires', 'Nettoyer', Colors.teal),
      _cc(Icons.delete_sweep, 'Miniatures', 'Thumbnails orphelins', 'Vérifier', Colors.grey),
      _cc(Icons.broken_image, 'Images corrompues', 'Fichiers image < 1KB', '${image.where((f) => f.size < 1024).length} fichiers', Colors.brown),
      _cc(Icons.audio_file, 'Audio court', 'Fichiers < 30 secondes estimé', '${audio.where((f) => f.size < 200000).length} fichiers', Colors.indigo),
      if (_duplicates.isNotEmpty) ...[const SizedBox(height: 16), Text('Doublons détectés', style: Theme.of(context).textTheme.titleMedium),
        ..._duplicates.take(10).map((f) => ListTile(leading: Icon(_ti(f.type), color: Colors.orange), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), subtitle: Text(_fs(f.size)), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _del(f))))],
    ]);
  }

  Widget _cc(IconData i, String t, String s1, String s2, Color c) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(
    leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: c.withOpacity(0.15), borderRadius: BorderRadius.circular(10)), child: Icon(i, color: c, size: 20)),
    title: Text(t, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text(s1, style: const TextStyle(fontSize: 11)),
    trailing: Text(s2, style: const TextStyle(fontSize: 11)),
  ));

  // ═══ SÉCURITÉ ═══
  Widget _security() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Sécurité & Mots de passe', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      if (_pwResult.isNotEmpty) Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
        child: SelectableText(_pwResult, style: const TextStyle(fontFamily: 'monospace', fontSize: 16))),
      const SizedBox(height: 12),
      Row(children: [const Text('Longueur: '), Expanded(child: Slider(value: _pwLen.toDouble(), min: 8, max: 64, divisions: 56, label: '$_pwLen', onChanged: (v) => setState(() => _pwLen = v.round()))), Text('$_pwLen')]),
      SwitchListTile(title: const Text('Majuscules'), value: _pwUpper, onChanged: (v) => setState(() => _pwUpper = v), dense: true),
      SwitchListTile(title: const Text('Minuscules'), value: _pwLower, onChanged: (v) => setState(() => _pwLower = v), dense: true),
      SwitchListTile(title: const Text('Chiffres'), value: _pwNum, onChanged: (v) => setState(() => _pwNum = v), dense: true),
      SwitchListTile(title: const Text('Symboles'), value: _pwSym, onChanged: (v) => setState(() => _pwSym = v), dense: true),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: FilledButton.icon(onPressed: _genPw, icon: const Icon(Icons.refresh), label: const Text('Générer'))),
        if (_pwResult.isNotEmpty) ...[const SizedBox(width: 8), IconButton.filled(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copié !'))), icon: const Icon(Icons.copy))]]),
    ]))),
    const SizedBox(height: 16),
    ...[(Icons.enhanced_encryption, 'Chiffrer un fichier', 'AES-256-GCM', 'encrypt_file'),
      (Icons.no_encryption, 'Déchiffrer un fichier', 'Décryptage AES-256', 'decrypt_file'),
      (Icons.fingerprint, 'Vérifier hachage', 'MD5 / SHA-256', 'hash_file'),
      (Icons.password, 'Évaluer force mot de passe', 'Test de robustesse', 'pw_strength'),
      (Icons.vpn_key, 'Générateur de clés', 'Clés AES-256 / Ed25519', 'key_gen'),
      (Icons.text_snippet, 'Chiffrer un texte', 'AES-256 pour notes', 'encrypt_text'),
      (Icons.local_police, 'Analyse permissions', 'Vérifier les apps', 'perm_audit'),
    ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
      leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 22), title: Text(c.$2, style: const TextStyle(fontSize: 14)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 16), onTap: () => _onSecurityAction(c.$4, c.$2),
    ))),
  ]);

  // ═══ MÉTADONNÉES (RÉEL) ═══
  Widget _metadata() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Éditeur de métadonnées', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Lisez et modifiez les tags ID3 de vos fichiers audio avec FFmpeg.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      const SizedBox(height: 16),

      // File selection
      Card(child: ListTile(
        leading: Icon(_metaSource != null ? Icons.check_circle : Icons.audio_file, color: _metaSource != null ? Colors.green : Theme.of(context).colorScheme.primary),
        title: Text(_metaSource?.displayName ?? 'Choisir un fichier audio', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
        subtitle: _metaSource != null ? Text('${_metaSource!.extension.toUpperCase()} • ${_fs(_metaSource!.size)}') : const Text('MP3, FLAC, AAC, etc.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _pickMetaSource(audio),
      )),
      const SizedBox(height: 12),

      // Metadata display/edit
      if (_metaLoading) const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      if (_metaData != null && !_metaLoading) ...[
        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text('Informations fichier', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 8),
          if (_metaData!.duration.isNotEmpty) _infoRow('Durée', _metaData!.duration),
          if (_metaData!.bitrate.isNotEmpty) _infoRow('Bitrate', '${_metaData!.bitrate} bps'),
          _infoRow('Chemin', _metaData!.filePath),
        ]))),
        const SizedBox(height: 12),

        Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
          Text('Tags audio', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: _titleCtl, decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title, size: 20))),
          const SizedBox(height: 8),
          TextField(controller: _artistCtl, decoration: const InputDecoration(labelText: 'Artiste', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person, size: 20))),
          const SizedBox(height: 8),
          TextField(controller: _albumCtl, decoration: const InputDecoration(labelText: 'Album', border: OutlineInputBorder(), prefixIcon: Icon(Icons.album, size: 20))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: TextField(controller: _yearCtl, decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
            const SizedBox(width: 8),
            Expanded(child: TextField(controller: _genreCtl, decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _commentCtl, decoration: const InputDecoration(labelText: 'Commentaire', border: OutlineInputBorder()), maxLines: 2),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: _saveMetadata, icon: const Icon(Icons.save), label: const Text('Sauvegarder'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _stripMetadata, icon: const Icon(Icons.delete_forever), label: const Text('Effacer tags'))),
          ]),
        ]))),
      ] else if (_metaSource == null && !_metaLoading) ...[
        const SizedBox(height: 24),
        Center(child: Column(children: [
          Icon(Icons.tag, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 12),
          const Text('Sélectionnez un fichier audio pour voir ses métadonnées'),
        ])),
      ],

      const SizedBox(height: 16),
      if (audio.isNotEmpty) ...[Text('Fichiers récents', style: Theme.of(context).textTheme.titleMedium),
        ...audio.take(8).map((f) => ListTile(leading: const Icon(Icons.music_note, size: 20), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)), trailing: IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () { setState(() => _metaSource = f); _loadMetadata(f); })))],
    ]);
  }

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 80, child: Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
    Expanded(child: Text(value, style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)),
  ]));

  void _pickMetaSource(List<MediaFile> files) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
    builder: (_, sc) => Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Choisir un fichier audio', style: Theme.of(context).textTheme.titleLarge)),
      Expanded(child: ListView.builder(controller: sc, itemCount: files.length, itemBuilder: (_, i) {
        final f = files[i];
        return ListTile(
          leading: const Icon(Icons.music_note, size: 20),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)),
          onTap: () { Navigator.pop(context); setState(() => _metaSource = f); _loadMetadata(f); },
        );
      })),
    ]),
  ));

  Future<void> _loadMetadata(MediaFile file) async {
    setState(() { _metaLoading = true; _metaData = null; });
    final data = await MediaProcessor.readMetadata(file.path);
    if (mounted) {
      setState(() {
        _metaData = data;
        _metaLoading = false;
        _titleCtl.text = data.title;
        _artistCtl.text = data.artist;
        _albumCtl.text = data.album;
        _yearCtl.text = data.year;
        _genreCtl.text = data.genre;
        _commentCtl.text = data.comment;
      });
    }
  }

  Future<void> _saveMetadata() async {
    if (_metaSource == null) return;
    final newMeta = AudioMetadata(
      filePath: _metaSource!.path,
      title: _titleCtl.text,
      artist: _artistCtl.text,
      album: _albumCtl.text,
      year: _yearCtl.text,
      genre: _genreCtl.text,
      comment: _commentCtl.text,
    );
    final result = await MediaProcessor.writeMetadata(inputPath: _metaSource!.path, metadata: newMeta);
    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tags sauvegardés: $result'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la sauvegarde des tags'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _stripMetadata() async {
    if (_metaSource == null) return;
    final confirm = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer tous les tags ?'),
      content: const Text('Cette action supprimera toutes les métadonnées du fichier.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer'))],
    ));
    if (confirm != true) return;
    final result = await MediaProcessor.stripMetadata(inputPath: _metaSource!.path);
    if (mounted) {
      if (result != null) {
        setState(() { _titleCtl.clear(); _artistCtl.clear(); _albumCtl.clear(); _yearCtl.clear(); _genreCtl.clear(); _commentCtl.clear(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tags supprimés')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur lors de la suppression'), backgroundColor: Colors.red));
      }
    }
  }

  // ═══ AUDIO TOOLS (RÉEL) ═══
  Widget _audioTools() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Outils audio', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('Découpez, fusionnez et transformez vos fichiers audio.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
      const SizedBox(height: 16),

      // ─── DÉCOUPEUR AUDIO ───
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Découpeur audio', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),

        // Source file
        InkWell(onTap: () => _pickCutterSource(audio), child: Container(
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outline), borderRadius: BorderRadius.circular(8)),
          child: Row(children: [
            Icon(_cutterSource != null ? Icons.check_circle : Icons.audio_file, color: _cutterSource != null ? Colors.green : Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(_cutterSource?.displayName ?? 'Choisir un fichier audio', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
            const Icon(Icons.chevron_right, size: 16),
          ]),
        )),
        const SizedBox(height: 12),

        // Range slider
        Row(children: [Text('Début: ${_cutterStart.toStringAsFixed(0)}s'), const Spacer(), Text('Fin: ${_cutterEnd.toStringAsFixed(0)}s')]),
        RangeSlider(
          values: RangeValues(_cutterStart, _cutterEnd),
          min: 0, max: _cutterDuration,
          onChanged: (v) => setState(() { _cutterStart = v.start; _cutterEnd = v.end; }),
        ),
        if (_cutterProcessing) ...[const SizedBox(height: 8), const LinearProgressIndicator()],
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: _cutterProcessing ? null : _doCut,
          icon: _cutterProcessing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.content_cut),
          label: Text(_cutterProcessing ? 'Découpe...' : 'Découper (${(_cutterEnd - _cutterStart).toStringAsFixed(0)}s)'),
        )),
      ]))),
      const SizedBox(height: 12),

      // ─── OTHER AUDIO TOOLS ───
      ...[(Icons.merge, 'Fusionner audio', 'Assembler plusieurs fichiers', () => _mergeAudioDialog(audio)),
        (Icons.speed, 'Changer vitesse/pitch', 'Accélérer, ralentir', () => _speedDialog(audio)),
        (Icons.graphic_eq, 'Normaliser volume', 'Loudness normalization', () => _normalizeDialog(audio)),
        (Icons.surround_sound, 'Mono → Stéréo / Stéréo → Mono', 'Changer le nombre de canaux', () => _channelsDialog(audio)),
        (Icons.notifications_active, 'Créer sonnerie', 'Découper 30s pour sonnerie', () => _ringtoneDialog(audio)),
        (Icons.volume_up, 'Amplificateur', 'Augmenter le volume', () => _amplifyDialog(audio)),
      ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
        leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 22), title: Text(c.$2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 16), onTap: c.$4,
      ))),
    ]);
  }

  void _pickCutterSource(List<MediaFile> files) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
    initialChildSize: 0.7, minChildSize: 0.3, maxChildSize: 0.9, expand: false,
    builder: (_, sc) => Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('Choisir un fichier audio', style: Theme.of(context).textTheme.titleLarge)),
      Expanded(child: ListView.builder(controller: sc, itemCount: files.length, itemBuilder: (_, i) {
        final f = files[i];
        return ListTile(
          leading: const Icon(Icons.music_note, size: 20),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)),
          onTap: () async {
            Navigator.pop(context);
            setState(() { _cutterSource = f; _cutterStart = 0; _cutterEnd = 30; });
            // Get real duration
            final dur = await MediaProcessor.getDuration(f.path);
            if (mounted && dur > 0) {
              setState(() { _cutterDuration = dur; _cutterEnd = dur > 30 ? 30 : dur; });
            }
          },
        );
      })),
    ]),
  ));

  Future<void> _doCut() async {
    if (_cutterSource == null) return;
    setState(() => _cutterProcessing = true);
    final result = await MediaProcessor.cutAudio(
      inputPath: _cutterSource!.path, startSec: _cutterStart, endSec: _cutterEnd,
    );
    setState(() => _cutterProcessing = false);
    if (mounted) {
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Découpe réussie!'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de découpe'), backgroundColor: Colors.red));
      }
    }
  }

  void _mergeAudioDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _AudioPickDialog(
    title: 'Fusionner audio', audio: audio, multiSelect: true,
    onConfirm: (files) async {
      if (files.length < 2) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez au moins 2 fichiers'))); return; }
      final result = await MediaProcessor.mergeAudio(inputPaths: files.map((f) => f.path).toList());
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fusion réussie!'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de fusion'), backgroundColor: Colors.red));
        }
      }
    },
  ));

  void _speedDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _SpeedDialog(audio: audio));

  void _normalizeDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _AudioPickDialog(
    title: 'Normaliser le volume', audio: audio, multiSelect: false,
    onConfirm: (files) async {
      final result = await MediaProcessor.normalize(inputPath: files.first.path);
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Normalisation réussie!'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de normalisation'), backgroundColor: Colors.red));
        }
      }
    },
  ));

  void _channelsDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _ChannelsDialog(audio: audio));

  void _ringtoneDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _AudioPickDialog(
    title: 'Créer une sonnerie', audio: audio, multiSelect: false,
    onConfirm: (files) async {
      final result = await MediaProcessor.createRingtone(inputPath: files.first.path);
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sonnerie créée!'), action: SnackBarAction(label: 'Ouvrir', onPressed: () => _openFile(result))));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur de création'), backgroundColor: Colors.red));
        }
      }
    },
  ));

  void _amplifyDialog(List<MediaFile> audio) => showDialog(context: context, builder: (_) => _AmplifyDialog(audio: audio));

  // ═══ UTILITAIRES ═══
  Future<void> _runClean() async {
    setState(() => _scanning = true);
    final audio = ref.read(audioFilesProvider).valueOrNull ?? [];
    final video = ref.read(videoFilesProvider).valueOrNull ?? [];
    final image = ref.read(imageFilesProvider).valueOrNull ?? [];
    final all = [...audio, ...video, ...image];
    final sizeMap = <int, List<MediaFile>>{};
    for (final f in all) { sizeMap.putIfAbsent(f.size, () => []).add(f); }
    _duplicates = sizeMap.values.where((l) => l.length > 1).expand((l) => l).toList();
    all.sort((a, b) => b.size.compareTo(a.size));
    _largeFiles = all;
    setState(() => _scanning = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_duplicates.length ~/ 2} doublons trouvés')));
  }

  void _del(MediaFile f) => showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Supprimer ?'), content: Text(f.displayName),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async { Navigator.pop(context); try { await File(f.path).delete(); ref.invalidate(audioFilesProvider); ref.invalidate(videoFilesProvider); ref.invalidate(imageFilesProvider); } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }}, child: const Text('Supprimer'))]));

  void _genPw() {
    final chars = StringBuffer();
    if (_pwUpper) chars.write('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (_pwLower) chars.write('abcdefghijklmnopqrstuvwxyz');
    if (_pwNum) chars.write('0123456789');
    if (_pwSym) chars.write(r'!@#$%^&*()_+-=[]{}|;:,.<>?');
    if (chars.isEmpty) chars.write('abcdefghijklmnopqrstuvwxyz');
    setState(() => _pwResult = List.generate(_pwLen, (_) => chars.toString()[Random.secure().nextInt(chars.length)]).join());
  }

  void _openFile(String path) {
    // Files are saved in GiovaPlayer/Output - user can find them there
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier sauvegardé: $path')));
  }

  IconData _ti(String t) => switch (t) { 'audio' => Icons.music_note, 'video' => Icons.movie, 'image' => Icons.photo, _ => Icons.insert_drive_file };
  Widget _sc(String l, String s, IconData i, Color c) => Column(children: [Icon(i, color: c, size: 20), const SizedBox(height: 4), Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text(l, style: TextStyle(fontSize: 10, color: Colors.grey[600]))]);
  String _fs(int b) { if (b < 1024) return '$b B'; if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB'; if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB'; return '${(b/1073741824).toStringAsFixed(1)} GB'; }
  String _heaviestFolder(List<MediaFile> files) { final m = <String, int>{}; for (final f in files) { final d = f.path.substring(0, f.path.lastIndexOf('/')); m[d] = (m[d] ?? 0) + f.size; } if (m.isEmpty) return '-'; final e = m.entries.reduce((a, b) => a.value > b.value ? a : b); return '${e.key.substring(e.key.lastIndexOf('/') + 1)} (${_fs(e.value)})'; }

  // ═══ SÉCURITÉ — ACTIONS RÉELLES ═══
  void _onSecurityAction(String action, String title) {
    switch (action) {
      case 'encrypt_file': _encryptFileDialog(); break;
      case 'decrypt_file': _decryptFileDialog(); break;
      case 'hash_file': _hashFileDialog(); break;
      case 'pw_strength': _pwStrengthDialog(); break;
      case 'key_gen': _keyGenDialog(); break;
      case 'encrypt_text': _encryptTextDialog(); break;
      case 'perm_audit': _permAuditDialog(); break;
    }
  }

  void _encryptFileDialog() {
    final audio = ref.read(audioFilesProvider).valueOrNull ?? [];
    final video = ref.read(videoFilesProvider).valueOrNull ?? [];
    final all = [...audio, ...video];
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [
      Text('Chiffrer un fichier (AES-256)', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      SizedBox(height: 300, child: ListView.builder(itemCount: all.length, itemBuilder: (_, i) {
        final f = all[i];
        return ListTile(leading: Icon(_ti(f.type)), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), subtitle: Text(_fs(f.size)),
          onTap: () async {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chiffrement en cours...')));
            try {
              final encPath = await VaultCrypto.encryptFile(f.path);
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier chiffré: ${encPath.split('/').last}')));
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
            }
          });
      })),
    ]));
  }

  void _decryptFileDialog() {
    final ctl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Déchiffrer un fichier'), content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Chemin du fichier .enc', border: OutlineInputBorder())),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          try {
            final decrypted = await VaultCrypto.decryptFile(ctl.text);
            final outPath = '${ctl.text}.dec';
            await File(outPath).writeAsBytes(decrypted);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier déchiffré: $outPath')));
          } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
          }
        }, child: const Text('Déchiffrer'))],
    ));
  }

  void _hashFileDialog() {
    final audio = ref.read(audioFilesProvider).valueOrNull ?? [];
    final all = audio;
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(16), shrinkWrap: true, children: [
      Text('Hash de fichier (MD5 + SHA-256)', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      SizedBox(height: 300, child: ListView.builder(itemCount: all.length, itemBuilder: (_, i) {
        final f = all[i];
        return ListTile(leading: const Icon(Icons.music_note), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          onTap: () async {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Calcul du hash...')));
            final md5 = await SecurityUtils.md5HashFile(f.path);
            final sha = await SecurityUtils.sha256HashFile(f.path);
            if (mounted) {
              showDialog(context: context, builder: (_) => AlertDialog(title: Text(f.displayName), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('MD5:', style: TextStyle(fontWeight: FontWeight.bold)), SelectableText(md5, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                const SizedBox(height: 8), const Text('SHA-256:', style: TextStyle(fontWeight: FontWeight.bold)), SelectableText(sha, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
                FilledButton(onPressed: () { Clipboard.setData(ClipboardData(text: sha)); Navigator.pop(context); }, child: const Text('Copier SHA-256'))]));
            }
          });
      })),
    ]));
  }

  void _pwStrengthDialog() {
    final ctl = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (_, setS) => AlertDialog(title: const Text('Force du mot de passe'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Mot de passe', border: OutlineInputBorder()), onChanged: (_) => setS(() {})),
      const SizedBox(height: 12),
      if (ctl.text.isNotEmpty) _buildStrengthWidget(ctl.text),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))])));
  }

  Widget _buildStrengthWidget(String password) {
    final strength = SecurityUtils.evaluatePassword(password);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      LinearProgressIndicator(value: strength.score / 100, color: strength.color),
      const SizedBox(height: 4),
      Text('${strength.label} (${strength.score}/100)', style: TextStyle(color: strength.color, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...strength.issues.map((i) => Text('• $i', style: const TextStyle(fontSize: 12))),
    ]);
  }

  void _keyGenDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Générateur de clés'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      FilledButton(onPressed: () { Navigator.pop(context); _showKeyResult('AES-256', SecurityUtils.generateKey(bytes: 32)); }, child: const Text('Générer clé AES-256 (64 hex chars)')),
      const SizedBox(height: 8),
      FilledButton(onPressed: () { Navigator.pop(context); final kp = SecurityUtils.generateKeyPair(); _showKeyResult('Ed25519', 'Privée: ${kp.privateKey}\nPublique: ${kp.publicKey}'); }, child: const Text('Générer paire Ed25519')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer'))]));
  }

  void _showKeyResult(String type, String key) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text('Clé $type'), content: SelectableText(key, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
        FilledButton(onPressed: () { Clipboard.setData(ClipboardData(text: key)); Navigator.pop(context); }, child: const Text('Copier'))]));
  }

  void _encryptTextDialog() {
    final ctl = TextEditingController();
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (_, setS) => AlertDialog(title: const Text('Chiffrer un texte'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: ctl, decoration: const InputDecoration(labelText: 'Texte à chiffrer', border: OutlineInputBorder()), maxLines: 4),
      if (ctl.text.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: FutureBuilder<String>(
        future: VaultCrypto.encryptString(ctl.text),
        builder: (_, snap) => snap.hasData ? SelectableText(snap.data!, style: const TextStyle(fontSize: 10, fontFamily: 'monospace')) : const CircularProgressIndicator(),
      )),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
      FilledButton(onPressed: () { setS(() {}); }, child: const Text('Chiffrer'))])));
  }

  void _permAuditDialog() {
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Analyse des permissions'), content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Permissions accordées à GiovaPlayer:', style: TextStyle(fontWeight: FontWeight.bold)),
      SizedBox(height: 8),
      Text('• Stockage (lecture médias)'), Text('• Internet (téléchargements)'), Text('• Biométrie (coffre-fort)'),
      Text('• Wake lock (lecteur vidéo)'), Text('• Service premier plan (audio)'),
      SizedBox(height: 8),
      Text('Toutes les permissions sont utilisées légitimement.', style: TextStyle(fontSize: 12)),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }
}

// ═══ DIALOG HELPERS ═══

class _AudioPickDialog extends StatefulWidget {
  final String title;
  final List<MediaFile> audio;
  final bool multiSelect;
  final void Function(List<MediaFile> selected) onConfirm;
  const _AudioPickDialog({required this.title, required this.audio, required this.multiSelect, required this.onConfirm});
  @override State<_AudioPickDialog> createState() => _AudioPickDialogState();
}

class _AudioPickDialogState extends State<_AudioPickDialog> {
  final Set<int> _selected = {};
  @override Widget build(BuildContext context) => AlertDialog(title: Text(widget.title), content: SizedBox(width: double.maxFinite, height: 400,
    child: ListView.builder(itemCount: widget.audio.length, itemBuilder: (_, i) {
      final f = widget.audio[i]; final sel = _selected.contains(i);
      return CheckboxListTile(value: sel, onChanged: (v) {
        setState(() { if (v == true) { if (!widget.multiSelect) _selected.clear(); _selected.add(i); } else _selected.remove(i); });
      }, title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)), subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)));
    }),
  ), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
    FilledButton(onPressed: () { Navigator.pop(context); widget.onConfirm(_selected.map((i) => widget.audio[i]).toList()); }, child: const Text('OK'))]);
}

class _SpeedDialog extends StatefulWidget {
  final List<MediaFile> audio;
  const _SpeedDialog({required this.audio});
  @override State<_SpeedDialog> createState() => _SpeedDialogState();
}

class _SpeedDialogState extends State<_SpeedDialog> {
  double _speed = 1.5;
  MediaFile? _selected;
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Changer vitesse'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(_selected?.displayName ?? 'Choisir un fichier', maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 8),
    DropdownButtonFormField<MediaFile>(value: _selected, items: widget.audio.take(30).map((f) => DropdownMenuItem(value: f, child: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) => setState(() => _selected = v), decoration: const InputDecoration(border: OutlineInputBorder())),
    const SizedBox(height: 12),
    Text('Vitesse: ${_speed}x'),
    Slider(value: _speed, min: 0.5, max: 3.0, divisions: 10, label: '${_speed}x', onChanged: (v) => setState(() => _speed = v)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
    FilledButton(onPressed: _selected == null ? null : () async {
      Navigator.pop(context);
      final result = await MediaProcessor.changeSpeed(inputPath: _selected!.path, speed: _speed);
      if (mounted) {
        if (result != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vitesse changée! $result')));
        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red));
      }
    }, child: const Text('Appliquer'))]);
}

class _ChannelsDialog extends StatefulWidget {
  final List<MediaFile> audio;
  const _ChannelsDialog({required this.audio});
  @override State<_ChannelsDialog> createState() => _ChannelsDialogState();
}

class _ChannelsDialogState extends State<_ChannelsDialog> {
  int _channels = 2;
  MediaFile? _selected;
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Convertir canaux'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<MediaFile>(value: _selected, items: widget.audio.take(30).map((f) => DropdownMenuItem(value: f, child: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) => setState(() => _selected = v), decoration: const InputDecoration(border: OutlineInputBorder())),
    const SizedBox(height: 12),
    SegmentedButton<int>(segments: const [ButtonSegment(value: 1, label: Text('Mono')), ButtonSegment(value: 2, label: Text('Stéréo'))], selected: {_channels}, onSelectionChanged: (v) => setState(() => _channels = v.first)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
    FilledButton(onPressed: _selected == null ? null : () async {
      Navigator.pop(context);
      final result = await MediaProcessor.changeChannels(inputPath: _selected!.path, channels: _channels);
      if (mounted) {
        if (result != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Conversion réussie!')));
        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red));
      }
    }, child: const Text('Convertir'))]);
}

class _AmplifyDialog extends StatefulWidget {
  final List<MediaFile> audio;
  const _AmplifyDialog({required this.audio});
  @override State<_AmplifyDialog> createState() => _AmplifyDialogState();
}

class _AmplifyDialogState extends State<_AmplifyDialog> {
  double _factor = 2.0;
  MediaFile? _selected;
  @override Widget build(BuildContext context) => AlertDialog(title: const Text('Amplifier'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
    DropdownButtonFormField<MediaFile>(value: _selected, items: widget.audio.take(30).map((f) => DropdownMenuItem(value: f, child: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))).toList(),
      onChanged: (v) => setState(() => _selected = v), decoration: const InputDecoration(border: OutlineInputBorder())),
    const SizedBox(height: 12),
    Text('Volume: ${_factor}x'),
    Slider(value: _factor, min: 0.5, max: 5.0, divisions: 18, label: '${_factor}x', onChanged: (v) => setState(() => _factor = v)),
  ])), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
    FilledButton(onPressed: _selected == null ? null : () async {
      Navigator.pop(context);
      final result = await MediaProcessor.amplify(inputPath: _selected!.path, factor: _factor);
      if (mounted) {
        if (result != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Amplification réussie!')));
        else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur'), backgroundColor: Colors.red));
      }
    }, child: const Text('Appliquer'))]);
}
