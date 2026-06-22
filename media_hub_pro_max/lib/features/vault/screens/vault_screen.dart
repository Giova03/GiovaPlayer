import 'package:flutter/material.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});
  @override
  State<VaultScreen> createState() => _S();
}
class _S extends State<VaultScreen> {
  bool _unlocked = false; bool _decoy = false; String _pin = '';

  @override
  Widget build(BuildContext context) {
    if (!_unlocked) return _lock();
    if (_decoy) return _decoyV();
    return _main();
  }

  Widget _lock() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(body: SafeArea(child: Column(children: [
      const Spacer(),
      Container(width: 72, height: 72, decoration: BoxDecoration(shape: BoxShape.circle, color: cs.primaryContainer),
        child: Icon(Icons.lock, size: 36, color: cs.primary)),
      const SizedBox(height: 20),
      Text('Coffre-fort GiovaPlayer', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Entrez votre PIN', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 28),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (i) => Container(width: 14, height: 14, margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(shape: BoxShape.circle, color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(color: i < _pin.length ? cs.primary : cs.outline)))),
      const SizedBox(height: 28),
      SizedBox(width: 260, child: GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, childAspectRatio: 1.5, mainAxisSpacing: 6, crossAxisSpacing: 6),
        itemCount: 12, itemBuilder: (_, idx) {
          if (idx == 9) return const SizedBox();
          if (idx == 11) return _nb(icon: Icons.backspace, onTap: () { if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1)); });
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

  Widget _nb({String? digit, IconData? icon, VoidCallback? onTap}) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(28),
    child: Container(decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE0E0E0)),
      child: Center(child: digit != null ? Text(digit, style: const TextStyle(fontSize: 22)) : Icon(icon, size: 22))));

  void _add(String d) { if (_pin.length >= 4) return; setState(() => _pin += d); if (_pin.length == 4) _validate(); }
  void _validate() {
    if (_pin == '9999') setState(() { _unlocked = true; _decoy = true; })
    else if (_pin == '1234') setState(() { _unlocked = true; _decoy = false; })
    else { setState(() => _pin = ''); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN incorrect'), backgroundColor: Colors.red)); }
  }

  Widget _main() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
      IconButton(icon: const Icon(Icons.lock_open), onPressed: () => setState(() { _unlocked = false; _pin = ''; })),
      IconButton(icon: const Icon(Icons.add), onPressed: (){}),
    ]), body: ListView(padding: const EdgeInsets.all(16), children: [
      Card(color: cs.tertiaryContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.shield, color: cs.onTertiaryContainer), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('AES-256-GCM', style: TextStyle(color: cs.onTertiaryContainer, fontWeight: FontWeight.w600)),
          Text('Anti-screenshot • Flou auto • Photo intrus', style: TextStyle(color: cs.onTertiaryContainer.withValues(alpha:0.7), fontSize: 12)),
        ])),
      ]))),
      const SizedBox(height: 16),
      ...[(Icons.photo,'Photos chiffrees',24),(Icons.note,'Notes chiffrees',12),(Icons.password,'Mots de passe',45),
        (Icons.credit_card,'Cartes bancaires',2),(Icons.folder,'Fichiers divers',8)].map((s) => Card(margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(leading: Icon(s.$1, color: cs.tertiary), title: Text(s.$2),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: cs.tertiaryContainer, borderRadius: BorderRadius.circular(12)),
              child: Text('${s.$3}', style: TextStyle(color: cs.onTertiaryContainer, fontSize: 12))),
            const SizedBox(width: 8), const Icon(Icons.chevron_right)])))),
      const SizedBox(height: 16),
      SwitchListTile(title: const Text('Anti-screenshot'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Flou auto app switch'), value: true, onChanged: (_){}),
      SwitchListTile(title: const Text('Photo intrus + GPS'), value: true, onChanged: (_){}),
      const SizedBox(height: 16),
      Card(color: cs.errorContainer, child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
        Icon(Icons.warning, color: cs.onErrorContainer), const SizedBox(width: 12),
        Expanded(child: Text('Panic PIN (9999) : ouvre le vault leurre ou supprime tout.',
          style: TextStyle(color: cs.onErrorContainer, fontSize: 13))),
      ]))),
    ]));
  }

  Widget _decoyV() => Scaffold(appBar: AppBar(title: const Text('Coffre-fort'), actions: [
    IconButton(icon: const Icon(Icons.lock_open), onPressed: () => setState(() { _unlocked = false; _pin = ''; _decoy = false; })),
  ]), body: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.folder_open, size: 64, color: Colors.grey),
    SizedBox(height: 16),
    Text('Coffre vide', style: TextStyle(fontSize: 20)),
  ])));
}
