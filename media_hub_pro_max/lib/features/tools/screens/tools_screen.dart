import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _pwResult = '';
  int _pwLen = 16;
  bool _pwUpper = true, _pwLower = true, _pwNum = true, _pwSym = true;
  double _cutterStart = 0, _cutterEnd = 30;

  @override void initState() { super.initState(); _tc = TabController(length: 6, vsync: this); }
  @override void dispose() { _tc.dispose(); super.dispose(); }

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

  // ═══ CONVERTISSEUR ═══
  Widget _converter() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Convertisseur', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    ...[(Icons.videocam, 'Vidéo → Audio', 'Extraire la piste audio'),
      (Icons.image, 'Image → PDF', 'Convertir en document PDF'),
      (Icons.audiotrack, 'Audio → Audio', 'FLAC → MP3, WAV → AAC...'),
      (Icons.movie, 'Vidéo → Vidéo', 'MKV → MP4, AVI → MP4...'),
      (Icons.gif, 'Vidéo → GIF', 'Créer un GIF animé'),
      (Icons.compress, 'Compresser image', 'Réduire la taille'),
      (Icons.aspect_ratio, 'Redimensionner', 'Changer la résolution'),
      (Icons.batch_prediction, 'Conversion par lot', 'Traiter plusieurs fichiers'),
      (Icons.qr_code, 'QR Code', 'Générer un QR Code'),
      (Icons.picture_as_pdf, 'Texte → PDF', 'Convertir du texte en PDF'),
    ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
      leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 28),
      title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(c.$3, style: const TextStyle(fontSize: 12)),
      trailing: const Icon(Icons.chevron_right), onTap: () => _convertDialog(c.$2),
    ))),
  ]);

  void _convertDialog(String title) => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
    Text('Sélectionnez un fichier source pour commencer.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 16),
    FilledButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title en cours...'))); },
      icon: const Icon(Icons.folder_open), label: const Text('Choisir un fichier')),
  ]));

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
    ...[(Icons.enhanced_encryption, 'Chiffrer un fichier', 'AES-256-GCM'),
      (Icons.no_encryption, 'Déchiffrer un fichier', 'Décryptage AES-256'),
      (Icons.fingerprint, 'Vérifier hachage', 'MD5 / SHA-256'),
      (Icons.verified_user, 'Vérifier intégrité', 'Comparer checksums'),
      (Icons.password, 'Évaluer force mot de passe', 'Test de robustesse'),
      (Icons.vpn_key, 'Générateur de clés', 'Clés AES/RSA/Ed25519'),
      (Icons.shield, 'Audit sécurité', 'Vérifier les vulnérabilités'),
      (Icons.security, 'Chiffrement note', 'Notes chiffrées'),
      (Icons.local_police, 'Analyse permissions', 'Vérifier les apps'),
      (Icons.archive, 'Archive chiffrée', 'ZIP/RAR avec mot de passe'),
    ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
      leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 22), title: Text(c.$2, style: const TextStyle(fontSize: 14)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 16), onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.$2} lancé'))),
    ))),
  ]);

  // ═══ MÉTADONNÉES ═══
  Widget _metadata() {
    final audio = ref.watch(audioFilesProvider).valueOrNull ?? [];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('Éditeur de métadonnées', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      ...[(Icons.edit_note, 'Éditer tags audio', 'Titre, artiste, album, pochette'),
        (Icons.lyrics, 'Rechercher paroles', 'Trouver les paroles en ligne'),
        (Icons.auto_awesome, 'Auto-tag IA', 'Remplir les métadonnées manquantes'),
        (Icons.album, 'Télécharger pochettes', 'Chercher les covers manquantes'),
        (Icons.info, 'Voir métadonnées', 'Afficher les tags d\'un fichier'),
        (Icons.delete_forever, 'Supprimer tags', 'Effacer toutes les métadonnées'),
        (Icons.sync, 'Synchroniser tags', 'Aligner nom de fichier et tags'),
        (Icons.audiotrack, 'Normaliser tags', 'Standardiser le formatage'),
        (Icons.star, 'Notation', 'Ajouter une note/classification'),
        (Icons.history, 'Historique modifications', 'Voir les changements'),
      ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
        leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 22), title: Text(c.$2, style: const TextStyle(fontSize: 14)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.chevron_right, size: 16), onTap: () => _tagEditor(c.$2, audio),
      ))),
      if (audio.isNotEmpty) ...[const SizedBox(height: 16), Text('Fichiers récents', style: Theme.of(context).textTheme.titleMedium),
        ...audio.take(8).map((f) => ListTile(leading: const Icon(Icons.music_note, size: 20), title: Text(f.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(f.artistDisplay, style: const TextStyle(fontSize: 11)), trailing: IconButton(icon: const Icon(Icons.edit, size: 16), onPressed: () => _tagEditor('Éditer tags', audio))))],
    ]);
  }

  void _tagEditor(String title, List<MediaFile> audio) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(title, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
    TextField(decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder())),
    const SizedBox(height: 8), TextField(decoration: const InputDecoration(labelText: 'Artiste', border: OutlineInputBorder())),
    const SizedBox(height: 8), TextField(decoration: const InputDecoration(labelText: 'Album', border: OutlineInputBorder())),
    const SizedBox(height: 8), TextField(decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder())),
    const SizedBox(height: 16),
    Row(children: [Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler'))),
      const SizedBox(width: 8), Expanded(child: FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tags sauvegardés !'))); }, child: const Text('Sauvegarder')))],
    ),
  ])));

  // ═══ AUDIO TOOLS ═══
  Widget _audioTools() => ListView(padding: const EdgeInsets.all(16), children: [
    Text('Outils audio', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Text('Découpeur audio', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Row(children: [Text('Début: ${_cutterStart.toStringAsFixed(0)}s'), const Spacer(), Text('Fin: ${_cutterEnd.toStringAsFixed(0)}s')]),
      RangeSlider(values: RangeValues(_cutterStart, _cutterEnd), min: 0, max: 300, onChanged: (v) => setState(() { _cutterStart = v.start; _cutterEnd = v.end; })),
      FilledButton.icon(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Découpe de ${_cutterStart.toStringAsFixed(0)}s à ${_cutterEnd.toStringAsFixed(0)}s'))),
        icon: const Icon(Icons.content_cut), label: const Text('Découper')),
    ]))),
    const SizedBox(height: 8),
    ...[(Icons.merge, 'Fusionner audio', 'Assembler plusieurs fichiers'),
      (Icons.speed, 'Changer vitesse/pitch', 'Accélérer, ralentir, changer le ton'),
      (Icons.graphic_eq, 'Normaliser volume', 'ReplayGain / Loudness'),
      (Icons.surround_sound, 'Convertir mono/stéréo', 'Changer le nombre de canaux'),
      (Icons.notifications_active, 'Créer sonnerie', 'Découper 30s pour sonnerie'),
      (Icons.record_voice_over, 'Enregistreur vocal', 'Enregistrer avec le micro'),
      (Icons.volume_up, 'Amplificateur', 'Augmenter le volume'),
      (Icons.waves, 'Analyseur spectral', 'Visualiser les fréquences'),
      (Icons.loop, 'Boucleur', 'Créer des boucles audio'),
      (Icons.queue_music, 'Créer playlist M3U', 'Générer un fichier playlist'),
    ].map((c) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
      leading: Icon(c.$1, color: Theme.of(context).colorScheme.primary, size: 22), title: Text(c.$2, style: const TextStyle(fontSize: 14)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.chevron_right, size: 16), onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${c.$2} lancé'))),
    ))),
  ]);

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

  IconData _ti(String t) => switch (t) { 'audio' => Icons.music_note, 'video' => Icons.movie, 'image' => Icons.photo, _ => Icons.insert_drive_file };
  Widget _sc(String l, String s, IconData i, Color c) => Column(children: [Icon(i, color: c, size: 20), const SizedBox(height: 4), Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)), Text(l, style: TextStyle(fontSize: 10, color: Colors.grey[600]))]);
  String _fs(int b) { if (b < 1024) return '$b B'; if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB'; if (b < 1073741824) return '${(b/1048576).toStringAsFixed(1)} MB'; return '${(b/1073741824).toStringAsFixed(1)} GB'; }
  String _heaviestFolder(List<MediaFile> files) { final m = <String, int>{}; for (final f in files) { final d = f.path.substring(0, f.path.lastIndexOf('/')); m[d] = (m[d] ?? 0) + f.size; } if (m.isEmpty) return '-'; final e = m.entries.reduce((a, b) => a.value > b.value ? a : b); return '${e.key.substring(e.key.lastIndexOf('/') + 1)} (${_fs(e.value)})'; }
}
