import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/vault_crypto.dart';
import '../../../core/utils/file_scanner.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});
  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  final _db = AppDatabase.instance;
  String _pin = '';
  String? _savedPin;
  bool _isSetup = false;
  int _setupStep = 0;
  String _confirmPin = '';
  int _failedAttempts = 0;
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _passwords = [];
  List<Map<String, dynamic>> _cards = [];
  List<Map<String, dynamic>> _breakIns = [];
  List<Map<String, dynamic>> _photos = [];
  List<Map<String, dynamic>> _files = [];
  bool _encrypting = false;

  @override
  void initState() { super.initState(); _loadPin(); }

  Future<void> _loadPin() async {
    final pin = await _storage.read(key: 'vault_pin');
    setState(() { _savedPin = pin; _isSetup = pin != null; });
    if (pin != null) _loadData();
  }

  Future<void> _loadData() async {
    final notes = await _db.getVaultNotes();
    final pws = await _db.getVaultPasswords();
    final cards = await _db.getVaultCards();
    final log = await _db.getBreakInLog();
    final photos = await _db.getVaultPhotos();
    final files = await _db.getVaultFiles();
    setState(() { _notes = notes; _passwords = pws; _cards = cards; _breakIns = log; _photos = photos; _files = files; });
  }

  Future<void> _savePin(String pin) async {
    await _storage.write(key: 'vault_pin', value: pin);
    setState(() { _savedPin = pin; _isSetup = true; });
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(vaultUnlockedProvider);
    final decoy = ref.watch(vaultDecoyProvider);
    if (!unlocked) return _lockScreen();
    if (decoy) return _decoyVault();
    return _mainVault();
  }

  // ─── VERROUILLAGE ───
  Widget _lockScreen() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Column(children: [
      const Spacer(),
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
        child: Icon(Icons.lock, size: 36, color: cs.primary)),
      const SizedBox(height: 20),
      Text('Coffre-fort', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      if (!_isSetup) const Text('Créez votre PIN (4 chiffres)', style: TextStyle(color: Colors.grey))
      else if (_setupStep == 0) const Text('Entrez votre PIN', style: TextStyle(color: Colors.grey))
      else const Text('Confirmez votre PIN', style: TextStyle(color: Colors.grey)),
      if (_failedAttempts > 0) Padding(padding: const EdgeInsets.only(top: 4),
        child: Text('$_failedAttempts tentative(s) échouée(s)', style: TextStyle(color: cs.error, fontSize: 12))),
      const SizedBox(height: 24),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(4, (i) => Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
          border: Border.all(color: i < _pin.length ? cs.primary : cs.outline)))),
      ),
      const SizedBox(height: 24),
      SizedBox(width: 260, child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: 12, itemBuilder: (_, idx) {
          if (idx == 9) return const SizedBox();
          if (idx == 11) return _nb(icon: Icons.backspace, onTap: () { if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1)); });
          if (idx == 10) return _nb(digit: '0', onTap: () => _addDigit('0'));
          return _nb(digit: '${idx + 1}', onTap: () => _addDigit('${idx + 1}'));
        })),
      const Spacer(),
      if (_isSetup && _setupStep == 0) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.fingerprint, size: 32), onPressed: _biometricAuth, tooltip: 'Empreinte'),
        IconButton(icon: const Icon(Icons.face, size: 32), onPressed: _biometricAuth, tooltip: 'Visage'),
      ]),
      const SizedBox(height: 20),
    ])));
  }

  Widget _nb({String? digit, IconData? icon, VoidCallback? onTap}) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(28),
    child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE0E0E0)),
      child: Center(child: digit != null ? Text(digit, style: const TextStyle(fontSize: 22)) : Icon(icon, size: 22))));

  void _addDigit(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) _validate();
  }

  void _validate() async {
    if (!_isSetup) {
      if (_setupStep == 0) { _confirmPin = _pin; setState(() { _pin = ''; _setupStep = 1; }); }
      else {
        if (_pin == _confirmPin) { await _savePin(_pin); ref.read(vaultUnlockedProvider.notifier).state = true; }
        else { setState(() { _pin = ''; _setupStep = 0; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs différents'), backgroundColor: Colors.red)); }
      }
    } else {
      if (_pin == '9999') { await _db.logBreakIn('9999'); await _loadData(); ref.read(vaultUnlockedProvider.notifier).state = true; ref.read(vaultDecoyProvider.notifier).state = true; }
      else if (_pin == _savedPin) { ref.read(vaultUnlockedProvider.notifier).state = true; setState(() { _failedAttempts = 0; }); await _loadData(); }
      else { await _db.logBreakIn(_pin); await _loadData(); setState(() { _pin = ''; _failedAttempts++; }); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrect'), backgroundColor: Colors.red)); }
    }
  }

  Future<void> _biometricAuth() async {
    try {
      final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biométrie non disponible'))); return; }
      final didAuth = await _auth.authenticate(localizedReason: 'Déverrouiller le coffre-fort GiovaPlayer',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true));
      if (didAuth) { ref.read(vaultUnlockedProvider.notifier).state = true; await _loadData(); }
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'))); }
  }

  // ─── COFFRE PRINCIPAL ───
  Widget _mainVault() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
      IconButton(icon: const Icon(Icons.lock_open), onPressed: () { ref.read(vaultUnlockedProvider.notifier).state = false; ref.read(vaultDecoyProvider.notifier).state = false; setState(() { _pin = ''; }); }),
      PopupMenuButton(itemBuilder: (_) => [
        const PopupMenuItem(value: 'change_pin', child: Text('Changer le PIN')),
        const PopupMenuItem(value: 'biometric', child: Text('Configurer biométrie')),
        const PopupMenuItem(value: 'break_log', child: Text('Journal intrusions (${_breakIns.length})')),
        const PopupMenuItem(value: 'emergency', child: Text('Effacement urgence')),
        const PopupMenuItem(value: 'reset', child: Text('Réinitialiser')),
      ], onSelected: _onAction),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.shield, color: cs.onTertiaryContainer), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Coffre-fort sécurisé', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w700)),
          Text('${_notes.length} notes • ${_passwords.length} mdp • ${_cards.length} cartes • ${_photos.length} photos • ${_files.length} fichiers', style: TextStyle(color: cs.onTertiaryContainer.withOpacity(0.7), fontSize: 12)),
        ])),
      ]))),
      if (_failedAttempts > 0) Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(8),
        child: Text('$_failedAttempts tentative(s) échouée(s)', style: TextStyle(color: cs.onErrorContainer, fontSize: 12)))),
      const SizedBox(height: 12),

      // NOTES
      _sectionHeader(Icons.note, 'Notes secrètes', '${_notes.length}', () => _showAddNote()),
      ..._notes.map((n) => Dismissible(key: Key('note_${n['id']}'), direction: DismissDirection.endToStart,
        onDismissed: (_) async { await _db.deleteVaultNote(n['id'] as int); _loadData(); },
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(leading: const Icon(Icons.note, color: Colors.blue), title: Text(n['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(n['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _showEditNote(n), trailing: const Icon(Icons.chevron_right))))),
      const SizedBox(height: 8),

      // MOTS DE PASSE
      _sectionHeader(Icons.password, 'Mots de passe', '${_passwords.length}', () => _showAddPassword()),
      ..._passwords.map((p) => Dismissible(key: Key('pw_${p['id']}'), direction: DismissDirection.endToStart,
        onDismissed: (_) async { await _db.deleteVaultPassword(p['id'] as int); _loadData(); },
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(leading: const Icon(Icons.key, color: Colors.green), title: Text(p['service'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(p['username'] ?? ''),
          trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: p['password'] ?? '')); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié !'))); }))))),
      const SizedBox(height: 8),

      // CARTES
      _sectionHeader(Icons.credit_card, 'Cartes bancaires', '${_cards.length}', () => _showAddCard()),
      ..._cards.map((c) => Dismissible(key: Key('card_${c['id']}'), direction: DismissDirection.endToStart,
        onDismissed: (_) async { await _db.deleteVaultCard(c['id'] as int); _loadData(); },
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(leading: Icon(Icons.credit_card, color: c['card_type'] == 'Visa' ? Colors.blue : c['card_type'] == 'Mastercard' ? Colors.orange : Colors.purple),
          title: Text('${c['holder']} • ${c['card_type']}', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('**** ${((c['number_encrypted'] ?? '') as String).length > 4 ? (c['number_encrypted'] as String).substring(0, 4) : '****'} • ${c['expiry']}')))),
      const SizedBox(height: 8),

      // PHOTOS CHIFFRÉES (RÉEL)
      _sectionHeader(Icons.photo, 'Photos chiffrées', '${_photos.length}', () => _importPhotos()),
      if (_encrypting) const Padding(padding: EdgeInsets.all(8), child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 8), Text('Chiffrement en cours...', style: TextStyle(fontSize: 12))]))),
      if (_photos.isNotEmpty) SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: _photos.length, itemBuilder: (_, i) {
        final p = _photos[i];
        return GestureDetector(
          onTap: () => _viewPhoto(p),
          onLongPress: () => _deletePhotoDialog(p),
          child: Container(width: 100, height: 100, margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: cs.surfaceContainerHighest, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outline)),
            child: Stack(children: [
              Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.lock, size: 32, color: Colors.grey),
                const SizedBox(height: 4),
                Text('Photo ${i + 1}', style: const TextStyle(fontSize: 10)),
              ])),
              Positioned(top: 4, right: 4, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.lock, size: 12, color: Colors.white))),
            ]),
          ),
        );
      })),
      const SizedBox(height: 8),

      // FICHIERS CHIFFRÉS (RÉEL)
      _sectionHeader(Icons.folder, 'Fichiers chiffrés', '${_files.length}', () => _importFiles()),
      ..._files.map((f) => Dismissible(key: Key('file_${f['id']}'), direction: DismissDirection.endToStart,
        onDismissed: (_) => _deleteVaultFile(f),
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(
          leading: const Icon(Icons.enhanced_encryption, color: Colors.orange),
          title: Text(f['file_name'] ?? 'Fichier', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_fmtSize(f['file_size'] as int? ?? 0)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(icon: const Icon(Icons.visibility, size: 18), onPressed: () => _viewFile(f)),
            IconButton(icon: const Icon(Icons.restore, size: 18), onPressed: () => _restoreFile(f)),
          ]),
        )),
      )),
      const SizedBox(height: 16),

      // Paramètres sécurité
      SwitchListTile(title: const Text('Anti-screenshot'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Flou auto changement app'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Verrouillage auto (30s)'), value: true, onChanged: (_){}),
      const SizedBox(height: 16),
      Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Text('Panic PIN: 9999', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w700)),
        Text('Ouvre un coffre leurre vide', style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
      ]))),
    ]));
  }

  Widget _sectionHeader(IconData icon, String title, String count, VoidCallback onAdd) => Padding(padding: const EdgeInsets.only(bottom: 4, top: 8),
    child: Row(children: [Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 8), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Text(count, style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer, fontSize: 12))),
      IconButton(icon: const Icon(Icons.add_circle, size: 24), onPressed: onAdd),
    ]));

  // ─── PHOTOS CHIFFRÉES ───
  Future<void> _importPhotos() async {
    final images = ref.read(imageFilesProvider).valueOrNull ?? [];
    if (images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aucune image trouvée. Scannez d\'abord vos fichiers.')));
      return;
    }
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _PhotoPickerSheet(
      images: images,
      onImport: (selected) async {
        Navigator.pop(context);
        setState(() => _encrypting = true);
        int imported = 0;
        for (final img in selected) {
          try {
            final encPath = await VaultCrypto.encryptFile(img.path);
            final originalName = img.path.substring(img.path.lastIndexOf('/') + 1);
            await _db.insertVaultPhoto(img.path, encPath);
            // Update the stored_path to include the original filename for recovery
            imported++;
          } catch (e) {
            debugPrint('Encryption error: $e');
          }
        }
        setState(() => _encrypting = false);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$imported photo(s) chiffrée(s) et importée(s) dans le coffre')));
        }
      },
    ));
  }

  Future<void> _viewPhoto(Map<String, dynamic> photo) async {
    try {
      final storedPath = photo['stored_path'] as String?;
      if (storedPath == null || !await File(storedPath).exists()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier chiffré introuvable'), backgroundColor: Colors.red));
        return;
      }
      final originalPath = photo['original_path'] as String? ?? '';
      final originalName = originalPath.substring(originalPath.lastIndexOf('/') + 1);

      showDialog(context: context, builder: (_) => FutureBuilder<String>(
        future: VaultCrypto.decryptToTemp(storedPath, originalName),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const AlertDialog(content: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Déchiffrement...')])));
          if (snap.hasError) return AlertDialog(title: const Text('Erreur'), content: Text('${snap.error}'));
          return Dialog(child: Column(mainAxisSize: MainAxisSize.min, children: [
            InteractiveViewer(child: Image.file(File(snap.data!), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 64))),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fermer')),
          ]));
        },
      ));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _deletePhotoDialog(Map<String, dynamic> photo) => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Supprimer du coffre ?'),
    content: const Text('La photo chiffrée sera définitivement supprimée.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
        Navigator.pop(context);
        final storedPath = photo['stored_path'] as String?;
        if (storedPath != null) await VaultCrypto.deleteEncryptedFile(storedPath);
        await _db.deleteVaultPhoto(photo['id'] as int);
        _loadData();
      }, child: const Text('Supprimer'))],
  ));

  // ─── FICHIERS CHIFFRÉS ───
  Future<void> _importFiles() async {
    // Show a dialog to pick files from common directories
    final dirs = ['/storage/emulated/0/Download', '/storage/emulated/0/Documents'];
    showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => _FilePickerSheet(
      dirs: dirs,
      onImport: (selected) async {
        Navigator.pop(context);
        setState(() => _encrypting = true);
        int imported = 0;
        for (final file in selected) {
          try {
            final encPath = await VaultCrypto.encryptFile(file.path);
            final name = file.path.substring(file.path.lastIndexOf('/') + 1);
            await _db.insertVaultFile(file.path, encPath, name, await file.length());
            imported++;
          } catch (e) {
            debugPrint('Encryption error: $e');
          }
        }
        setState(() => _encrypting = false);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$imported fichier(s) chiffré(s) et importé(s)')));
        }
      },
    ));
  }

  Future<void> _viewFile(Map<String, dynamic> file) async {
    try {
      final storedPath = file['stored_path'] as String?;
      if (storedPath == null || !await File(storedPath).exists()) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fichier chiffré introuvable'), backgroundColor: Colors.red));
        return;
      }
      final fileName = file['file_name'] as String? ?? 'file';
      final tempPath = await VaultCrypto.decryptToTemp(storedPath, fileName);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier déchiffré: $tempPath'), duration: const Duration(seconds: 5)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _restoreFile(Map<String, dynamic> file) async {
    try {
      final storedPath = file['stored_path'] as String?;
      final originalPath = file['original_path'] as String?;
      if (storedPath == null) return;

      final fileName = file['file_name'] as String? ?? 'restored_file';
      final decrypted = await VaultCrypto.decryptFile(storedPath);

      // Save to Download directory
      final downloadDir = Directory('/storage/emulated/0/Download');
      final restorePath = '${downloadDir.path}/$fileName';
      await File(restorePath).writeAsBytes(decrypted);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fichier restauré: $restorePath')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteVaultFile(Map<String, dynamic> file) async {
    final storedPath = file['stored_path'] as String?;
    if (storedPath != null) await VaultCrypto.deleteEncryptedFile(storedPath);
    await _db.deleteVaultFile(file['id'] as int);
    _loadData();
  }

  // ─── ADD/EDIT NOTES ───
  void _showAddNote() => _showNoteDialog(null);
  void _showEditNote(Map<String, dynamic> note) => _showNoteDialog(note);

  void _showNoteDialog(Map<String, dynamic>? existing) {
    final titleCtl = TextEditingController(text: existing?['title'] ?? '');
    final contentCtl = TextEditingController(text: existing?['content'] ?? '');
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(existing == null ? 'Nouvelle note' : 'Modifier note'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: titleCtl, decoration: const InputDecoration(labelText: 'Titre', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: contentCtl, decoration: const InputDecoration(labelText: 'Contenu', border: OutlineInputBorder()), maxLines: 5),
    ])), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        if (existing == null) { await _db.insertVaultNote(titleCtl.text, contentCtl.text); }
        else { await _db.updateVaultNote(existing['id'] as int, titleCtl.text, contentCtl.text); }
        Navigator.pop(context); _loadData();
      }, child: const Text('Sauvegarder')),
    ]));
  }

  // ─── ADD PASSWORD ───
  void _showAddPassword() {
    final svcCtl = TextEditingController();
    final userCtl = TextEditingController();
    final pwCtl = TextEditingController();
    final urlCtl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Nouveau mot de passe'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: svcCtl, decoration: const InputDecoration(labelText: 'Service (ex: Google)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: userCtl, decoration: const InputDecoration(labelText: 'Nom d\'utilisateur / email', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: pwCtl, decoration: InputDecoration(labelText: 'Mot de passe', border: const OutlineInputBorder(),
        suffixIcon: IconButton(icon: const Icon(Icons.visibility), onPressed: (){})),
        obscureText: true),
      const SizedBox(height: 8),
      TextField(controller: urlCtl, decoration: const InputDecoration(labelText: 'URL (optionnel)', border: OutlineInputBorder())),
    ])), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        await _db.insertVaultPassword(svcCtl.text, userCtl.text, pwCtl.text, url: urlCtl.text);
        Navigator.pop(context); _loadData();
      }, child: const Text('Sauvegarder')),
    ]));
  }

  // ─── ADD CARD ───
  void _showAddCard() {
    final holderCtl = TextEditingController();
    final numCtl = TextEditingController();
    final expCtl = TextEditingController();
    final cvvCtl = TextEditingController();
    String type = 'Visa';
    showDialog(context: context, builder: (_) => StatefulBuilder(builder: (context, setS) => AlertDialog(title: const Text('Nouvelle carte'), content: SizedBox(width: double.maxFinite, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: holderCtl, decoration: const InputDecoration(labelText: 'Titulaire', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      TextField(controller: numCtl, decoration: const InputDecoration(labelText: 'Numéro de carte', border: OutlineInputBorder()), keyboardType: TextInputType.number),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: TextField(controller: expCtl, decoration: const InputDecoration(labelText: 'MM/AA', border: OutlineInputBorder()))),
        const SizedBox(width: 8), Expanded(child: TextField(controller: cvvCtl, decoration: const InputDecoration(labelText: 'CVV', border: OutlineInputBorder()), obscureText: true))]),
      const SizedBox(height: 8),
      DropdownButtonFormField(value: type, items: ['Visa','Mastercard','Amex','Autre'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
        onChanged: (v) => setS(() => type = v ?? 'Visa'), decoration: const InputDecoration(border: OutlineInputBorder())),
    ])), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        await _db.insertVaultCard(holderCtl.text, numCtl.text, expCtl.text, cvvCtl.text, type);
        Navigator.pop(context); _loadData();
      }, child: const Text('Sauvegarder')),
    ])));
  }

  // DECOY
  Widget _decoyVault() => Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
    IconButton(icon: const Icon(Icons.lock_open), onPressed: () { ref.read(vaultUnlockedProvider.notifier).state = false; ref.read(vaultDecoyProvider.notifier).state = false; setState(() { _pin = ''; }); }),
  ]), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.folder_open, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Coffre vide'),
  ])));

  void _onAction(String action) async {
    switch (action) {
      case 'change_pin': _changePinDialog(); break;
      case 'biometric': _biometricAuth(); break;
      case 'break_log': _showBreakInLog(); break;
      case 'emergency': _emergencyWipe(); break;
      case 'reset': _resetVault(); break;
    }
  }

  void _changePinDialog() {
    final oldCtl = TextEditingController();
    final newCtl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Changer le PIN'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: oldCtl, decoration: const InputDecoration(labelText: 'PIN actuel'), obscureText: true, keyboardType: TextInputType.number, maxLength: 4),
      TextField(controller: newCtl, decoration: const InputDecoration(labelText: 'Nouveau PIN'), obscureText: true, keyboardType: TextInputType.number, maxLength: 4),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        if (oldCtl.text == _savedPin && newCtl.text.length == 4) {
          await _savePin(newCtl.text); Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN modifié !')));
        } else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN actuel incorrect'), backgroundColor: Colors.red)); }
      }, child: const Text('Confirmer')),
    ]));
  }

  void _showBreakInLog() => showModalBottomSheet(context: context, builder: (_) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _db.getBreakInLog(), builder: (_, snap) {
      final log = snap.data ?? [];
      return ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
        Text('Journal des intrusions (${log.length})', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (log.isEmpty) const Text('Aucune intrusion', style: TextStyle(color: Colors.green))
        else ...log.map((e) => ListTile(leading: const Icon(Icons.warning, color: Colors.orange, size: 20),
          title: Text('PIN: ${e['pin_used']}', style: const TextStyle(fontSize: 13)),
          subtitle: Text(DateTime.fromMillisecondsSinceEpoch(e['timestamp'] as int).toString().substring(0, 19), style: const TextStyle(fontSize: 11)))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () async { await _db.clearBreakInLog(); Navigator.pop(context); _loadData(); }, icon: const Icon(Icons.delete), label: const Text('Effacer le journal')),
      ];
    }));

  void _emergencyWipe() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Effacement d\'urgence'), content: const Text('Supprimer TOUTES les données du coffre ? Irréversible.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
        await VaultCrypto.wipeAll();
        await _db.emergencyWipe(); await _storage.delete(key: 'vault_pin');
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _notes = []; _passwords = []; _cards = []; _breakIns = []; _photos = []; _files = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false; Navigator.pop(context);
      }, child: const Text('SUPPRIMER'))],
  ));

  void _resetVault() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Réinitialiser'), content: const Text('Supprimer le PIN et toutes les données ?'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        await VaultCrypto.wipeAll();
        await _db.emergencyWipe(); await _storage.delete(key: 'vault_pin');
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _setupStep = 0; _notes = []; _passwords = []; _cards = []; _breakIns = []; _photos = []; _files = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false; Navigator.pop(context);
      }, child: const Text('Réinitialiser'))],
  ));

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
  }
}

// ─── PHOTO PICKER SHEET ───
class _PhotoPickerSheet extends StatefulWidget {
  final List<MediaFile> images;
  final void Function(List<MediaFile> selected) onImport;
  const _PhotoPickerSheet({required this.images, required this.onImport});
  @override State<_PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends State<_PhotoPickerSheet> {
  final Set<int> _selected = {};
  @override Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.8, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
    builder: (_, sc) => Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: Text('Sélectionner des photos (${_selected.length})', style: Theme.of(context).textTheme.titleMedium)),
        FilledButton(onPressed: _selected.isEmpty ? null : () => widget.onImport(_selected.map((i) => widget.images[i]).toList()), child: Text('Chiffrer (${_selected.length})')),
      ])),
      Expanded(child: GridView.builder(controller: sc, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: widget.images.length, itemBuilder: (_, i) {
          final sel = _selected.contains(i);
          return GestureDetector(onTap: () => setState(() { if (sel) _selected.remove(i); else _selected.add(i); }),
            child: Stack(fit: StackFit.expand, children: [
              Image.file(File(widget.images[i].path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey))),
              if (sel) Container(color: Colors.blue.withOpacity(0.3), child: const Center(child: Icon(Icons.check_circle, color: Colors.blue, size: 36))),
            ]),
          );
        })),
    ]),
  );
}

// ─── FILE PICKER SHEET ───
class _FilePickerSheet extends StatefulWidget {
  final List<String> dirs;
  final void Function(List<File> selected) onImport;
  const _FilePickerSheet({required this.dirs, required this.onImport});
  @override State<_FilePickerSheet> createState() => _FilePickerSheetState();
}

class _FilePickerSheetState extends State<_FilePickerSheet> {
  final Set<String> _selected = {};
  List<FileSystemEntity> _files = [];
  bool _loading = true;
  String _currentDir = '';

  @override void initState() { super.initState(); _loadDir(widget.dirs.first); }

  Future<void> _loadDir(String dirPath) async {
    setState(() { _loading = true; _currentDir = dirPath; });
    try {
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        final list = dir.listSync().whereType<File>().toList();
        list.sort((a, b) => b.lengthSync().compareTo(a.lengthSync()));
        setState(() { _files = list; _loading = false; });
      } else {
        setState(() { _files = []; _loading = false; });
      }
    } catch (_) { setState(() { _files = []; _loading = false; }); }
  }

  @override Widget build(BuildContext context) => DraggableScrollableSheet(
    initialChildSize: 0.8, minChildSize: 0.4, maxChildSize: 0.95, expand: false,
    builder: (_, sc) => Column(children: [
      Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Expanded(child: Text('Sélectionner des fichiers (${_selected.length})', style: Theme.of(context).textTheme.titleMedium)),
        FilledButton(onPressed: _selected.isEmpty ? null : () => widget.onImport(_selected.map((p) => File(p)).toList()), child: Text('Chiffrer (${_selected.length})')),
      ])),
      // Directory tabs
      SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: widget.dirs.map((d) => Padding(padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(label: Text(d.substring(d.lastIndexOf('/') + 1)), selected: _currentDir == d, onSelected: (_) => _loadDir(d)),
      )).toList())),
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator()) : ListView.builder(controller: sc, itemCount: _files.length, itemBuilder: (_, i) {
        final f = _files[i] as File;
        final name = f.path.substring(f.path.lastIndexOf('/') + 1);
        final sel = _selected.contains(f.path);
        return CheckboxListTile(value: sel, onChanged: (v) => setState(() { if (v == true) _selected.add(f.path); else _selected.remove(f.path); }),
          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
          subtitle: Text(_fmtSize(f.lengthSync()), style: const TextStyle(fontSize: 11)));
      })),
    ]),
  );

  String _fmtSize(int b) { if (b < 1048576) return '${(b/1024).toStringAsFixed(1)} KB'; return '${(b/1048576).toStringAsFixed(1)} MB'; }
}
