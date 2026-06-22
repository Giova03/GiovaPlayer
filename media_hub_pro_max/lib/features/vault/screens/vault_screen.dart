import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ─── ÉCRAN COFFRE-FORT AES-256-GCM ───
/// Features: Double PIN + empreinte + visage + clé USB OTG,
/// Vault decoy + Panic PIN, Anti-screenshot + flou auto + photo intrus + GPS,
/// Notes chiffrées + mots de passe + scanner carte bancaire
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  bool _isUnlocked = false;
  bool _showDecoyVault = false;
  int _failedAttempts = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_isUnlocked) {
      return _VaultLockScreen(
        onUnlock: _unlock,
        onPanicPin: _handlePanicPin,
        onDecoyPin: _handleDecoyPin,
      );
    }

    if (_showDecoyVault) {
      return _DecoyVaultContent(onLock: _lock);
    }

    return _VaultMainContent(onLock: _lock);
  }

  /// Déverrouillage réussi
  void _unlock() {
    setState(() {
      _isUnlocked = true;
      _showDecoyVault = false;
      _failedAttempts = 0;
    });
  }

  /// Panic PIN — supprime tout ou ouvre dossier fake
  void _handlePanicPin() {
    setState(() {
      _isUnlocked = true;
      _showDecoyVault = true;
    });
  }

  /// Decoy PIN — ouvre le vault leurre
  void _handleDecoyPin() {
    setState(() {
      _isUnlocked = true;
      _showDecoyVault = true;
    });
  }

  /// Reverrouillage
  void _lock() {
    setState(() {
      _isUnlocked = false;
      _showDecoyVault = false;
    });
  }
}

/// ─── ÉCRAN DE DÉVERROUILLAGE ───
class _VaultLockScreen extends StatefulWidget {
  final VoidCallback onUnlock;
  final VoidCallback onPanicPin;
  final VoidCallback onDecoyPin;

  const _VaultLockScreen({
    required this.onUnlock,
    required this.onPanicPin,
    required this.onDecoyPin,
  });

  @override
  State<_VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<_VaultLockScreen> {
  String _pin = '';
  bool _useBiometrics = true;

  @override
  void initState() {
    super.initState();
    /// Auto-tenter biométrie au lancement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometrics();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            /// Icône verrouillage
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primaryContainer,
              ),
              child: Icon(Icons.lock, size: 40, color: cs.primary),
            ),
            const SizedBox(height: 24),

            /// Titre
            Text('Coffre-fort', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Entrez votre PIN pour déverrouiller',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),

            /// Indicateurs PIN (4 cercles)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) => Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? cs.primary : cs.surfaceContainerHighest,
                  border: Border.all(
                    color: i < _pin.length ? cs.primary : cs.outline,
                  ),
                ),
              )),
            ),
            const SizedBox(height: 32),

            /// Clavier numérique
            SizedBox(
              width: 280,
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 1.5,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  if (index == 9) return const SizedBox();
                  if (index == 11) {
                    return _NumButton(
                      icon: Icons.backspace,
                      onTap: _deleteDigit,
                    );
                  }
                  if (index == 10) {
                    return _NumButton(
                      digit: '0',
                      onTap: () => _addDigit('0'),
                    );
                  }
                  final digit = (index + 1).toString();
                  return _NumButton(
                    digit: digit,
                    onTap: () => _addDigit(digit),
                  );
                },
              ),
            ),

            const Spacer(),

            /// Options biométrie
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.fingerprint, size: 32),
                  onPressed: _tryBiometrics,
                  tooltip: 'Empreinte digitale',
                ),
                IconButton(
                  icon: const Icon(Icons.face, size: 32),
                  onPressed: _tryFaceUnlock,
                  tooltip: 'Reconnaissance faciale',
                ),
                IconButton(
                  icon: const Icon(Icons.usb, size: 32),
                  onPressed: _tryUsbKey,
                  tooltip: 'Clé USB OTG',
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _addDigit(String digit) {
    if (_pin.length >= 4) return;
    setState(() => _pin += digit);
    if (_pin.length == 4) _validatePin();
  }

  void _deleteDigit() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Validation du PIN
  void _validatePin() {
    // En production : vérifier via libsodium
    // Panic PIN = "9999" par exemple
    if (_pin == '9999') {
      widget.onPanicPin();
    } else if (_pin == '0000') {
      widget.onDecoyPin();
    } else if (_pin == '1234') {
      /// PIN correct (demo)
      widget.onUnlock();
    } else {
      /// PIN incorrect
      setState(() => _pin = '');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PIN incorrect'),
          backgroundColor: Colors.red,
        ),
      );

      /// Photo intrus après 3 échecs
      if (mounted) {
        /// TODO: _captureIntruderPhoto();
      }
    }
  }

  /// Tentative biométrie
  void _tryBiometrics() {
    // En production : local_auth
    // Simulé : déverrouillage direct pour la démo
  }

  void _tryFaceUnlock() {
    // En production : local_auth avec Face ID
  }

  void _tryUsbKey() {
    // En production : USB OTG + clé physique
  }
}

class _NumButton extends StatelessWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onTap;

  const _NumButton({this.digit, this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
        ),
        child: Center(
          child: digit != null
              ? Text(digit!, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w500))
              : Icon(icon, size: 24),
        ),
      ),
    );
  }
}

/// ─── CONTENU PRINCIPAL DU COFFRE ───
class _VaultMainContent extends StatelessWidget {
  final VoidCallback onLock;

  const _VaultMainContent({required this.onLock});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffre-fort'),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_open),
            onPressed: onLock,
            tooltip: 'Verrouiller',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddMenu(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          /// Statistiques coffre
          _VaultStatsBar(),
          const SizedBox(height: 16),

          /// Sécurité active
          Card(
            color: cs.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.shield, color: cs.onTertiaryContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sécurité maximale',
                            style: TextStyle(
                              color: cs.onTertiaryContainer,
                              fontWeight: FontWeight.w600)),
                        Text(
                          'AES-256-GCM • Anti-screenshot actif • Flou auto',
                          style: TextStyle(
                            color: cs.onTertiaryContainer.withOpacity(0.7),
                            fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          /// Sections du coffre
          Text('Contenu', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          _VaultSection(
            icon: Icons.photo,
            title: 'Photos chiffrées',
            count: 24,
            onTap: () {},
          ),
          _VaultSection(
            icon: Icons.videocam,
            title: 'Vidéos chiffrées',
            count: 3,
            onTap: () {},
          ),
          _VaultSection(
            icon: Icons.note,
            title: 'Notes chiffrées',
            count: 12,
            onTap: () {},
          ),
          _VaultSection(
            icon: Icons.password,
            title: 'Mots de passe',
            count: 45,
            onTap: () {},
          ),
          _VaultSection(
            icon: Icons.credit_card,
            title: 'Cartes bancaires',
            count: 2,
            onTap: () {},
          ),
          _VaultSection(
            icon: Icons.folder,
            title: 'Fichiers divers',
            count: 8,
            onTap: () {},
          ),

          const SizedBox(height: 16),
          Text('Sécurité', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          SwitchListTile(
            title: const Text('Anti-screenshot'),
            subtitle: const Text('Bloque les captures d\'écran'),
            value: true,
            onChanged: (_) {},
            secondary: const Icon(Icons.screenshot),
          ),
          SwitchListTile(
            title: const Text('Flou auto si app switch'),
            subtitle: const Text('Floute l\'app dans le sélecteur récent'),
            value: true,
            onChanged: (_) {},
            secondary: const Icon(Icons.blur_on),
          ),
          SwitchListTile(
            title: const Text('Photo intrus'),
            subtitle: const Text('Photo + GPS après 3 PIN échoués'),
            value: true,
            onChanged: (_) {},
            secondary: const Icon(Icons.camera_alt),
          ),

          const SizedBox(height: 16),

          /// Panic PIN info
          Card(
            color: cs.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.warning, color: cs.onErrorContainer),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Panic PIN : entrez le PIN d\'urgence pour supprimer '
                      'toutes les données du coffre ou ouvrir le vault leurre.',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(24),
        shrinkWrap: true,
        children: [
          Text('Ajouter au coffre', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.photo),
            title: const Text('Photos'),
            subtitle: const Text('Chiffrer et déplacer des photos'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.note_add),
            title: const Text('Note chiffrée'),
            subtitle: const Text('Créer une note sécurisée'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.password),
            title: const Text('Mot de passe'),
            subtitle: const Text('Ajouter un identifiant'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.credit_card),
            title: const Text('Carte bancaire'),
            subtitle: const Text('Scanner ou saisir manuellement'),
            onTap: () {},
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: const Text('Fichier'),
            subtitle: const Text('Chiffrer n\'importe quel fichier'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

/// ─── STATS BAR ───
class _VaultStatsBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('94', style: Theme.of(context).textTheme.headlineSmall),
                  Text('Éléments', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('2.4 GB', style: Theme.of(context).textTheme.headlineSmall),
                  Text('Chiffré', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('0', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.green)),
                  Text('Intrusions', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ─── SECTION DU COFFRE ───
class _VaultSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _VaultSection({
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.tertiary),
        title: Text(title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count', style: TextStyle(
                color: Theme.of(context).colorScheme.onTertiaryContainer,
                fontSize: 12)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// ─── VAULT LEURRE (DECOY) ───
class _DecoyVaultContent extends StatelessWidget {
  final VoidCallback onLock;

  const _DecoyVaultContent({required this.onLock});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffre-fort'),
        actions: [
          IconButton(icon: const Icon(Icons.lock_open), onPressed: onLock),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Coffre vide',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Aucun élément chiffré',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
