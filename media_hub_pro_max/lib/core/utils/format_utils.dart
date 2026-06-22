/// ─── UTILITAIRES PARTAGÉS ───

/// Formate une durée en millisecondes en string lisible
/// Ex: 238000 → "3:58"
String formatDuration(int ms) {
  final totalSeconds = ms ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Formate une taille en bytes en string lisible
/// Ex: 2621440 → "2.5 MB"
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  return '${(bytes / 1073741824).toStringAsFixed(1)} GB';
}

/// Formate un bitrate en kbps
/// Ex: 320 → "320 kbps", 1411 → "1411 kbps"
String formatBitrate(int kbps) {
  if (kbps >= 1000) {
    return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
  }
  return '$kbps kbps';
}

/// Formate un sample rate en Hz
/// Ex: 44100 → "44.1 kHz", 96000 → "96 kHz"
String formatSampleRate(int hz) {
  if (hz >= 1000) {
    final khz = hz / 1000;
    return '${khz == khz.roundToDouble() ? khz.round() : khz.toStringAsFixed(1)} kHz';
  }
  return '$hz Hz';
}

/// Formate une vitesse de téléchargement
/// Ex: 12582912 → "12.0 MB/s"
String formatSpeed(int bytesPerSec) {
  if (bytesPerSec < 1024) return '$bytesPerSec B/s';
  if (bytesPerSec < 1048576) return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
  return '${(bytesPerSec / 1048576).toStringAsFixed(1)} MB/s';
}

/// Extrait l'extension d'un nom de fichier
/// Ex: "song.flac" → "flac"
String getExtension(String filename) {
  final dot = filename.lastIndexOf('.');
  if (dot == -1) return '';
  return filename.substring(dot + 1).toLowerCase();
}

/// Vérifie si un fichier est un audio supporté
bool isAudioFile(String path) {
  final ext = getExtension(path);
  return {'flac', 'wav', 'dsf', 'dff', 'mp3', 'aac', 'ogg',
          'opus', 'wma', 'alac', 'm4a', 'ape'}.contains(ext);
}

/// Vérifie si un fichier est une vidéo supportée
bool isVideoFile(String path) {
  final ext = getExtension(path);
  return {'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv',
          'webm', 'm4v', '3gp', 'ts'}.contains(ext);
}

/// Vérifie si un fichier est une image supportée
bool isImageFile(String path) {
  final ext = getExtension(path);
  return {'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
          'tiff', 'heic', 'heif', 'raw', 'dng'}.contains(ext);
}

/// Détecte la plateforme depuis une URL
/// Retourne le nom de la plateforme ou 'unknown'
String detectPlatform(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) return 'youtube';
  if (lower.contains('tiktok.com')) return 'tiktok';
  if (lower.contains('instagram.com')) return 'instagram';
  if (lower.contains('facebook.com') || lower.contains('fb.watch')) return 'facebook';
  if (lower.contains('twitter.com') || lower.contains('x.com')) return 'twitter';
  if (lower.startsWith('magnet:') || lower.endsWith('.torrent')) return 'torrent';
  return 'web';
}

/// Tronque un texte avec ellipsis
String truncate(String text, int maxLength) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength - 3)}...';
}
