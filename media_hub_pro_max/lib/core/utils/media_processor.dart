import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Media processing utilities.
/// Uses FFmpeg binary on device if available.
/// Falls back gracefully when FFmpeg is not found.
class MediaProcessor {
  static String? _ffmpegPath;
  static bool _checked = false;

  /// Check if FFmpeg binary is available on the device
  static Future<bool> isAvailable() async {
    if (_checked) return _ffmpegPath != null;
    _checked = true;

    const paths = [
      '/system/bin/ffmpeg',
      '/system/xbin/ffmpeg',
      '/data/local/bin/ffmpeg',
    ];

    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final result = await Process.run(path, ['-version']);
          if (result.exitCode == 0) {
            _ffmpegPath = path;
            return true;
          }
        }
      } catch (_) {}
    }

    try {
      final result = await Process.run('which', ['ffmpeg']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          _ffmpegPath = path;
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Execute FFmpeg with proper argument list (fixes BUG-06: no string split)
  static Future<bool> executeArgs(List<String> args) async {
    if (_ffmpegPath == null) {
      await isAvailable();
      if (_ffmpegPath == null) return false;
    }
    try {
      final fullArgs = ['-y', ...args];
      final result = await Process.run(_ffmpegPath!, fullArgs);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('FFmpeg error: $e');
      return false;
    }
  }

  /// Get audio duration in seconds
  static Future<double> getDuration(String filePath) async {
    if (await isAvailable()) {
      try {
        final result = await Process.run(_ffmpegPath!, ['-i', filePath, '-f', 'null', '-']);
        final output = result.stderr.toString();
        final durMatch = RegExp(r'Duration:\s*(\d+):(\d+):(\d+\.?\d*)').firstMatch(output);
        if (durMatch != null) {
          final h = double.tryParse(durMatch.group(1) ?? '0') ?? 0;
          final m = double.tryParse(durMatch.group(2) ?? '0') ?? 0;
          final s = double.tryParse(durMatch.group(3) ?? '0') ?? 0;
          return h * 3600 + m * 60 + s;
        }
      } catch (_) {}
    }
    // Fallback: estimate from file size
    try {
      final file = File(filePath);
      final size = await file.length();
      final ext = p.extension(filePath).toLowerCase();
      if (ext == '.mp3') return size / 40000;
      if (ext == '.flac') return size / 100000;
      if (ext == '.wav') return size / 176000;
      if (ext == '.aac' || ext == '.m4a') return size / 32000;
      return size / 16000;
    } catch (_) {
      return 0;
    }
  }

  /// Read metadata from filename
  static Future<AudioMetadata> readMetadata(String filePath) async {
    String title = '';
    String artist = '';

    if (await isAvailable()) {
      try {
        final result = await Process.run(_ffmpegPath!, ['-i', filePath, '-f', 'null', '-']);
        final output = result.stderr.toString();
        final titleMatch = RegExp(r'title\s*:\s*(.+)').firstMatch(output);
        if (titleMatch != null) title = titleMatch.group(1)!.trim();
        final artistMatch = RegExp(r'artist\s*:\s*(.+)').firstMatch(output);
        if (artistMatch != null) artist = artistMatch.group(1)!.trim();
        if (title.isEmpty) {
          final baseName = p.basenameWithoutExtension(filePath);
          if (baseName.contains(' - ')) {
            final parts = baseName.split(' - ');
            artist = parts[0].trim();
            title = parts.sublist(1).join(' - ').trim();
          } else {
            title = baseName.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
          }
        }
      } catch (_) {
        final baseName = p.basenameWithoutExtension(filePath);
        title = baseName.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      }
    } else {
      final baseName = p.basenameWithoutExtension(filePath);
      if (baseName.contains(' - ')) {
        final parts = baseName.split(' - ');
        artist = parts[0].trim();
        title = parts.sublist(1).join(' - ').trim();
      } else {
        title = baseName.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
      }
    }
    return AudioMetadata(filePath: filePath, title: title, artist: artist);
  }

  /// Cut audio — uses List<String> args (fixes BUG-06)
  static Future<String?> cutAudio({required String inputPath, required double startSec, required double endSec, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_cut');
    final duration = endSec - startSec;
    final success = await executeArgs(['-i', inputPath, '-ss', startSec.toString(), '-t', duration.toString(), '-c', 'copy', output]);
    if (success) return output;
    return null;
  }

  /// Convert audio
  static Future<String?> convertAudio({required String inputPath, required String format, String bitrate = '320k', String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_converted', ext: '.$format');
    List<String> codecArgs;
    switch (format.toLowerCase()) {
      case 'mp3': codecArgs = ['-c:a', 'libmp3lame', '-b:a', bitrate]; break;
      case 'aac': case 'm4a': codecArgs = ['-c:a', 'aac', '-b:a', bitrate]; break;
      case 'flac': codecArgs = ['-c:a', 'flac']; break;
      case 'wav': codecArgs = ['-c:a', 'pcm_s16le']; break;
      case 'ogg': codecArgs = ['-c:a', 'libvorbis', '-b:a', bitrate]; break;
      default: codecArgs = ['-c:a', 'libmp3lame', '-b:a', bitrate];
    }
    final success = await executeArgs(['-i', inputPath, ...codecArgs, output]);
    return success ? output : null;
  }

  /// Extract audio from video
  static Future<String?> extractAudio({required String inputPath, String format = 'mp3', String bitrate = '320k', String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_audio', ext: '.$format');
    List<String> codecArgs;
    switch (format.toLowerCase()) {
      case 'mp3': codecArgs = ['-vn', '-c:a', 'libmp3lame', '-b:a', bitrate]; break;
      case 'aac': case 'm4a': codecArgs = ['-vn', '-c:a', 'aac', '-b:a', bitrate]; break;
      case 'flac': codecArgs = ['-vn', '-c:a', 'flac']; break;
      case 'wav': codecArgs = ['-vn', '-c:a', 'pcm_s16le']; break;
      default: codecArgs = ['-vn', '-c:a', 'libmp3lame', '-b:a', bitrate];
    }
    final success = await executeArgs(['-i', inputPath, ...codecArgs, output]);
    return success ? output : null;
  }

  /// Change speed
  static Future<String?> changeSpeed({required String inputPath, required double speed, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_speed');
    final success = await executeArgs(['-i', inputPath, '-filter:a', 'atempo=$speed', '-c:a', 'libmp3lame', '-b:a', '320k', output]);
    return success ? output : null;
  }

  /// Merge audio files
  static Future<String?> mergeAudio({required List<String> inputPaths, String? outputPath}) async {
    if (inputPaths.isEmpty) return null;
    if (inputPaths.length == 1) return inputPaths.first;
    final tempDir = await getTemporaryDirectory();
    final listFile = p.join(tempDir.path, 'concat_${DateTime.now().millisecondsSinceEpoch}.txt');
    await File(listFile).writeAsString(inputPaths.map((fp) => "file '$fp'").join('\n'));
    final output = outputPath ?? await _getOutputPath(inputPaths.first, '_merged');
    final success = await executeArgs(['-f', 'concat', '-safe', '0', '-i', listFile, '-c', 'copy', output]);
    try { await File(listFile).delete(); } catch (_) {}
    return success ? output : null;
  }

  /// Write metadata
  static Future<String?> writeMetadata({required String inputPath, required AudioMetadata metadata, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_tagged');
    final args = <String>['-i', inputPath];
    if (metadata.title.isNotEmpty) args.addAll(['-metadata', 'title=${metadata.title}']);
    if (metadata.artist.isNotEmpty) args.addAll(['-metadata', 'artist=${metadata.artist}']);
    if (metadata.album.isNotEmpty) args.addAll(['-metadata', 'album=${metadata.album}']);
    if (metadata.year.isNotEmpty) args.addAll(['-metadata', 'date=${metadata.year}']);
    if (metadata.genre.isNotEmpty) args.addAll(['-metadata', 'genre=${metadata.genre}']);
    if (metadata.comment.isNotEmpty) args.addAll(['-metadata', 'comment=${metadata.comment}']);
    args.addAll(['-c', 'copy', output]);
    final success = await executeArgs(args);
    return success ? output : null;
  }

  /// Strip metadata
  static Future<String?> stripMetadata({required String inputPath, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_clean');
    final success = await executeArgs(['-i', inputPath, '-map_metadata', '-1', '-c', 'copy', output]);
    return success ? output : null;
  }

  /// Amplify
  static Future<String?> amplify({required String inputPath, required double factor, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_amp');
    final success = await executeArgs(['-i', inputPath, '-filter:a', 'volume=$factor', '-c:a', 'libmp3lame', '-b:a', '320k', output]);
    return success ? output : null;
  }

  /// Normalize
  static Future<String?> normalize({required String inputPath, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_normalized');
    final success = await executeArgs(['-i', inputPath, '-filter:a', 'loudnorm', '-c:a', 'libmp3lame', '-b:a', '320k', output]);
    return success ? output : null;
  }

  /// Change channels
  static Future<String?> changeChannels({required String inputPath, required int channels, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_ch');
    final success = await executeArgs(['-i', inputPath, '-ac', channels.toString(), '-c:a', 'libmp3lame', '-b:a', '320k', output]);
    return success ? output : null;
  }

  /// Create ringtone
  static Future<String?> createRingtone({required String inputPath, double startSec = 0, double durationSec = 30, String? outputPath}) async {
    final tempDir = await getTemporaryDirectory();
    final output = outputPath ?? p.join(tempDir.path, 'ringtone_${DateTime.now().millisecondsSinceEpoch}.mp3');
    final success = await executeArgs(['-i', inputPath, '-ss', startSec.toString(), '-t', durationSec.toString(), '-c:a', 'libmp3lame', '-b:a', '192k', output]);
    return success ? output : null;
  }

  /// Get output path — uses Download directory on Android (fixes BUG-08)
  static Future<String> _getOutputPath(String inputPath, String suffix, {String? ext}) async {
    final baseName = p.basenameWithoutExtension(inputPath);
    final extension = ext ?? p.extension(inputPath);

    // Try public Download directory first (visible to user)
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download/GiovaPlayer');
      if (!downloadDir.existsSync()) {
        try { downloadDir.createSync(recursive: true); } catch (_) {}
      }
      if (downloadDir.existsSync()) {
        return p.join(downloadDir.path, '$baseName$suffix$extension');
      }
    }

    // Fallback to app documents directory
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'GiovaPlayer', 'Output'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    return p.join(outDir.path, '$baseName$suffix$extension');
  }
}

class AudioMetadata {
  final String filePath;
  final String title;
  final String artist;
  final String album;
  final String year;
  final String genre;
  final String track;
  final String comment;
  final String duration;
  final String bitrate;

  AudioMetadata({
    required this.filePath,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.year = '',
    this.genre = '',
    this.track = '',
    this.comment = '',
    this.duration = '',
    this.bitrate = '',
  });

  String get displayName {
    if (title.isNotEmpty) return title;
    return p.basenameWithoutExtension(filePath).replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
  String get artistDisplay => artist.isNotEmpty ? artist : 'Artiste inconnu';
}
