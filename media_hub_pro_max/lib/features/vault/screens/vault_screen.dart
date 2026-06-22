// GiovaPlayer - Coffre-fort avec PIN et biomimetrie
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/constants/app_constants.dart';

/// Ecran du coffre-fort GiovaPlayer
class VaultScreen extends ConsumerStatefulWidget {
  const VaultScreen({super.key});

  @override
  ConsumerState<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends ConsumerState<VaultScreen> {
  String _pin = '';
  bool _isUnlocked = false;
  bool _isPanicMode = false;
  int _attempts = 0;
  String? _error;

  static const String _panicPin = AppConstants.panicPin;
  static const int _maxAttempts = AppConstants.maxPinAttempts;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_isUnlocked) {
      return _buildPinLockScreen(cs);
    }
    if (_isPanicMode) {
      return _buildDecoyVault(cs);
    }
    return _buildMainVault(cs);
  }

  /// Ecran de verrouillage PIN
  Widget _buildPinLockScreen(ColorScheme cs) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: cs.primary),
              const SizedBox(height: 16),
              Text('Coffre-fort GiovaPlayer',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text('Entrez votre code PIN a 4 chiffres',
                  style: TextStyle(color: cs.onSurfaceVariant)),
              const SizedBox(height: 24),
              _buildPinDots(cs),
              const SizedBox(height: 8),
              if (_error != null)
                Text(_error!, style: TextStyle(color: cs.error, fontSize: 13)),
              const SizedBox(height: 16),
              _buildNumericKeypad(cs),
              const SizedBox(height: 16),
              _buildBiometricButtons(cs),
            ],
          ),
        ),
      ),
    );
  }

  /// Indicateurs de points PIN
  Widget _buildPinDots(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final filled = i < _pin.length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? cs.primary : cs.surfaceContainerHighest,
            border: Border.all(
              color: filled ? cs.primary : cs.outline,
              width: 2,
            ),
          ),
        );
      }),
    );
  }

  /// Clavier numerique pour le PIN
  Widget _buildNumericKeypad(ColorScheme cs) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 72, height: 72);
            if (key == 'del') {
              return _buildKeypadButton(
                Icons.backspace_outlined, cs, () => _onDelKey(),
                isIcon: true,
              );
            }
            return _buildKeypadButton(key, cs, () => _onDigitKey(key));
          }).toList(),
        );
      }).toList(),
    );
  }

  /// Bouton individuel du clavier
  Widget _buildKeypadButton(dynamic label, ColorScheme cs, VoidCallback onTap,
      {bool isIcon = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surfaceContainerHighest,
        ),
        child: Center(
          child: isIcon
              ? Icon(label, color: cs.onSurface, size: 24)
              : Text(label.toString(),
                  style: Theme.of(context).textTheme.headlineSmall),
        ),
      ),
    );
  }

  /// Boutons biométriques
  Widget _buildBiometricButtons(ColorScheme cs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildBioButton(Icons.fingerprint, 'Empreinte', cs),
        const SizedBox(width: 16),
        _buildBioButton(Icons.face, 'Visage', cs),
        const SizedBox(width: 16),
        _buildBioButton(Icons.usb, 'Cle USB', cs),
      ],
    );
  }

  /// Bouton biométrique individuel
  Widget _buildBioButton(IconData icon, String label, ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: () {
            // Simulation de biomimetrie - en production utiliser local_auth
            _unlock();
          },
          icon: Icon(icon, size: 28, color: cs.primary),
          style: IconButton.styleFrom(
            backgroundColor: cs.primaryContainer,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  /// Gestion de la touche chiffre
  void _onDigitKey(String digit) {
    if (_pin.length >= 4) return;
    setState(() {
      _pin += digit;
      _error = null;
    });
    if (_pin.length == 4) _validatePin();
  }

  /// Gestion de la touche effacer
  void _onDelKey() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  /// Validation du PIN saisi
  void _validatePin() {
    if (_pin == _panicPin) {
      setState(() {
        _isUnlocked = true;
        _isPanicMode = true;
      });
      return;
    }
    // En production, comparer avec le PIN hashé stocké
    if (_pin == AppConstants.defaultVaultPin) {
      _unlock();
    } else {
      _attempts++;
      setState(() {
        _pin = '';
        if (_attempts >= _maxAttempts) {
          _error = 'Trop de tentatives. Reessayez plus tard.';
        } else {
          _error = 'PIN incorrect (${_maxAttempts - _attempts} essais restants)';
        }
      });
    }
  }

  /// Debloque le coffre-fort
  void _unlock() {
    setState(() {
      _isUnlocked = true;
      _isPanicMode = false;
      _pin = '';
      _attempts = 0;
    });
    ref.read(vaultUnlockedProvider.notifier).state = true;
  }

  /// Contenu principal du coffre-fort
  Widget _buildMainVault(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffre-fort'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isUnlocked = false;
                _pin = '';
              });
              ref.read(vaultUnlockedProvider.notifier).state = false;
            },
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Verrouiller',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsBar(cs),
            const SizedBox(height: 16),
            _buildSecurityCard(cs),
            const SizedBox(height: 16),
            _buildSectionsList(cs),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Barre de statistiques du coffre
  Widget _buildStatsBar(ColorScheme cs) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(cs, Icons.folder, '0', 'Fichiers'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(cs, Icons.storage, '0 Mo', 'Utilise'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard(cs, Icons.security, 'AES-256', 'Chiffrement'),
        ),
      ],
    );
  }

  /// Carte de statistique individuelle
  Widget _buildStatCard(ColorScheme cs, IconData icon, String value, String label) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: cs.primary, size: 24),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  /// Carte de securite
  Widget _buildSecurityCard(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield, color: cs.primary),
                const SizedBox(width: 8),
                Text('Securite', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _buildSecurityRow(Icons.lock, 'Chiffrement', 'AES-256 actif'),
            _buildSecurityRow(Icons.fingerprint, 'Biomimetrie', 'Configuree'),
            _buildSecurityRow(Icons.timer, 'Verrouillage auto', '5 minutes'),
            _buildSecurityRow(Icons.warning, 'PIN panique', 'Configure'),
          ],
        ),
      ),
    );
  }

  /// Ligne d'information de securite
  Widget _buildSecurityRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(child: Text(title)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  /// Liste des sections du coffre
  Widget _buildSectionsList(ColorScheme cs) {
    final sections = [
      _Section(Icons.photo, 'Photos', 0, cs.primary),
      _Section(Icons.videocam, 'Videos', 0, cs.tertiary),
      _Section(Icons.audiotrack, 'Audios', 0, cs.secondary),
      _Section(Icons.description, 'Documents', 0, cs.error),
      _Section(Icons.vpn_key, 'Mots de passe', 0, cs.tertiary),
      _Section(Icons.note, 'Notes', 0, cs.primary),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Categories', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...sections.map((s) => Card(
              child: ListTile(
                leading: Icon(s.icon, color: s.color),
                title: Text(s.label),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${s.count}', style: TextStyle(color: cs.onSurfaceVariant)),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {},
              ),
            )),
      ],
    );
  }

  /// Coffre leurre (vide) - active par PIN panique
  Widget _buildDecoyVault(ColorScheme cs) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coffre-fort'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                _isUnlocked = false;
                _isPanicMode = false;
                _pin = '';
              });
            },
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('Coffre vide',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 18)),
            const SizedBox(height: 8),
            Text('Aucun fichier protege',
                style: TextStyle(color: cs.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Section du coffre-fort
class _Section {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  const _Section(this.icon, this.label, this.count, this.color);
}
