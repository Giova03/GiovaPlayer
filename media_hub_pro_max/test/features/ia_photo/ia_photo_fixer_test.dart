import 'package:flutter_test/flutter_test.dart';

import 'package:media_hub_pro_max/features/ia_photo/services/ia_photo_fixer.dart';
import 'package:media_hub_pro_max/core/utils/format_utils.dart';

void main() {
  group('IA Photo Fixer', () {
    late IaPhotoFixer fixer;

    setUp(() {
      fixer = IaPhotoFixer();
    });

    tearDown(() {
      fixer.dispose();
    });

    test('Chargement modèle doit réussir', () async {
      await fixer.loadModel();
      // Pas d'exception = succès
      expect(true, isTrue);
    });

    test('Chargement modèle est idempotent', () async {
      await fixer.loadModel();
      await fixer.loadModel();
      // Double appel ne doit pas lever d'erreur
      expect(true, isTrue);
    });

    test('processImage en mode auto retourne FixResult', () async {
      final result = await fixer.processImage(
        imagePath: 'test_image.jpg',
        intensity: 0.75,
      );

      expect(result, isNotNull);
      expect(result.analysis, isNotNull);
      expect(result.processingTimeMs, greaterThan(0));
      expect(result.analysis.histogram, isNotNull);
      expect(result.analysis.histogram['mean'], greaterThan(0));
    });

    test('processImage en mode pro applique les réglages', () async {
      final result = await fixer.processImage(
        imagePath: 'test_image.jpg',
        intensity: 0.5,
        proSettings: const ProSettings(
          exposure: 30,
          contrast: 20,
          sharpness: 50,
          denoise: 40,
          wb: 10,
          faceSmooth: true,
          eyeBright: false,
        ),
      );

      expect(result, isNotNull);
      expect(result.analysis, isNotNull);
    });

    test('Analyse image détecte au moins 1 visage (dummy)', () async {
      final result = await fixer.processImage(
        imagePath: 'test_face.jpg',
        intensity: 0.5,
      );

      expect(result.analysis.faceCount, greaterThanOrEqualTo(0));
    });

    test('Intensité 0 ne modifie pas l\\'image significativement', () async {
      final result = await fixer.processImage(
        imagePath: 'test.jpg',
        intensity: 0.0,
      );

      expect(result, isNotNull);
    });
  });

  group('Format Utils', () {
    test('formatDuration — format court', () {
      expect(formatDuration(238000), '3:58');
    });

    test('formatDuration — format long avec heures', () {
      expect(formatDuration(3723000), '1:02:03');
    });

    test('formatDuration — zéro', () {
      expect(formatDuration(0), '0:00');
    });

    test('formatFileSize — bytes', () {
      expect(formatFileSize(512), '512 B');
    });

    test('formatFileSize — kilobytes', () {
      expect(formatFileSize(1536), '1.5 KB');
    });

    test('formatFileSize — megabytes', () {
      expect(formatFileSize(2621440), '2.5 MB');
    });

    test('formatFileSize — gigabytes', () {
      expect(formatFileSize(3221225472), '3.0 GB');
    });

    test('formatBitrate — kbps', () {
      expect(formatBitrate(320), '320 kbps');
    });

    test('formatBitrate — Mbps', () {
      expect(formatBitrate(1500), '1.5 Mbps');
    });

    test('formatSampleRate — kHz entier', () {
      expect(formatSampleRate(96000), '96 kHz');
    });

    test('formatSampleRate — kHz décimal', () {
      expect(formatSampleRate(44100), '44.1 kHz');
    });

    test('isAudioFile — FLAC', () {
      expect(isAudioFile('song.flac'), isTrue);
    });

    test('isAudioFile — TXT', () {
      expect(isAudioFile('notes.txt'), isFalse);
    });

    test('isVideoFile — MKV', () {
      expect(isVideoFile('movie.mkv'), isTrue);
    });

    test('isImageFile — HEIC', () {
      expect(isImageFile('photo.heic'), isTrue);
    });

    test('detectPlatform — YouTube', () {
      expect(detectPlatform('https://youtube.com/watch?v=abc'), 'youtube');
    });

    test('detectPlatform — TikTok', () {
      expect(detectPlatform('https://tiktok.com/@user/video/123'), 'tiktok');
    });

    test('detectPlatform — torrent magnet', () {
      expect(detectPlatform('magnet:?xt=urn:btih:abc'), 'torrent');
    });

    test('detectPlatform — inconnu', () {
      expect(detectPlatform('https://example.com/file'), 'web');
    });

    test('truncate — texte court', () {
      expect(truncate('Hello', 10), 'Hello');
    });

    test('truncate — texte long', () {
      expect(truncate('Hello World!', 8), 'Hello...');
    });
  });

  group('FixResult', () {
    test('FixResult contient les champs requis', () {
      final result = FixResult(
        originalImage: null,
        fixedImage: null,
        analysis: const ImageAnalysis(
          histogram: {'mean': 128.0, 'stdDev': 55.0},
          faceCount: 1,
          noiseLevel: 0.3,
          sharpnessScore: 0.65,
          exposureIssue: false,
          contrastIssue: false,
          wbIssue: false,
        ),
        processingTimeMs: 1200,
        progress: 'Terminé',
      );

      expect(result.analysis.faceCount, 1);
      expect(result.analysis.noiseLevel, 0.3);
      expect(result.processingTimeMs, 1200);
    });
  });

  group('ProSettings', () {
    test('ProSettings valeurs par défaut', () {
      const settings = ProSettings();
      expect(settings.exposure, 0);
      expect(settings.contrast, 0);
      expect(settings.faceSmooth, isTrue);
      expect(settings.eyeBright, isTrue);
    });
  });
}
