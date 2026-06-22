import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ia_photo_fixer.dart';

class IaPhotoFixScreen extends ConsumerStatefulWidget {
  const IaPhotoFixScreen({super.key});
  @override
  ConsumerState<IaPhotoFixScreen> createState() => _S();
}
class _S extends ConsumerState<IaPhotoFixScreen> {
  final _fixer = IaPhotoFixer();
  FixState _state = FixState.idle;
  double _intensity = 75;
  double _cmpPos = 0.5;
  FixResult? _result;
  bool _pro = false;
  double _exp=0,_con=0,_shp=0,_den=0,_wb=0;
  bool _fsm=true,_eyb=true;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(appBar: AppBar(title: const Text('IA Photo Fix'), actions: [
      SegmentedButton<bool>(segments: const [ButtonSegment(value: false, label: Text('Auto')), ButtonSegment(value: true, label: Text('Pro'))],
        selected: {_pro}, onSelectionChanged: (v) => setState(() => _pro = v.first)),
      const SizedBox(width: 8),
    ]), body: Column(children: [
      Expanded(flex: 3, child: Stack(children: [
        Container(color: cs.surfaceContainerHighest, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.photo, size: 64, color: Colors.grey),
          const SizedBox(height: 8),
          Text('AVANT', style: TextStyle(color: cs.onSurfaceVariant)),
        ]))),
        if (_result != null) ClipRect(child: Align(alignment: Alignment.centerRight, widthFactor: 1 - _cmpPos,
          child: Container(color: cs.primaryContainer.withValues(alpha:0.3), child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_fix_high, size: 64), const SizedBox(height: 8),
            Text('APRES', style: TextStyle(color: cs.primary)),
          ]))))),
        if (_result != null) Positioned(left: _cmpPos * MediaQuery.of(context).size.width, top: 0, bottom: 0,
          child: GestureDetector(onHorizontalDragUpdate: (d) => setState(() => _cmpPos = (d.globalPosition.dx / MediaQuery.of(context).size.width).clamp(0.05, 0.95)),
            child: Container(width: 3, color: Colors.white, child: Center(child: Container(width: 28, height: 28,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha:0.3), blurRadius: 8)]),
              child: const Icon(Icons.compare_arrows, size: 16)))))),
        if (_state == FixState.processing) Container(color: Colors.black54, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 16),
          const Text('Analyse IA en cours...', style: TextStyle(color: Colors.white)),
        ]))),
      ])),
      Expanded(flex: 2, child: _pro ? _proPanel(cs) : _autoPanel(cs)),
    ]), bottomNavigationBar: Container(padding: const EdgeInsets.all(16), child: Row(children: [
      Expanded(flex: 2, child: FilledButton.icon(
        onPressed: _state == FixState.processing ? null : _run,
        icon: _state == FixState.processing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high),
        label: Text(_state == FixState.processing ? 'Traitement...' : _state == FixState.done ? 'Re-corriger' : 'Auto Fix'))),
      if (_result != null) ...[const SizedBox(width: 8),
        IconButton.filled(onPressed: (){}, icon: const Icon(Icons.compare)),
        IconButton.filled(onPressed: _save, icon: const Icon(Icons.save))],
      const SizedBox(width: 8),
      IconButton.outlined(onPressed: _reset, icon: const Icon(Icons.refresh)),
    ])));
  }

  Widget _autoPanel(ColorScheme cs) => Container(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Icon(Icons.auto_awesome, color: cs.primary), const SizedBox(width: 8),
      Text('Intensite IA', style: Theme.of(context).textTheme.titleMedium),
      const Spacer(),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(20)),
        child: Text('${_intensity.round()}%', style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700)))]),
    const SizedBox(height: 16),
    Slider(value: _intensity, min: 0, max: 100, divisions: 100, label: '${_intensity.round()}%', onChanged: (v) => setState(() => _intensity = v)),
    const SizedBox(height: 8),
    Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      ChoiceChip(label: const Text('Subtil'), selected: (_intensity-30).abs()<5, onSelected: (_) => setState(() => _intensity=30)),
      ChoiceChip(label: const Text('Equilibre'), selected: (_intensity-55).abs()<5, onSelected: (_) => setState(() => _intensity=55)),
      ChoiceChip(label: const Text('Standard'), selected: (_intensity-75).abs()<5, onSelected: (_) => setState(() => _intensity=75)),
      ChoiceChip(label: const Text('Intense'), selected: (_intensity-100).abs()<5, onSelected: (_) => setState(() => _intensity=100)),
    ]),
    const SizedBox(height: 16),
    Wrap(spacing: 8, runSpacing: 8, children: [
      Chip(avatar: const Icon(Icons.exposure, size: 16), label: const Text('Expo'), visualDensity: VisualDensity.compact),
      Chip(avatar: const Icon(Icons.contrast, size: 16), label: const Text('Contraste'), visualDensity: VisualDensity.compact),
      Chip(avatar: const Icon(Icons.face, size: 16), label: const Text('Visage'), visualDensity: VisualDensity.compact),
      Chip(avatar: const Icon(Icons.grain, size: 16), label: const Text('Debruit'), visualDensity: VisualDensity.compact),
      Chip(avatar: const Icon(Icons.blur_on, size: 16), label: const Text('Nettete'), visualDensity: VisualDensity.compact),
    ]),
  ]));

  Widget _proPanel(ColorScheme cs) => SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(children: [
    _sl('Exposition', _exp, -100, 100, Icons.exposure, (v) => setState(() => _exp = v)),
    _sl('Contraste', _con, -100, 100, Icons.contrast, (v) => setState(() => _con = v)),
    _sl('Nettete', _shp, 0, 100, Icons.blur_on, (v) => setState(() => _shp = v)),
    _sl('Debruitage', _den, 0, 100, Icons.grain, (v) => setState(() => _den = v)),
    _sl('WB', _wb, -100, 100, Icons.wb_sunny, (v) => setState(() => _wb = v)),
    SwitchListTile(title: const Text('Lissage peau'), value: _fsm, onChanged: (v) => setState(() => _fsm = v)),
    SwitchListTile(title: const Text('Eclaircir yeux'), value: _eyb, onChanged: (v) => setState(() => _eyb = v)),
  ]));

  Widget _sl(String l, double v, double mn, double mx, IconData ic, ValueChanged<double> cb) =>
    Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Icon(ic, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8),
      SizedBox(width: 72, child: Text(l, style: const TextStyle(fontSize: 12))),
      Expanded(child: Slider(value: v, min: mn, max: mx, onChanged: cb)),
      SizedBox(width: 36, child: Text(v.round().toString(), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12))),
    ]));

  Future<void> _run() async {
    setState(() => _state = FixState.processing);
    try {
      _result = await _fixer.processImage(path: 'photo.jpg', intensity: _intensity / 100,
        pro: _pro ? ProSettings(exposure: _exp, contrast: _con, sharpness: _shp, denoise: _den, wb: _wb, faceSmooth: _fsm, eyeBright: _eyb) : null);
      setState(() => _state = FixState.done);
    } catch (e) { setState(() => _state = FixState.error); }
  }
  void _save() => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Photo corrigee sauvegardee !')));
  void _reset() => setState(() { _state = FixState.idle; _result = null; _intensity = 75; _exp=_con=_shp=_den=_wb=0; });
}
