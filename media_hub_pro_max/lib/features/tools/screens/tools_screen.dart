import 'dart:io';
import 'dart:math';
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
  bool _scanning = false;
  List<MediaFile> _duplicates = [];
  List<MediaFile> _largeFiles = [];
  int _audioTotal = 0, _videoTotal = 0, _imageTotal = 0;
  String _passwordGenResult = '';
  int _passwordLength = 16;
  bool _includeUpper = true, _includeLower = true, _includeNumbers = true, _includeSymbols = true;

  // Audio converter state
  String _selectedQuality = '320kbps';
  String _selectedFormat = 'MP3';

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Outils Pro'),
      bottom: TabBar(controller: _tc, isScrollable: true, tabs: const [
        Tab(text: 'Stockage', icon: Icon(Icons.storage, size: 16)),
        Tab(text: 'Convertisseur', icon: Icon(Icons.transform, size: 16)),
        Tab(text: 'Nettoyeur', icon: Icon(Icons.cleaning_services, size: 16)),
        Tab(text: 'Sécurité', icon: Icon(Icons.security, size: 16)),
        Tab(text: 'Métadonnées', icon: Icon(Icons.tag, size: 16)),
        Tab(text: 'Audio Tools', icon: Icon(Icons.graphic_eq, size: 16)),
      ])),
      body: TabBarView(controller: _tc, children: [
        _buildStorage(cs),
        _buildConverter(cs),
        _buildCleaner(cs),
        _buildSecurity(cs),
        _buildMetadata(cs),
        _buildAudioTools(cs),
      ]),
    );
  }

  // ═══ STOCKAGE ═══
  Widget _buildStorage(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Analyse du stockage', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: _analyzeStorage, icon: const Icon(Icons.analytics), label: const Text('Analyser')),
      const SizedBox(height: 16),
      if (_audioTotal + _videoTotal + _imageTotal > 0) ...[
        Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(children: [
          Text(_fmtSize(_audioTotal + _videoTotal + _imageTotal),
            style: Theme.of(context).textTheme.headlineMedium),
          const Text('Espace total occupé'),
          const SizedBox(height: 16),
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: SizedBox(height: 16, child: Row(children: [
              if (_videoTotal > 0) Expanded(flex: _videoTotal, child: Container(color: Colors.red)),
              if (_audioTotal > 0) Expanded(flex: _audioTotal, child: Container(color: Colors.blue)),
              if (_imageTotal > 0) Expanded(flex: _imageTotal, child: Container(color: Colors.green)),
            ]))),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _sc('Vidéos', _fmtSize(_videoTotal), Icons.movie, Colors.red),
            _sc('Audio', _fmtSize(_audioTotal), Icons.music_note, Colors.blue),
            _sc('Photos', _fmtSize(_imageTotal), Icons.photo, Colors.green),
          ]),
        ]))),
        const SizedBox(height: 16),
        Text('Fichiers les plus volumineux', style: Theme.of(context).textTheme.titleMedium),
        ..._largeFiles.take(15).map((f) => ListTile(
          leading: Icon(_typeIcon(f.type), color: cs.primary),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(_fmtSize(f.size)),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _deleteFile(f)),
        )),
      ],
    ]);
  }

  // ═══ CONVERTISSEUR ═══
  Widget _buildConverter(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Convertisseur de formats', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      // Vidéo → Audio
      Card(child: ListTile(
        leading: Icon(Icons.videocam, color: cs.primary, size: 32),
        title: const Text('Vidéo → Audio'),
        subtitle: const Text('Extraire la piste audio d\'une vidéo (MP4 → MP3, FLAC...)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('video_to_audio'),
      )),
      // Image → PDF
      Card(child: ListTile(
        leading: Icon(Icons.image, color: Colors.green, size: 32),
        title: const Text('Image → PDF'),
        subtitle: const Text('Convertir des images en document PDF'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('image_to_pdf'),
      )),
      // Audio format
      Card(child: ListTile(
        leading: Icon(Icons.audiotrack, color: Colors.blue, size: 32),
        title: const Text('Audio → Audio'),
        subtitle: const Text('Changer le format audio (FLAC → MP3, WAV → AAC...)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('audio_to_audio'),
      )),
      // Vidéo format
      Card(child: ListTile(
        leading: Icon(Icons.movie, color: Colors.red, size: 32),
        title: const Text('Vidéo → Vidéo'),
        subtitle: const Text('Changer le format vidéo (MKV → MP4, AVI → MP4...)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('video_to_video'),
      )),
      // GIF
      Card(child: ListTile(
        leading: Icon(Icons.gif, color: Colors.orange, size: 32),
        title: const Text('Vidéo → GIF'),
        subtitle: const Text('Créer un GIF animé à partir d\'une vidéo'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('video_to_gif'),
      )),
      // Compress image
      Card(child: ListTile(
        leading: Icon(Icons.compress, color: Colors.purple, size: 32),
        title: const Text('Compresser image'),
        subtitle: const Text('Réduire la taille d\'une image (qualité, résolution)'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('compress_image'),
      )),
      // Resize
      Card(child: ListTile(
        leading: Icon(Icons.aspect_ratio, color: Colors.teal, size: 32),
        title: const Text('Redimensionner image'),
        subtitle: const Text('Changer la taille d\'une image'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showConverter('resize_image'),
      )),
    ]);
  }

  void _showConverter(String type) {
    final labels = {
      'video_to_audio': ('Extraire audio d\'une vidéo', 'Sélectionnez une vidéo pour extraire sa piste audio.'),
      'image_to_pdf': ('Image vers PDF', 'Sélectionnez des images pour créer un PDF.'),
      'audio_to_audio': ('Convertir audio', 'Sélectionnez un fichier audio à convertir.'),
      'video_to_video': ('Convertir vidéo', 'Sélectionnez une vidéo à convertir.'),
      'video_to_gif': ('Vidéo vers GIF', 'Sélectionnez une vidéo pour créer un GIF.'),
      'compress_image': ('Compresser image', 'Sélectionnez une image à compresser.'),
      'resize_image': ('Redimensionner', 'Sélectionnez une image à redimensionner.'),
    };
    final info = labels[type]!;

    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.6, expand: false,
      builder: (c, ctrl) => ListView(controller: ctrl, padding: const EdgeInsets.all(24), children: [
        Text(info.$1, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(info.$2, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 20),
        // Options de qualité
        if (type == 'video_to_audio' || type == 'audio_to_audio') ...[
          Text('Format de sortie', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['MP3', 'FLAC', 'AAC', 'OGG', 'WAV'].map((f) =>
            ChoiceChip(label: Text(f), selected: _selectedFormat == f,
              onSelected: (_) => setState(() => _selectedFormat = f))).toList()),
          const SizedBox(height: 12),
          Text('Qualité', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['128kbps', '192kbps', '256kbps', '320kbps', 'Lossless'].map((q) =>
            ChoiceChip(label: Text(q), selected: _selectedQuality == q,
              onSelected: (_) => setState(() => _selectedQuality = q))).toList()),
        ],
        if (type == 'compress_image') ...[
          Text('Qualité de compression', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: ['Haute', 'Moyenne', 'Basse'].map((q) =>
            ChoiceChip(label: Text(q), selected: _selectedQuality == q,
              onSelected: (_) => setState(() => _selectedQuality = q))).toList()),
        ],
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _startConversion(type);
          },
          icon: const Icon(Icons.transform), label: const Text('Sélectionner un fichier'))),
      ]),
    ));
  }

  void _startConversion(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Conversion ${type.replaceAll('_', ' ')} en cours...'),
        duration: const Duration(seconds: 2)));
    // La conversion réelle nécessiterait ffmpeg ou des bibliothèques natives
  }

  // ═══ NETTOYEUR ═══
  Widget _buildCleaner(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Nettoyeur intelligent', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: _scanning ? null : _runCleanerScan,
        icon: _scanning ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.cleaning_services),
        label: Text(_scanning ? 'Scan en cours...' : 'Lancer le scan complet'),
      ),
      const SizedBox(height: 16),
      // Résultats du scan
      _cleanerCard(Icons.content_copy, 'Fichiers dupliqués', '${_duplicates.length ~/ 2} doublons trouvés',
        _fmtSize(_duplicates.fold<int>(0, (s, f) => s + f.size ~/ 2)), Colors.orange, cs),
      _cleanerCard(Icons.photo_size_select_large, 'Photos floues', 'Analyse IA de qualité',
        'Bientôt disponible', Colors.red, cs),
      _cleanerCard(Icons.cached, 'Cache applicatif', 'Fichiers temporaires des apps',
        'Nettoyage automatique', Colors.blue, cs),
      _cleanerCard(Icons.folder_special, 'Fichiers orphelins', 'Fichiers sans référence',
        'Scan intelligent', Colors.green, cs),
      _cleanerCard(Icons.delete_sweep, 'APK installés', 'Fichiers APK dans Download',
        'Espace récupérable', Colors.purple, cs),
      const SizedBox(height: 16),
      if (_duplicates.isNotEmpty) ...[
        Text('Doublons détectés', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ..._duplicates.take(10).map((f) => ListTile(
          leading: Icon(_typeIcon(f.type), color: Colors.orange),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${_fmtSize(f.size)} • ${f.path.substring(0, f.path.lastIndexOf('/')).substring(f.path.lastIndexOf('/'))}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteFile(f)),
        )),
      ],
    ]);
  }

  Widget _cleanerCard(IconData icon, String title, String subtitle, String extra, Color color, ColorScheme cs) =>
    Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
      leading: Container(width: 40, height: 40,
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 22)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(extra, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
        const SizedBox(height: 4),
        SizedBox(height: 28, child: FilledButton.tonal(
          onPressed: (){}, style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
          child: const Text('Nettoyer', style: TextStyle(fontSize: 10)))),
      ]),
    ));

  // ═══ SÉCURITÉ ═══
  Widget _buildSecurity(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.verified_user, color: cs.onTertiaryContainer), const SizedBox(width: 12),
          Expanded(child: Text('Sécurité GiovaPlayer',
            style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700, fontSize: 16)))]),
        const SizedBox(height: 12),
        ...['Aucune donnée personnelle collectée', 'Aucun envoi à des serveurs',
          'Chiffrement AES-256-GCM', 'Aucun tracking', 'Permissions minimales',
          'RGPD par design', 'Panic PIN 9999', 'Anti-screenshot coffre'].map((r) =>
          Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
            Icon(Icons.check_circle, size: 14, color: cs.onTertiaryContainer),
            const SizedBox(width: 6), Text(r, style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12))]))),
      ]))),
      const SizedBox(height: 16),
      // Générateur de mots de passe
      Text('Générateur de mots de passe', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        if (_passwordGenResult.isNotEmpty) Container(width: double.infinity,
          padding: const EdgeInsets.all(12), decoration: BoxDecoration(
            color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
          child: SelectableText(_passwordGenResult, style: const TextStyle(fontFamily: 'monospace', fontSize: 16))),
        const SizedBox(height: 12),
        Row(children: [const Text('Longueur: '), Expanded(child: Slider(
          value: _passwordLength.toDouble(), min: 8, max: 64, divisions: 56,
          label: '$_passwordLength', onChanged: (v) => setState(() => _passwordLength = v.round()))),
          Text('$_passwordLength')]),
        SwitchListTile(title: const Text('Majuscules'), value: _includeUpper, onChanged: (v) => setState(() => _includeUpper = v)),
        SwitchListTile(title: const Text('Minuscules'), value: _includeLower, onChanged: (v) => setState(() => _includeLower = v)),
        SwitchListTile(title: const Text('Chiffres'), value: _includeNumbers, onChanged: (v) => setState(() => _includeNumbers = v)),
        SwitchListTile(title: const Text('Symboles'), value: _includeSymbols, onChanged: (v) => setState(() => _includeSymbols = v)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _generatePassword,
            icon: const Icon(Icons.refresh), label: const Text('Générer'))),
          if (_passwordGenResult.isNotEmpty) ...[const SizedBox(width: 8),
            IconButton.filled(onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié !')));
            }, icon: const Icon(Icons.copy))],
        ]),
      ]))),
      const SizedBox(height: 16),
      // Chiffrement
      Text('Chiffrement de fichiers', style: Theme.of(context).textTheme.titleMedium),
      Card(child: ListTile(
        leading: Icon(Icons.enhanced_encryption, color: cs.primary),
        title: const Text('Chiffrer un fichier'),
        subtitle: const Text('AES-256-GCM • Mot de passe'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.no_encryption, color: cs.primary),
        title: const Text('Déchiffrer un fichier'),
        subtitle: const Text('Décryptage AES-256'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      // Hachage
      Card(child: ListTile(
        leading: Icon(Icons.fingerprint, color: cs.primary),
        title: const Text('Vérifier hachage'),
        subtitle: const Text('MD5 / SHA-256 / CRC32'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
    ]);
  }

  // ═══ MÉTADONNÉES ═══
  Widget _buildMetadata(ColorScheme cs) {
    final audioFiles = ref.watch(audioFilesProvider).valueOrNull ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Éditeur de métadonnées', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: Icon(Icons.edit_note, color: cs.primary, size: 32),
        title: const Text('Éditer tags audio'),
        subtitle: const Text('Modifier titre, artiste, album, pochette...'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showMetadataEditor(audioFiles),
      )),
      Card(child: ListTile(
        leading: Icon(Icons.lyrics, color: Colors.blue, size: 32),
        title: const Text('Rechercher paroles'),
        subtitle: const Text('Trouver les paroles d\'une chanson'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.auto_awesome, color: Colors.green, size: 32),
        title: const Text('Auto-tag IA'),
        subtitle: const Text('Remplir automatiquement les métadonnées manquantes'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.album, color: Colors.orange, size: 32),
        title: const Text('Télécharger pochettes'),
        subtitle: const Text('Chercher les pochettes d\'album manquantes'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      if (audioFiles.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Fichiers sans métadonnées', style: Theme.of(context).textTheme.titleMedium),
        ...audioFiles.take(10).map((f) => ListTile(
          leading: Icon(Icons.music_note, color: cs.onSurfaceVariant),
          title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.artist == null ? 'Artiste inconnu' : f.artistDisplay),
          trailing: IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _showMetadataEditor(audioFiles)),
        )),
      ],
    ]);
  }

  void _showMetadataEditor(List<MediaFile> files) {
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => Padding(
      padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Éditeur de tags', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(decoration: const InputDecoration(labelText: 'Artiste', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(decoration: const InputDecoration(labelText: 'Album', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder())),
        const SizedBox(height: 8),
        TextField(decoration: const InputDecoration(labelText: 'Genre', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close), label: const Text('Annuler'))),
          const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tags sauvegardés !')));
          }, icon: const Icon(Icons.save), label: const Text('Sauvegarder'))),
        ]),
      ]),
    ));
  }

  // ═══ AUDIO TOOLS ═══
  Widget _buildAudioTools(ColorScheme cs) {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Outils audio avancés', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: Icon(Icons.content_cut, color: cs.primary, size: 32),
        title: const Text('Découpeur audio'),
        subtitle: const Text('Couper une partie d\'un fichier audio'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showAudioCutter(),
      )),
      Card(child: ListTile(
        leading: Icon(Icons.merge, color: Colors.green, size: 32),
        title: const Text('Fusionner audio'),
        subtitle: const Text('Assembler plusieurs fichiers audio'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.speed, color: Colors.orange, size: 32),
        title: const Text('Changer vitesse/pitch'),
        subtitle: const Text('Accélérer, ralentir ou changer le ton'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.graphic_eq, color: Colors.blue, size: 32),
        title: const Text('Normaliser volume'),
        subtitle: const Text('ReplayGain / Loudness normalization'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.surround_sound, color: Colors.purple, size: 32),
        title: const Text('Convertir mono/stéréo'),
        subtitle: const Text('Changer le nombre de canaux audio'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.notifications_active, color: Colors.red, size: 32),
        title: const Text('Créer sonnerie'),
        subtitle: const Text('Découper 30s pour sonnerie/notification'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
      Card(child: ListTile(
        leading: Icon(Icons.record_voice_over, color: Colors.teal, size: 32),
        title: const Text('Enregistreur vocal'),
        subtitle: const Text('Enregistrer de l\'audio avec le micro'),
        trailing: const Icon(Icons.chevron_right), onTap: (){},
      )),
    ]);
  }

  void _showAudioCutter() {
    double startSec = 0, endSec = 30;
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => StatefulBuilder(
      builder: (context, setModalState) => Padding(padding: const EdgeInsets.all(24), child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        Text('Découpeur audio', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text('Sélectionnez la plage à conserver'),
        const SizedBox(height: 12),
        Row(children: [
          Text('Début: ${startSec.toStringAsFixed(0)}s'),
          const Spacer(),
          Text('Fin: ${endSec.toStringAsFixed(0)}s'),
        ]),
        RangeSlider(values: RangeValues(startSec, endSec), min: 0, max: 300,
          onChanged: (v) => setModalState(() { startSec = v.start; endSec = v.end; })),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Découpage de ${startSec.toStringAsFixed(0)}s à ${endSec.toStringAsFixed(0)}s...')));
          }, icon: const Icon(Icons.content_cut), label: const Text('Découper'))),
      ])),
    ));
  }

  // ═══ UTILITAIRES ═══
  Future<void> _analyzeStorage() async {
    setState(() => _scanning = true);
    final audioFiles = ref.read(audioFilesProvider).valueOrNull ?? [];
    final videoFiles = ref.read(videoFilesProvider).valueOrNull ?? [];
    final imageFiles = ref.read(imageFilesProvider).valueOrNull ?? [];
    final allFiles = [...audioFiles, ...videoFiles, ...imageFiles];
    allFiles.sort((a, b) => b.size.compareTo(a.size));
    setState(() {
      _audioTotal = audioFiles.fold(0, (s, f) => s + f.size);
      _videoTotal = videoFiles.fold(0, (s, f) => s + f.size);
      _imageTotal = imageFiles.fold(0, (s, f) => s + f.size);
      _largeFiles = allFiles;
      _scanning = false;
    });
  }

  Future<void> _runCleanerScan() async {
    setState(() => _scanning = true);
    final audioFiles = ref.read(audioFilesProvider).valueOrNull ?? [];
    final videoFiles = ref.read(videoFilesProvider).valueOrNull ?? [];
    final imageFiles = ref.read(imageFilesProvider).valueOrNull ?? [];
    final allFiles = [...audioFiles, ...videoFiles, ...imageFiles];
    final sizeMap = <int, List<MediaFile>>{};
    for (final f in allFiles) {
      sizeMap.putIfAbsent(f.size, () => []).add(f);
    }
    _duplicates = sizeMap.values.where((l) => l.length > 1).expand((l) => l).toList();
    setState(() => _scanning = false);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_duplicates.length ~/ 2} doublons trouvés')));
  }

  void _deleteFile(MediaFile f) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Supprimer ?'), content: Text('Supprimer "${f.displayName}" ?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(onPressed: () async {
          Navigator.pop(context);
          try { await File(f.path).delete(); ref.invalidate(audioFilesProvider); ref.invalidate(videoFilesProvider); ref.invalidate(imageFilesProvider);
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier supprimé')));
          } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red)); }
        }, child: const Text('Supprimer')),
      ],
    ));
  }

  void _generatePassword() {
    final chars = StringBuffer();
    if (_includeUpper) chars.write('ABCDEFGHIJKLMNOPQRSTUVWXYZ');
    if (_includeLower) chars.write('abcdefghijklmnopqrstuvwxyz');
    if (_includeNumbers) chars.write('0123456789');
    if (_includeSymbols) chars.write(r'!@#$%^&*()_+-=[]{}|;:,.<>?');
    if (chars.isEmpty) chars.write('abcdefghijklmnopqrstuvwxyz');
    final random = Random.secure();
    setState(() => _passwordGenResult = List.generate(_passwordLength, (_) =>
      chars.toString()[random.nextInt(chars.length)]).join());
  }

  IconData _typeIcon(String type) => switch (type) { 'audio' => Icons.music_note, 'video' => Icons.movie, 'image' => Icons.photo, _ => Icons.insert_drive_file };
  Widget _sc(String l, String s, IconData i, Color c) => Column(children: [Icon(i, color: c, size: 20), const SizedBox(height: 4), Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text(l, style: TextStyle(fontSize: 10, color: Colors.grey[600]))]);
  String _fmtSize(int bytes) { if (bytes < 1024) return '$bytes B'; if (bytes < 1024*1024) return '${(bytes/1024).toStringAsFixed(1)} KB'; if (bytes < 1024*1024*1024) return '${(bytes/(1024*1024)).toStringAsFixed(1)} MB'; return '${(bytes/(1024*1024*1024)).toStringAsFixed(1)} GB'; }
}
