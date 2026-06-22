// GiovaPlayer - Ecran de correction photo IA
// Contact: giobamos03@gmail.com | WhatsApp: +22670698070
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/ia_photo_fixer.dart';

/// Ecran de correction photo IA avec modes Auto et Pro
class IaPhotoFixScreen extends StatefulWidget {
  const IaPhotoFixScreen({super.key});

  @override
  State<IaPhotoFixScreen> createState() => _IaPhotoFixScreenState();
}

class _IaPhotoFixScreenState extends State<IaPhotoFixScreen> {
  bool _isAutoMode = true;
  double _intensity = 50.0;
  String _selectedPreset = 'Equilibre';
  ProSettings _proSettings = const ProSettings();
  FixState _fixState = const FixState();
  bool _showCompare = false;
  double _comparePosition = 0.5;
  Uint8List? _originalImage;
  Uint8List? _fixedImage;

  final List<String> _presets = ['Subtil', 'Equilibre', 'Standard', 'Intense'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('IA Photo Fix'),
        actions: [
          IconButton(
            onPressed: _resetAll,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reinitialiser',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildModeSelector(cs),
          Expanded(child: _buildImagePreview(cs)),
          Expanded(child: _isAutoMode ? _buildAutoPanel(cs) : _buildProPanel(cs)),
          _buildActionButtons(cs),
        ],
      ),
    );
  }

  /// Selecteur de mode Auto/Pro
  Widget _buildModeSelector(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Auto'), icon: Icon(Icons.auto_fix_high)),
          ButtonSegment(value: false, label: Text('Pro'), icon: Icon(Icons.tune)),
        ],
        selected: {_isAutoMode},
        onSelectionChanged: (v) => setState(() => _isAutoMode = v.first),
      ),
    );
  }

  /// Previsualisation de l'image avec comparaison
  Widget _buildImagePreview(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            _buildPlaceholder(cs),
            if (_showCompare && _fixedImage != null) _buildCompareSlider(cs),
          ],
        ),
      ),
    );
  }

  /// Placeholder de l'image
  Widget _buildPlaceholder(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('Selectionnez une photo',
              style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  /// Slider de comparaison avant/apres
  Widget _buildCompareSlider(ColorScheme cs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final splitX = constraints.maxWidth * _comparePosition;
        return Stack(
          children: [
            // Cote gauche - original
            Container(
              width: splitX,
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                border: Border(
                  right: BorderSide(color: cs.primary, width: 2),
                ),
              ),
              child: Center(
                child: Text('Avant',
                    style: TextStyle(color: cs.onSurfaceVariant)),
              ),
            ),
            // Cote droit - corrige
            Positioned(
              left: splitX,
              top: 0,
              bottom: 0,
              right: 0,
              child: Center(
                child: Text('Apres',
                    style: TextStyle(color: cs.primary)),
              ),
            ),
            // Slider de comparaison
            Positioned(
              left: splitX - 20,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _comparePosition =
                        (details.localPosition.dx / constraints.maxWidth)
                            .clamp(0.05, 0.95);
                  });
                },
                child: Container(
                  width: 40,
                  color: Colors.transparent,
                  child: Center(
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.compare_arrows,
                          color: cs.onPrimary, size: 18),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Panneau Auto - intensite et presets
  Widget _buildAutoPanel(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Intensite', style: Theme.of(context).textTheme.titleSmall),
          Row(
            children: [
              const Text('0%'),
              Expanded(
                child: Slider(
                  value: _intensity,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_intensity.round()}%',
                  onChanged: (v) => setState(() => _intensity = v),
                ),
              ),
              const Text('100%'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Presets', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _presets.map((preset) {
              final isSelected = _selectedPreset == preset;
              return ChoiceChip(
                label: Text(preset),
                selected: isSelected,
                onSelected: (_) => _selectPreset(preset),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Panneau Pro - reglages manuels
  Widget _buildProPanel(ColorScheme cs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProSlider('Exposition', _proSettings.exposure, (v) {
            setState(() => _proSettings = _proSettings.copyWith(exposure: v));
          }),
          _buildProSlider('Contraste', _proSettings.contrast, (v) {
            setState(() => _proSettings = _proSettings.copyWith(contrast: v));
          }),
          _buildProSlider('Nettete', _proSettings.sharpness, (v) {
            setState(() => _proSettings = _proSettings.copyWith(sharpness: v));
          }),
          _buildProSlider('Debruitage', _proSettings.denoise, (v) {
            setState(() => _proSettings = _proSettings.copyWith(denoise: v));
          }),
          _buildProSlider('Balance blancs', _proSettings.whiteBalance, (v) {
            setState(() => _proSettings = _proSettings.copyWith(whiteBalance: v));
          }),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Lissage visage'),
            value: _proSettings.faceSmooth,
            onChanged: (v) {
              setState(() => _proSettings = _proSettings.copyWith(faceSmooth: v));
            },
          ),
          SwitchListTile(
            title: const Text('Eclat des yeux'),
            value: _proSettings.eyeBright,
            onChanged: (v) {
              setState(() => _proSettings = _proSettings.copyWith(eyeBright: v));
            },
          ),
        ],
      ),
    );
  }

  /// Slider de reglage professionnel
  Widget _buildProSlider(String label, double value, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label)),
          Expanded(
            child: Slider(
              value: value,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(value * 100).round()}',
                textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }

  /// Boutons d'action principaux
  Widget _buildActionButtons(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _runAutoFix,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Auto Fix'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _toggleCompare,
              icon: const Icon(Icons.compare),
              label: const Text('Comparer'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saveResult,
              icon: const Icon(Icons.save),
              label: const Text('Sauver'),
            ),
          ),
        ],
      ),
    );
  }

  /// Selectionne un preset et ajuste l'intensite
  void _selectPreset(String preset) {
    final presetValues = {'Subtil': 25.0, 'Equilibre': 50.0, 'Standard': 70.0, 'Intense': 90.0};
    setState(() {
      _selectedPreset = preset;
      _intensity = presetValues[preset] ?? 50.0;
    });
  }

  /// Lance la correction automatique
  Future<void> _runAutoFix() async {
    if (_originalImage == null) return;
    setState(() => _fixState = const FixState(isProcessing: true, progress: 0.1, currentStep: 'Analyse...'));
    try {
      final fixer = IaPhotoFixer.instance;
      final result = await fixer.autoFix(_originalImage!, _intensity / 100);
      setState(() {
        _fixState = FixState(
          isProcessing: false,
          progress: 1.0,
          currentStep: 'Termine',
          result: result,
        );
        if (result.success) _fixedImage = result.imageData;
      });
    } catch (e) {
      setState(() => _fixState = FixState(isProcessing: false, error: e.toString()));
    }
  }

  /// Bascule le mode comparaison
  void _toggleCompare() {
    setState(() {
      _showCompare = !_showCompare;
      _comparePosition = 0.5;
    });
  }

  /// Sauvegarde le resultat
  void _saveResult() {
    if (_fixedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune image corrigee a sauvegarder')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image sauvegardee avec succes')),
    );
  }

  /// Reinitialise tous les reglages
  void _resetAll() {
    setState(() {
      _intensity = 50.0;
      _selectedPreset = 'Equilibre';
      _proSettings = const ProSettings();
      _showCompare = false;
      _fixedImage = null;
      _fixState = const FixState();
    });
  }
}
