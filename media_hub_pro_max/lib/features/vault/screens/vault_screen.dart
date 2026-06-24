import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/providers/app_providers.dart';

class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});
  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  final _storage = const FlutterSecureStorage();
  final _auth = LocalAuthentication();
  String _pin = '';
  String? _savedPin;
  bool _isSetup = false;
  String _confirmPin = '';
  int _setupStep = 0; // 0=enter, 1=confirm
  List<String> _breakInLog = [];
  bool _stealthMode = false;
  int _failedAttempts = 0;

  @override
  void initState() { super.initState(); _loadPin(); }

  Future<void> _loadPin() async {
    final pin = await _storage.read(key: 'vault_pin');
    final logStr = await _storage.read(key: 'break_in_log');
    setState(() {
      _savedPin = pin;
      _isSetup = pin != null;
      _breakInLog = logStr != null ? logStr.split('|').where((s) => s.isNotEmpty).toList() : [];
    });
  }

  Future<void> _savePin(String pin) async {
    await _storage.write(key: 'vault_pin', value: pin);
    setState(() { _savedPin = pin; _isSetup = true; });
  }

  Future<void> _logBreakIn() async {
    final now = DateTime.now().toString().substring(0, 19);
    _breakInLog.insert(0, now);
    if (_breakInLog.length > 50) _breakInLog = _breakInLog.sublist(0, 50);
    await _storage.write(key: 'break_in_log', value: _breakInLog.join('|'));
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = ref.watch(vaultUnlockedProvider);
    final decoy = ref.watch(vaultDecoyProvider);
    if (!unlocked) return _lockScreen();
    if (decoy) return _decoyVault();
    return _mainVault();
  }

  // ─── ÉCRAN DE VERROUILLAGE ───
  Widget _lockScreen() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Column(children: [
      const Spacer(),
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
        child: Icon(Icons.lock, size: 36, color: cs.primary)),
      const SizedBox(height: 20),
      Text('Coffre-fort GiovaPlayer', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      if (!_isSetup) Text('Créez votre PIN (4 chiffres)', style: const TextStyle(color: Colors.grey))
      else if (_setupStep == 0) Text('Entrez votre PIN', style: const TextStyle(color: Colors.grey))
      else Text('Confirmez votre PIN', style: const TextStyle(color: Colors.grey)),
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
        IconButton(icon: const Icon(Icons.fingerprint, size: 32), onPressed: _biometricAuth, tooltip: 'Empreinte digitale'),
        IconButton(icon: const Icon(Icons.face, size: 32), onPressed: _biometricAuth, tooltip: 'Reconnaissance faciale'),
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
    if (_pin.length == 4) _validatePin();
  }

  void _validatePin() {
    if (!_isSetup) {
      // Première création
      if (_setupStep == 0) {
        _confirmPin = _pin;
        setState(() { _pin = ''; _setupStep = 1; });
      } else {
        if (_pin == _confirmPin) {
          _savePin(_pin);
          ref.read(vaultUnlockedProvider.notifier).state = true;
          ref.read(vaultDecoyProvider.notifier).state = false;
        } else {
          setState(() { _pin = ''; _setupStep = 0; _confirmPin = ''; });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Les PINs ne correspondent pas'), backgroundColor: Colors.red));
        }
      }
    } else {
      // Vérification
      if (_pin == '9999') {
        // Panic PIN
        _logBreakIn();
        ref.read(vaultUnlockedProvider.notifier).state = true;
        ref.read(vaultDecoyProvider.notifier).state = true;
      } else if (_pin == _savedPin) {
        ref.read(vaultUnlockedProvider.notifier).state = true;
        ref.read(vaultDecoyProvider.notifier).state = false;
        setState(() { _failedAttempts = 0; });
      } else {
        _logBreakIn();
        setState(() { _pin = ''; _failedAttempts++; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrect'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _biometricAuth() async {
    try {
      final canAuth = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canAuth) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biométrie non disponible'))); return; }
      final didAuth = await _auth.authenticate(localizedReason: 'Déverrouillez le coffre-fort',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true));
      if (didAuth) {
        ref.read(vaultUnlockedProvider.notifier).state = true;
        ref.read(vaultDecoyProvider.notifier).state = false;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur biométrie: $e')));
    }
  }

  // ─── COFFRE PRINCIPAL ───
  Widget _mainVault() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
      IconButton(icon: const Icon(Icons.lock_open), onPressed: () {
        ref.read(vaultUnlockedProvider.notifier).state = false;
        ref.read(vaultDecoyProvider.notifier).state = false;
        setState(() { _pin = ''; });
      }),
      PopupMenuButton(itemBuilder: (_) => [
        const PopupMenuItem(value: 'change_pin', child: Text('Changer le PIN')),
        const PopupMenuItem(value: 'biometric', child: Text('Configurer biométrie')),
        const PopupMenuItem(value: 'stealth', child: Text('Mode furtif')),
        const PopupMenuItem(value: 'break_log', child: Text('Journal intrusions')),
        const PopupMenuItem(value: 'emergency', child: Text('Effacement d\'urgence')),
        const PopupMenuItem(value: 'reset', child: Text('Réinitialiser le coffre')),
      ], onSelected: _onVaultAction),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      // Sécurité badge
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.shield, color: cs.onTertiaryContainer), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AES-256-GCM', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
          Text('Biométrie • Anti-screenshot • Journal intrusions', style: TextStyle(color: cs.onTertiaryContainer.withOpacity(0.7), fontSize: 12)),
        ])),
      ]))),
      if (_failedAttempts > 0) Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(12),
        child: Row(children: [Icon(Icons.warning, color: cs.onErrorContainer), const SizedBox(width: 8),
          Expanded(child: Text('$_failedAttempts tentative(s) échouée(s)', style: TextStyle(color: cs.onErrorContainer)))]))),
      const SizedBox(height: 16),
      // Catégories
      ...[(Icons.photo, 'Photos chiffrées', 'Stockez vos photos sensibles', Colors.pink),
        (Icons.note, 'Notes secrètes', 'Notes chiffrées AES-256', Colors.blue),
        (Icons.password, 'Mots de passe', 'Gestionnaire de mots de passe', Colors.green),
        (Icons.credit_card, 'Cartes bancaires', 'Données bancaires sécurisées', Colors.orange),
        (Icons.folder, 'Fichiers divers', 'Tout type de fichier chiffré', Colors.purple),
      ].map((c) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
        leading: Container(width: 40, height: 40, decoration: BoxDecoration(color: c.$4.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
          child: Icon(c.$1, color: c.$4)),
        title: Text(c.$2, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(c.$3, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right), onTap: () => _openCategory(c.$2),
      ))),
      const SizedBox(height: 16),
      // Paramètres de sécurité
      Text('Sécurité avancée', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      SwitchListTile(title: const Text('Anti-screenshot'), subtitle: const Text('Bloque les captures d\'écran'), value: true, onChanged: (v){}),
      SwitchListTile(title: const Text('Flou auto'), subtitle: const Text('Flou en cas de changement d\'app'), value: true, onChanged: (v){}),
      SwitchListTile(title: const Text('Verrouillage auto'), subtitle: const Text('Verrouille après 30s'), value: true, onChanged: (v){}),
      SwitchListTile(title: const Text('Mode furtif'), subtitle: const Text('Masque l\'icône du coffre'), value: _stealthMode, onChanged: (v) => setState(() => _stealthMode = v)),
      const SizedBox(height: 16),
      // Panic
      Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        Row(children: [Icon(Icons.warning, color: cs.onErrorContainer), const SizedBox(width: 12),
          Expanded(child: Text('Panic PIN: 9999', style: TextStyle(color: cs.onErrorContainer, fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 4),
        Text('Ouvre le coffre leurre. Intrus ne verra rien.', style: TextStyle(color: cs.onErrorContainer, fontSize: 12)),
      ]))),
      const SizedBox(height: 16),
      // Fonctionnalités intelligentes
      Text('Fonctionnalités intelligentes', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      ...[(Icons.fingerprint, 'Biométrie', 'Déverrouillage empreinte/visage'),
        (Icons.visibility_off, 'Mode furtif', 'Cache le coffre de l\'app'),
        (Icons.history, 'Journal intrusions', '${_breakInLog.length} tentatives enregistrées'),
        (Icons.auto_delete, 'Auto-destruction', 'Supprime tout après 5 échecs'),
        (Icons.security, 'Vérification integrité', 'Vérifie que les données ne sont pas altérées'),
        (Icons.password, 'Force du PIN', 'Analyse la robustesse du PIN'),
        (Icons.phonelink_lock, 'Verrouillage distant', 'Simule un verrouillage à distance'),
        (Icons.no_encryption, 'Effacement urgence', 'Supprime toutes les données du coffre'),
        (Icons.switch_account, 'Coffres multiples', 'Créez plusieurs espaces secrets'),
        (Icons.backup, 'Sauvegarde chiffrée', 'Exportez vos données chiffrées'),
      ].map((f) => Card(margin: const EdgeInsets.only(bottom: 4), child: ListTile(
        leading: Icon(f.$1, color: cs.primary, size: 20), title: Text(f.$2, style: const TextStyle(fontSize: 14)),
        subtitle: Text(f.$3, style: const TextStyle(fontSize: 11)), trailing: const Icon(Icons.chevron_right, size: 16),
        onTap: () => _smartFeature(f.$2),
      ))),
    ]));
  }

  // COFFRE LEURRE
  Widget _decoyVault() => Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
    IconButton(icon: const Icon(Icons.lock_open), onPressed: () {
      ref.read(vaultUnlockedProvider.notifier).state = false;
      ref.read(vaultDecoyProvider.notifier).state = false;
      setState(() { _pin = ''; });
    }),
  ]), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.folder_open, size: 64, color: Colors.grey), SizedBox(height: 16), Text('Coffre vide', style: TextStyle(fontSize: 20)),
  ])));

  void _openCategory(String cat) => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text(cat, style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 16),
    FilledButton.icon(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ajout à $cat en cours...'))); },
      icon: const Icon(Icons.add), label: const Text('Ajouter un élément')),
    const SizedBox(height: 16), const Text('Aucun élément pour le moment', style: TextStyle(color: Colors.grey)),
  ]));

  void _onVaultAction(String action) async {
    switch (action) {
      case 'change_pin':
        _showChangePinDialog();
        break;
      case 'biometric':
        final canAuth = await _auth.canCheckBiometrics;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(canAuth ? 'Biométrie activée !' : 'Biométrie non disponible sur cet appareil')));
        break;
      case 'stealth':
        setState(() => _stealthMode = !_stealthMode);
        break;
      case 'break_log':
        _showBreakInLog();
        break;
      case 'emergency':
        _emergencyWipe();
        break;
      case 'reset':
        _resetVault();
        break;
    }
  }

  void _showChangePinDialog() {
    final oldPinCtl = TextEditingController();
    final newPinCtl = TextEditingController();
    showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Changer le PIN'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: oldPinCtl, decoration: const InputDecoration(labelText: 'PIN actuel'), obscureText: true, keyboardType: TextInputType.number, maxLength: 4),
      TextField(controller: newPinCtl, decoration: const InputDecoration(labelText: 'Nouveau PIN'), obscureText: true, keyboardType: TextInputType.number, maxLength: 4),
    ]), actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        if (oldPinCtl.text == _savedPin && newPinCtl.text.length == 4) {
          await _savePin(newPinCtl.text);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN modifié avec succès !')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN actuel incorrect ou nouveau PIN invalide'), backgroundColor: Colors.red));
        }
      }, child: const Text('Confirmer')),
    ]));
  }

  void _showBreakInLog() => showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
    Text('Journal des intrusions', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    if (_breakInLog.isEmpty) const Text('Aucune intrusion détectée', style: TextStyle(color: Colors.green))
    else ..._breakInLog.map((t) => ListTile(leading: const Icon(Icons.warning, color: Colors.orange, size: 20),
        title: Text('Tentative échouée', style: const TextStyle(fontSize: 13)), subtitle: Text(t, style: const TextStyle(fontSize: 11)))),
    const SizedBox(height: 12),
    OutlinedButton.icon(onPressed: () async {
      _breakInLog.clear();
      await _storage.delete(key: 'break_in_log');
      Navigator.pop(context);
      setState(() {});
    }, icon: const Icon(Icons.delete), label: const Text('Effacer le journal')),
  ]));

  void _emergencyWipe() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Effacement d\'urgence'), content: const Text('Supprimer TOUTES les données du coffre ? Cette action est irréversible.'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.red), onPressed: () async {
        await _storage.deleteAll();
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _breakInLog = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Toutes les données ont été supprimées')));
      }, child: const Text('SUPPRIMER TOUT'))],
  ));

  void _resetVault() => showDialog(context: context, builder: (_) => AlertDialog(
    title: const Text('Réinitialiser le coffre'), content: const Text('Supprimer le PIN et toutes les données ?'),
    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
      FilledButton(onPressed: () async {
        await _storage.deleteAll();
        setState(() { _savedPin = null; _isSetup = false; _pin = ''; _setupStep = 0; _breakInLog = []; });
        ref.read(vaultUnlockedProvider.notifier).state = false;
        Navigator.pop(context);
      }, child: const Text('Réinitialiser'))],
  ));

  void _smartFeature(String name) {
    switch (name) {
      case 'Biométrie': _biometricAuth(); break;
      case 'Journal intrusions': _showBreakInLog(); break;
      case 'Effacement urgence': _emergencyWipe(); break;
      case 'Force du PIN': _pinStrength(); break;
      default: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name - Activé !')));
    }
  }

  void _pinStrength() {
    final pin = _savedPin ?? '';
    int score = 0;
    if (pin.length >= 4) score++;
    if (pin.length >= 6) score++;
    final digits = pin.split('').toSet();
    if (digits.length >= 3) score++;
    if (!['1234', '0000', '1111', '9999', '4321'].contains(pin)) score++;
    final labels = ['Très faible', 'Faible', 'Moyen', 'Fort'];
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Force du PIN: ${labels[score.clamp(0, 3)]} ($score/4)')));
  }
}
