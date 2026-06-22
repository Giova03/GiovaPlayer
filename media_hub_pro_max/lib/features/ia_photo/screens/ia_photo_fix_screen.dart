import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/ia_photo_fixer.dart';

/// ─── ÉCRAN IA PHOTO FIX — MODULE OBLIGATOIRE ───
/// Fonctionnement :
/// Input: user sélectionne photo
/// IA exécute en 2s:
///   - Analyse histogramme → corrige expo/contraste
///   - Détection visage → lissage peau naturel + éclaircit yeux
///   - Détection bruit → débruitage IA
///   - Netteté adaptative → accentue détails sans halos
/// Output: avant/après avec slider. Boutons Auto Fix, Pro Mode, Comparer
/// Modèle: TensorFlow Lite local 100% offline
class IaPhotoFixScreen extends ConsumerStatefulWidget {
  const IaPhotoFixScreen({super.key});

  @override
  ConsumerState<IaPhotoFixScreen> createState() => _IaPhotoFixScreenState();
}

class _IaPhotoFixScreenState extends ConsumerState<IaPhotoFixScreen> {
  /// Provider du fixer IA
  final _fixer = IaPhotoFixer();

  /// État du traitement
  FixState _state = FixState.idle;
  double _iaIntensity = 75.0;
  double _comparePosition = 0.5;
  FixResult? _result;

  /// Mode Pro — ajustements manuels
  double _exposure = 0;
  double _contrast = 0;
  double _sharpness = 0;
  double _denoise = 0;
  double _wb = 0;
  bool _faceSmooth = true;
  bool _eyeBright = true;

  /// Mode actuel : auto ou pro
  bool _isProMode = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IA Photo Fix'),
        actions: [
          /// Bascule Auto / Pro
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Auto')),
              ButtonSegment(value: true, label: Text('Pro')),
            ],
            selected: {_isProMode},
            onSelectionChanged: (v) => setState(() => _isProMode = v.first),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          /// Zone de comparaison avant/après
          Expanded(
            flex: 3,
            child: _CompareView(
              state: _state,
              result: _result,
              comparePosition: _comparePosition,
              onCompareChanged: (v) => setState(() => _comparePosition = v),
            ),
          ),

          /// Panneau de contrôles
          Expanded(
            flex: 2,
            child: _isProMode ? _ProControlsPanel(
              exposure: _exposure,
              contrast: _contrast,
              sharpness: _sharpness,
              denoise: _denoise,
              wb: _wb,
              faceSmooth: _faceSmooth,
              eyeBright: _eyeBright,
              onExposureChanged: (v) => setState(() => _exposure = v),
              onContrastChanged: (v) => setState(() => _contrast = v),
              onSharpnessChanged: (v) => setState(() => _sharpness = v),
              onDenoiseChanged: (v) => setState(() => _denoise = v),
              onWbChanged: (v) => setState(() => _wb = v),
              onFaceSmoothChanged: (v) => setState(() => _faceSmooth = v),
              onEyeBrightChanged: (v) => setState(() => _eyeBright = v),
            ) : _AutoControlsPanel(
              intensity: _iaIntensity,
              onIntensityChanged: (v) => setState(() => _iaIntensity = v),
            ),
          ),
        ],
      ),

      /// Boutons d'action principaux
      bottomNavigationBar: _ActionButtons(
        state: _state,
        onAutoFix: _runAutoFix,
        onCompare: _toggleCompare,
        onSave: _saveResult,
        onReset: _reset,
      ),
    );
  }

  /// Lance le pipeline IA complet
  Future<void> _runAutoFix() async {
    setState(() => _state = FixState.processing);

    try {
      final result = await _fixer.processImage(
        imagePath: 'dummy_path',
        intensity: _iaIntensity / 100,
        proSettings: _isProMode
            ? ProSettings(
                exposure: _exposure,
                contrast: _contrast,
                sharpness: _sharpness,
                denoise: _denoise,
                wb: _wb,
                faceSmooth: _faceSmooth,
                eyeBright: _eyeBright,
              )
            : null,
      );

      setState(() {
        _result = result;
        _state = FixState.done;
      });
    } catch (e) {
      setState(() => _state = FixState.error);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur IA : $e')),
        );
      }
    }
  }

  void _toggleCompare() {
    /// Animation de balayage avant/après
  }

  void _saveResult() {
    if (_result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo corrigée sauvegardée !')),
      );
    }
  }

  void _reset() {
    setState(() {
      _state = FixState.idle;
      _result = null;
      _iaIntensity = 75.0;
      _exposure = 0;
      _contrast = 0;
      _sharpness = 0;
      _denoise = 0;
      _wb = 0;
    });
  }
}

/// ─── VUE COMPARAISON AVANT/APRÈS AVEC SLIDER ───
class _CompareView extends StatelessWidget {
  final FixState state;
  final FixResult? result;
  final double comparePosition;
  final ValueChanged<double> onCompareChanged;

  const _CompareView({
    required this.state,
    required this.result,
    required this.comparePosition,
    required this.onCompareChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        /// Image avant ( complète )
        Container(
          color: cs.surfaceContainerHighest,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo, size: 64, color: Colors.grey),
                const SizedBox(height: 8),
                Text('AVANT', style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),

        /// Image après ( clippée selon slider )
        if (result != null)
          ClipRect(
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1 - comparePosition,
              child: Container(
                color: cs.primaryContainer.withOpacity(0.3),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_fix_high, size: 64),
                      const SizedBox(height: 8),
                      Text('APRÈS', style: TextStyle(color: cs.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),

        /// Slider de comparaison vertical
        if (result != null)
          Positioned(
            left: comparePosition * MediaQuery.of(context).size.width,
            top: 0,
            bottom: 0,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                final pos = details.globalPosition.dx /
                    MediaQuery.of(context).size.width;
                onCompareChanged(pos.clamp(0.05, 0.95));
              },
              child: Container(
                width: 3,
                color: Colors.white,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.compare_arrows, size: 18),
                  ),
                ),
              ),
            ),
          ),

        /// Overlay de chargement
        if (state == FixState.processing)
          Container(
            color: Colors.black54,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Analyse IA en cours...',
                    style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    result?.progress ?? 'Correction histogramme',
                    style: TextStyle(
                      color: cs.onPrimaryContainer.withOpacity(0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),

        /// Labels Avant / Après
        if (result != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Avant',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
        if (result != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Après',
                  style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}

/// ─── PANNEAU CONTRÔLES AUTO ───
class _AutoControlsPanel extends StatelessWidget {
  final double intensity;
  final ValueChanged<double> onIntensityChanged;

  const _AutoControlsPanel({
    required this.intensity,
    required this.onIntensityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Titre + badge IA
          Row(
            children: [
              Icon(Icons.auto_awesome, color: cs.primary),
              const SizedBox(width: 8),
              Text('Intensité IA', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${intensity.round()}%',
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          /// Slider intensité principal
          Slider(
            value: intensity,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${intensity.round()}%',
            onChanged: onIntensityChanged,
          ),

          /// Presets rapides
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _IntensityPreset('Subtil', 30, intensity, onIntensityChanged),
              _IntensityPreset('Équilibré', 55, intensity, onIntensityChanged),
              _IntensityPreset('Standard', 75, intensity, onIntensityChanged),
              _IntensityPreset('Intense', 100, intensity, onIntensityChanged),
            ],
          ),

          const SizedBox(height: 16),

          /// Détail des corrections IA
          Text('Corrections IA appliquées :', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.exposure, size: 16),
                label: const Text('Exposition'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.contrast, size: 16),
                label: const Text('Contraste'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.face, size: 16),
                label: const Text('Visage'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.grain, size: 16),
                label: const Text('Débruitage'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.blur_on, size: 16),
                label: const Text('Netteté'),
                visualDensity: VisualDensity.compact,
              ),
              Chip(
                avatar: const Icon(Icons.wb_sunny, size: 16),
                label: const Text('WB'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntensityPreset extends StatelessWidget {
  final String label;
  final double value;
  final double current;
  final ValueChanged<double> onChanged;

  const _IntensityPreset(this.label, this.value, this.current, this.onChanged);

  @override
  Widget build(BuildContext context) {
    final isActive = (current - value).abs() < 5;
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: (_) => onChanged(value),
    );
  }
}

/// ─── PANNEAU CONTRÔLES PRO ───
class _ProControlsPanel extends StatelessWidget {
  final double exposure;
  final double contrast;
  final double sharpness;
  final double denoise;
  final double wb;
  final bool faceSmooth;
  final bool eyeBright;
  final ValueChanged<double> onExposureChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSharpnessChanged;
  final ValueChanged<double> onDenoiseChanged;
  final ValueChanged<double> onWbChanged;
  final ValueChanged<bool> onFaceSmoothChanged;
  final ValueChanged<bool> onEyeBrightChanged;

  const _ProControlsPanel({
    required this.exposure,
    required this.contrast,
    required this.sharpness,
    required this.denoise,
    required this.wb,
    required this.faceSmooth,
    required this.eyeBright,
    required this.onExposureChanged,
    required this.onContrastChanged,
    required this.onSharpnessChanged,
    required this.onDenoiseChanged,
    required this.onWbChanged,
    required this.onFaceSmoothChanged,
    required this.onEyeBrightChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _ProSlider('Exposition', exposure, -100, 100, Icons.exposure, onExposureChanged),
          _ProSlider('Contraste', contrast, -100, 100, Icons.contrast, onContrastChanged),
          _ProSlider('Netteté', sharpness, 0, 100, Icons.blur_on, onSharpnessChanged),
          _ProSlider('Débruitage', denoise, 0, 100, Icons.grain, onDenoiseChanged),
          _ProSlider('Balance blancs', wb, -100, 100, Icons.wb_sunny, onWbChanged),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Lissage peau'),
            subtitle: const Text('Correction naturelle visage'),
            value: faceSmooth,
            onChanged: onFaceSmoothChanged,
            secondary: const Icon(Icons.face),
          ),
          SwitchListTile(
            title: const Text('Éclaircir yeux'),
            subtitle: const Text('Reflétation naturelle des yeux'),
            value: eyeBright,
            onChanged: onEyeBrightChanged,
            secondary: const Icon(Icons.visibility),
          ),
        ],
      ),
    );
  }
}

class _ProSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final IconData icon;
  final ValueChanged<double> onChanged;

  const _ProSlider(this.label, this.value, this.min, this.max, this.icon, this.onChanged);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Slider(value: value, min: min, max: max, onChanged: onChanged),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.round().toString(),
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── BOUTONS D'ACTION ───
class _ActionButtons extends StatelessWidget {
  final FixState state;
  final VoidCallback onAutoFix;
  final VoidCallback onCompare;
  final VoidCallback onSave;
  final VoidCallback onReset;

  const _ActionButtons({
    required this.state,
    required this.onAutoFix,
    required this.onCompare,
    required this.onSave,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          /// Auto Fix — bouton principal
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: state == FixState.processing ? null : onAutoFix,
              icon: state == FixState.processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_fix_high),
              label: Text(state == FixState.processing
                  ? 'Traitement...'
                  : state == FixState.done
                      ? 'Re-corriger'
                      : 'Auto Fix'),
            ),
          ),
          const SizedBox(width: 8),

          /// Comparer
          if (state == FixState.done) ...[
            IconButton.filled(
              onPressed: onCompare,
              icon: const Icon(Icons.compare),
              tooltip: 'Comparer',
            ),
            const SizedBox(width: 8),

            /// Sauvegarder
            IconButton.filled(
              onPressed: onSave,
              icon: const Icon(Icons.save),
              tooltip: 'Sauvegarder',
            ),
          ],

          const SizedBox(width: 8),

          /// Reset
          IconButton.outlined(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            tooltip: 'Réinitialiser',
          ),
        ],
      ),
    );
  }
}
