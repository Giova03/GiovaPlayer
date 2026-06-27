import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Media processing utilities.
/// Uses FFmpeg binary on device if available (/system/bin/ffmpeg or /data/.../ffmpeg).
/// Falls back to file-copy based operations when FFmpeg is not found.
class MediaProcessor {
  static String? _ffmpegPath;
  static bool _checked = false;

  /// Check if FFmpeg binary is available on the device
  static Future<bool> isAvailable() async {
    if (_checked) return _ffmpegPath != null;
    _checked = true;

    // Check common FFmpeg binary locations on Android
    const paths = [
      '/system/bin/ffmpeg',
      '/system/xbin/ffmpeg',
      '/data/data/com.giovaplayer.giova_player/files/ffmpeg',
      '/data/local/bin/ffmpeg',
    ];

    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          final result = await Process.run(path, ['-version']);
          if (result.exitCode == 0) {
            _ffmpegPath = path;
            debugPrint('FFmpeg found at: $path');
            return true;
          }
        }
      } catch (_) {}
    }

    // Try 'which ffmpeg'
    try {
      final result = await Process.run('which', ['ffmpeg']);
      if (result.exitCode == 0) {
        final path = (result.stdout as String).trim();
        if (path.isNotEmpty) {
          _ffmpegPath = path;
          debugPrint('FFmpeg found via which: $path');
          return true;
        }
      }
    } catch (_) {}

    debugPrint('FFmpeg not found on device');
    return false;
  }

  /// Execute an FFmpeg command
  static Future<bool> execute(String command) async {
    if (_ffmpegPath == null) {
      await isAvailable();
      if (_ffmpegPath == null) return false;
    }

    try {
      final args = command.split(' ');
      // Remove the 'ffmpeg' part if included
      final cleanArgs = args.where((a) => a != 'ffmpeg' && a.isNotEmpty).toList();
      final result = await Process.run(_ffmpegPath!, cleanArgs);
      return result.exitCode == 0;
    } catch (e) {
      debugPrint('FFmpeg execute error: $e');
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
        // If no tags found, parse from filename
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

  /// Cut audio
  static Future<String?> cutAudio({
    required String inputPath,
    required double startSec,
    required double endSec,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_cut');
    final duration = endSec - startSec;
    final success = await execute('-y -i "$inputPath" -ss $startSec -t $duration -c copy "$output"');
    if (success) return output;

    // Fallback: copy entire file if ffmpeg not available
    try {
      await File(inputPath).copy(output);
      return output;
    } catch (e) {
      return null;
    }
  }

  /// Convert audio to a different format
  static Future<String?> convertAudio({
    required String inputPath,
    required String format,
    String bitrate = '320k',
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_converted', ext: '.$format');
    String codecFlag;
    switch (format.toLowerCase()) {
      case 'mp3': codecFlag = '-c:a libmp3lame -b:a $bitrate'; break;
      case 'aac': case 'm4a': codecFlag = '-c:a aac -b:a $bitrate'; break;
      case 'flac': codecFlag = '-c:a flac'; break;
      case 'wav': codecFlag = '-c:a pcm_s16le'; break;
      case 'ogg': codecFlag = '-c:a libvorbis -b:a $bitrate'; break;
      default: codecFlag = '-c:a libmp3lame -b:a $bitrate';
    }
    final success = await execute('-y -i "$inputPath" $codecFlag "$output"');
    return success ? output : null;
  }

  /// Extract audio from video
  static Future<String?> extractAudio({
    required String inputPath,
    String format = 'mp3',
    String bitrate = '320k',
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_audio', ext: '.$format');
    String codecFlag;
    switch (format.toLowerCase()) {
      case 'mp3': codecFlag = '-vn -c:a libmp3lame -b:a $bitrate'; break;
      case 'aac': case 'm4a': codecFlag = '-vn -c:a aac -b:a $bitrate'; break;
      case 'flac': codecFlag = '-vn -c:a flac'; break;
      case 'wav': codecFlag = '-vn -c:a pcm_s16le'; break;
      default: codecFlag = '-vn -c:a libmp3lame -b:a $bitrate';
    }
    final success = await execute('-y -i "$inputPath" $codecFlag "$output"');
    return success ? output : null;
  }

  /// Change audio speed
  static Future<String?> changeSpeed({required String inputPath, required double speed, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_speed');
    final success = await execute('-y -i "$inputPath" -filter:a "atempo=$speed" -c:a libmp3lame -b:a 320k "$output"');
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
    final success = await execute('-y -f concat -safe 0 -i "$listFile" -c copy "$output"');
    try { await File(listFile).delete(); } catch (_) {}
    return success ? output : null;
  }

  /// Write metadata
  static Future<String?> writeMetadata({required String inputPath, required AudioMetadata metadata, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_tagged');
    final args = StringBuffer('-y -i "$inputPath"');
    if (metadata.title.isNotEmpty) args.write(' -metadata title="${metadata.title}"');
    if (metadata.artist.isNotEmpty) args.write(' -metadata artist="${metadata.artist}"');
    if (metadata.album.isNotEmpty) args.write(' -metadata album="${metadata.album}"');
    if (metadata.year.isNotEmpty) args.write(' -metadata date="${metadata.year}"');
    if (metadata.genre.isNotEmpty) args.write(' -metadata genre="${metadata.genre}"');
    if (metadata.comment.isNotEmpty) args.write(' -metadata comment="${metadata.comment}"');
    args.write(' -c copy "$output"');
    final success = await execute(args.toString());
    return success ? output : null;
  }

  /// Strip metadata
  static Future<String?> stripMetadata({required String inputPath, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_clean');
    final success = await execute('-y -i "$inputPath" -map_metadata -1 -c copy "$output"');
    return success ? output : null;
  }

  /// Amplify
  static Future<String?> amplify({required String inputPath, required double factor, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_amp');
    final success = await execute('-y -i "$inputPath" -filter:a "volume=$factor" -c:a libmp3lame -b:a 320k "$output"');
    return success ? output : null;
  }

  /// Normalize
  static Future<String?> normalize({required String inputPath, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_normalized');
    final success = await execute('-y -i "$inputPath" -filter:a "loudnorm" -c:a libmp3lame -b:a 320k "$output"');
    return success ? output : null;
  }

  /// Change channels
  static Future<String?> changeChannels({required String inputPath, required int channels, String? outputPath}) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_ch');
    final success = await execute('-y -i "$inputPath" -ac $channels -c:a libmp3lame -b:a 320k "$output"');
    return success ? output : null;
  }

  /// Create ringtone
  static Future<String?> createRingtone({required String inputPath, double startSec = 0, double durationSec = 30, String? outputPath}) async {
    final tempDir = await getTemporaryDirectory();
    final output = outputPath ?? p.join(tempDir.path, 'ringtone_${DateTime.now().millisecondsSinceEpoch}.mp3');
    final success = await execute('-y -i "$inputPath" -ss $startSec -t $durationSec -c:a libmp3lame -b:a 192k "$output"');
    return success ? output : null;
  }

  static Future<String> _getOutputPath(String inputPath, String suffix, {String? ext}) async {
    final dir = await getExternalStorageDirectory();
    final outDir = Directory('${dir?.parent.path}/GiovaPlayer/Output');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final baseName = p.basenameWithoutExtension(inputPath);
    final extension = ext ?? p.extension(inputPath);
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
  String get albumDisplay => album.isNotEmpty ? album : 'Album inconnu';
}
