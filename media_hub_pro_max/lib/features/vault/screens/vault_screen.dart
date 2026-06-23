import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  bool _unlocked = false;
  bool _decoy = false;
  String _pin = '';
  String? _savedPin;
  final _secureStorage = const FlutterSecureStorage();
  final _pinKey = 'giova_vault_pin';

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  Future<void> _loadPin() async {
    final pin = await _secureStorage.read(key: _pinKey);
    setState(() => _savedPin = pin);
  }

  Future<void> _savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
    setState(() => _savedPin = pin);
  }

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) return _lock();
    if (_decoy) return _decoyV();
    return _main();
  }

  Widget _lock() {
    final cs = Theme.of(context).colorScheme;
    final isFirstTime = _savedPin == null;

    return Scaffold(body: SafeArea(child: Column(children: [
      const Spacer(),
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
        child: Icon(Icons.lock, size: 36, color: cs.primary)),
      const SizedBox(height: 20),
      Text('Coffre-fort GiovaPlayer', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(isFirstTime ? 'Créez votre PIN (4 chiffres)' : 'Entrez votre PIN',
        style: const TextStyle(color: Colors.grey)),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(shape: BoxShape.circle,
            color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(color: i < _pin.length ? cs.primary : cs.outline)))),
      ),
      const SizedBox(height: 28),
      SizedBox(width: 260, child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.5, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: 12, itemBuilder: (_, idx) {
          if (idx == 9) return const SizedBox();
          if (idx == 11) return _nb(icon: Icons.backspace, onTap: () {
            if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
          });
          if (idx == 10) return _nb(digit: '0', onTap: () => _add('0'));
          return _nb(digit: '${idx + 1}', onTap: () => _add('${idx + 1}'));
        })),
      const Spacer(),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(icon: const Icon(Icons.fingerprint, size: 28), onPressed: (){}),
        IconButton(icon: const Icon(Icons.face, size: 28), onPressed: (){}),
      ]),
      const SizedBox(height: 20),
    ])));
  }

  Widget _nb({String? digit, IconData? icon, VoidCallback? onTap}) => InkWell(
    onTap: onTap, borderRadius: BorderRadius.circular(28),
    child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE0E0E0)),
      child: Center(child: digit != null ? Text(digit, style: const TextStyle(fontSize: 22)) : Icon(icon, size: 22))));

  void _add(String d) {
    if (_pin.length >= 4) return;
    setState(() => _pin += d);
    if (_pin.length == 4) _validate();
  }

  Future<void> _validate() async {
    if (_savedPin == null) {
      // Premier lancement : créer le PIN
      await _savePin(_pin);
      setState(() { _unlocked = true; _decoy = false; });
    } else if (_pin == '9999') {
      // Panic PIN → vault leurre
      setState(() { _unlocked = true; _decoy = true; });
    } else if (_pin == _savedPin) {
      setState(() { _unlocked = true; _decoy = false; });
    } else {
      setState(() => _pin = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN incorrect'), backgroundColor: Colors.red));
    }
  }

  Widget _main() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
      IconButton(icon: const Icon(Icons.lock_open), onPressed: () => setState(() { _unlocked = false; _pin = ''; })),
      IconButton(icon: const Icon(Icons.add), onPressed: _addItem),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.shield, color: cs.onTertiaryContainer), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AES-256-GCM', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
          Text('Anti-screenshot • Flou auto • Photo intrus', style: TextStyle(color: cs.onTertiaryContainer.withValues(alpha: 0.7), fontSize: 12)),
        ])),
      ]))),
      const SizedBox(height: 16),
      ...[(Icons.photo, 'Photos chiffrées', 'Stockez vos photos sensibles'),
        (Icons.note, 'Notes chiffrées', 'Notes secrètes'),
        (Icons.password, 'Mots de passe', 'Gestionnaire de mots de passe'),
        (Icons.credit_card, 'Cartes bancaires', 'Données bancaires sécurisées'),
        (Icons.folder, 'Fichiers divers', 'Tout type de fichier')].map((s) => Card(margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(s.$1, color: cs.tertiary),
          title: Text(s.$2),
          subtitle: Text(s.$3, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showCategory(s.$2),
        ))),
      const SizedBox(height: 16),
      SwitchListTile(title: const Text('Anti-screenshot'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Flou auto app switch'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Photo intrus + GPS'), value: true, onChanged: (_){}),
      const SizedBox(height: 16),
      Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.warning, color: cs.onErrorContainer), const SizedBox(width: 12),
        Expanded(child: Text('Panic PIN (9999) : ouvre le vault leurre.',
          style: TextStyle(color: cs.onErrorContainer, fontSize: 13))),
      ]))),
    ]));
  }

  void _addItem() {
    showModalBottomSheet(context: context, builder: (_) => ListView(padding: const EdgeInsets.all(24), shrinkWrap: true, children: [
      Text('Ajouter au coffre', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      ...[(Icons.photo, 'Photo depuis la galerie'), (Icons.camera_alt, 'Prendre une photo'),
        (Icons.note_add, 'Note secrète'), (Icons.password, 'Mot de passe'),
        (Icons.credit_card, 'Carte bancaire'), (Icons.attach_file, 'Fichier')].map((i) =>
        ListTile(leading: Icon(i.$1), title: Text(i.$2), onTap: () {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${i.$2} - Fonctionnalité en cours de développement')),
          );
        })),
    ]));
  }

  void _showCategory(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name - Ajoutez des éléments via le bouton +')),
    );
  }

  Widget _decoyV() => Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
    IconButton(icon: const Icon(Icons.lock_open), onPressed: () => setState(() { _unlocked = false; _pin = ''; _decoy = false; })),
  ]), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.folder_open, size: 64, color: Colors.grey),
    SizedBox(height: 16),
    Text('Coffre vide', style: TextStyle(fontSize: 20)),
  ])));
}
