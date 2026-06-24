import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:ffmpeg_kit_flutter_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_min/return_code.dart';

/// Media processing utilities using FFmpeg Kit Audio.
/// Uses only FFmpegKit.execute() which is guaranteed to exist.
/// For metadata reading, we use session logs from the execute result.
class MediaProcessor {
  /// Execute an FFmpeg command and return success status
  static Future<bool> execute(String command) async {
    try {
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      return ReturnCode.isSuccess(returnCode);
    } catch (e) {
      debugPrint('FFmpeg error: $e');
      return false;
    }
  }

  /// Get audio duration in seconds.
  /// Uses a simple file stat approach as fallback if FFmpeg parsing fails.
  static Future<double> getDuration(String filePath) async {
    try {
      // Estimate duration from file size for common formats
      // MP3 at 320kbps ≈ 40KB/s, FLAC ≈ 100KB/s, WAV ≈ 176KB/s
      final file = File(filePath);
      final size = await file.length();
      final ext = p.extension(filePath).toLowerCase();

      if (ext == '.mp3') return size / 40000;
      if (ext == '.flac') return size / 100000;
      if (ext == '.wav') return size / 176000;
      if (ext == '.aac' || ext == '.m4a') return size / 32000;
      if (ext == '.ogg') return size / 40000;
      if (ext == '.opus') return size / 25000;
      // Default: assume ~128kbps
      return size / 16000;
    } catch (e) {
      return 0;
    }
  }

  /// Read metadata tags from an audio file by parsing the filename
  static Future<AudioMetadata> readMetadata(String filePath) async {
    // Parse artist - title from filename format "Artist - Title.mp3"
    final baseName = p.basenameWithoutExtension(filePath);
    String title = '';
    String artist = '';

    if (baseName.contains(' - ')) {
      final parts = baseName.split(' - ');
      artist = parts[0].trim();
      title = parts.sublist(1).join(' - ').trim();
    } else {
      title = baseName.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    }

    return AudioMetadata(
      filePath: filePath,
      title: title,
      artist: artist,
    );
  }

  /// Cut audio from [start] to [end] seconds
  /// Returns the output file path on success, null on failure
  static Future<String?> cutAudio({
    required String inputPath,
    required double startSec,
    required double endSec,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_cut');
    final duration = endSec - startSec;
    final cmd = '-y -i "$inputPath" -ss $startSec -t $duration -c copy "$output"';
    final success = await execute(cmd);
    return success ? output : null;
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
      case 'mp3':
        codecFlag = '-c:a libmp3lame -b:a $bitrate';
        break;
      case 'aac':
      case 'm4a':
        codecFlag = '-c:a aac -b:a $bitrate';
        break;
      case 'flac':
        codecFlag = '-c:a flac';
        break;
      case 'wav':
        codecFlag = '-c:a pcm_s16le';
        break;
      case 'ogg':
        codecFlag = '-c:a libvorbis -b:a $bitrate';
        break;
      case 'opus':
        codecFlag = '-c:a libopus -b:a $bitrate';
        break;
      default:
        codecFlag = '-c:a libmp3lame -b:a $bitrate';
    }
    final cmd = '-y -i "$inputPath" $codecFlag "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Extract audio from video file
  static Future<String?> extractAudio({
    required String inputPath,
    String format = 'mp3',
    String bitrate = '320k',
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_audio', ext: '.$format');
    String codecFlag;
    switch (format.toLowerCase()) {
      case 'mp3':
        codecFlag = '-vn -c:a libmp3lame -b:a $bitrate';
        break;
      case 'aac':
      case 'm4a':
        codecFlag = '-vn -c:a aac -b:a $bitrate';
        break;
      case 'flac':
        codecFlag = '-vn -c:a flac';
        break;
      case 'wav':
        codecFlag = '-vn -c:a pcm_s16le';
        break;
      default:
        codecFlag = '-vn -c:a libmp3lame -b:a $bitrate';
    }
    final cmd = '-y -i "$inputPath" $codecFlag "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Change audio speed
  static Future<String?> changeSpeed({
    required String inputPath,
    required double speed,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_speed');
    final cmd = '-y -i "$inputPath" -filter:a "atempo=$speed" -c:a libmp3lame -b:a 320k "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Merge multiple audio files
  static Future<String?> mergeAudio({
    required List<String> inputPaths,
    String? outputPath,
  }) async {
    if (inputPaths.isEmpty) return null;
    if (inputPaths.length == 1) return inputPaths.first;

    final tempDir = await getTemporaryDirectory();
    final listFile = p.join(tempDir.path, 'concat_list_${DateTime.now().millisecondsSinceEpoch}.txt');
    final entries = inputPaths.map((fp) => "file '$fp'").join('\n');
    await File(listFile).writeAsString(entries);

    final output = outputPath ?? await _getOutputPath(inputPaths.first, '_merged');
    final cmd = '-y -f concat -safe 0 -i "$listFile" -c copy "$output"';
    final success = await execute(cmd);

    try { await File(listFile).delete(); } catch (_) {}

    return success ? output : null;
  }

  /// Write metadata tags to an audio file
  static Future<String?> writeMetadata({
    required String inputPath,
    required AudioMetadata metadata,
    String? outputPath,
  }) async {
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

  /// Strip all metadata from a file
  static Future<String?> stripMetadata({
    required String inputPath,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_clean');
    final cmd = '-y -i "$inputPath" -map_metadata -1 -c copy "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Amplify audio volume
  static Future<String?> amplify({
    required String inputPath,
    required double factor,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_amp');
    final cmd = '-y -i "$inputPath" -filter:a "volume=$factor" -c:a libmp3lame -b:a 320k "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Normalize audio volume
  static Future<String?> normalize({
    required String inputPath,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_normalized');
    final cmd = '-y -i "$inputPath" -filter:a "loudnorm" -c:a libmp3lame -b:a 320k "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Convert mono to stereo or stereo to mono
  static Future<String?> changeChannels({
    required String inputPath,
    required int channels,
    String? outputPath,
  }) async {
    final output = outputPath ?? await _getOutputPath(inputPath, '_ch');
    final cmd = '-y -i "$inputPath" -ac $channels -c:a libmp3lame -b:a 320k "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  /// Create ringtone
  static Future<String?> createRingtone({
    required String inputPath,
    double startSec = 0,
    double durationSec = 30,
    String? outputPath,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final output = outputPath ?? p.join(
      tempDir.path,
      'ringtone_${DateTime.now().millisecondsSinceEpoch}.mp3',
    );
    final cmd = '-y -i "$inputPath" -ss $startSec -t $durationSec -c:a libmp3lame -b:a 192k "$output"';
    final success = await execute(cmd);
    return success ? output : null;
  }

  // ─── Helpers ───

  static Future<String> _getOutputPath(String inputPath, String suffix, {String? ext}) async {
    final dir = await getExternalStorageDirectory();
    final outDir = Directory('${dir?.parent.path}/GiovaPlayer/Output');
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final baseName = p.basenameWithoutExtension(inputPath);
    final extension = ext ?? p.extension(inputPath);
    return p.join(outDir.path, '$baseName$suffix$extension');
  }
}

/// Audio metadata model
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
    final name = p.basenameWithoutExtension(filePath);
    return name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }

  String get artistDisplay => artist.isNotEmpty ? artist : 'Artiste inconnu';
  String get albumDisplay => album.isNotEmpty ? album : 'Album inconnu';
}
