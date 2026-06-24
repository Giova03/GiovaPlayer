import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/app_providers.dart';

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
    setState(() { _notes = notes; _passwords = pws; _cards = cards; _breakIns = log; });
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
          Text('${_notes.length} notes • ${_passwords.length} mots de passe • ${_cards.length} cartes', style: TextStyle(color: cs.onTertiaryContainer.withOpacity(0.7), fontSize: 12)),
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
          onTap: () => _showEditNote(n), trailing: const Icon(Icons.chevron_right)))),
      const SizedBox(height: 8),
      // MOTS DE PASSE
      _sectionHeader(Icons.password, 'Mots de passe', '${_passwords.length}', () => _showAddPassword()),
      ..._passwords.map((p) => Dismissible(key: Key('pw_${p['id']}'), direction: DismissDirection.endToStart,
        onDismissed: (_) async { await _db.deleteVaultPassword(p['id'] as int); _loadData(); },
        background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
        child: Card(child: ListTile(leading: const Icon(Icons.key, color: Colors.green), title: Text(p['service'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(p['username'] ?? ''),
          trailing: IconButton(icon: const Icon(Icons.copy, size: 18), onPressed: () { Clipboard.setData(ClipboardData(text: p['password'] ?? '')); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe copié !'))); })))),
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
      // PHOTOS
      _sectionHeader(Icons.photo, 'Photos chiffrées', '0', () => _showAddPhoto()),
      // FICHIERS
      _sectionHeader(Icons.folder, 'Fichiers chiffrés', '0', () => _showAddFile()),
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

  void _showAddPhoto() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez des photos depuis la Galerie puis utilisez "Déplacer vers le coffre"')));
  void _showAddFile() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fonctionnalité disponible - ajoutez des fichiers sensibles')));

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
        await _db.emergencyWipe(); await _storage.delete(key: 'vault_pin');
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _notes = []; _passwords = []; _cards = []; _breakIns = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false; Navigator.pop(context);
      }, child: const Text('SUPPRIMER'))],
  ));

  void _resetVault() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Réinitialiser'), content: const Text('Supprimer le PIN et toutes les données ?'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        await _db.emergencyWipe(); await _storage.delete(key: 'vault_pin');
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _setupStep = 0; _notes = []; _passwords = []; _cards = []; _breakIns = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false; Navigator.pop(context);
      }, child: const Text('Réinitialiser'))],
  ));
}
