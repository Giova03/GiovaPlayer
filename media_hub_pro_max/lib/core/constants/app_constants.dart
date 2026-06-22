/// ─── CONSTANTES GLOBALES MEDIA HUB PRO MAX ───

/// Nom de l'application
const String appName = 'Media Hub Pro MAX';
const String appVersion = '1.0.0';

/// ─── AUDIO ───
const int equalizerBands = 32;
const int crossfadeDefaultSec = 3;
const int crossfadeMaxSec = 12;
const double replayGainTargetDb = -14.0;

/// Formats audio supportés
const Set<String> audioExtensions = {
  'flac', 'wav', 'dsf', 'dff', 'mp3', 'aac', 'ogg',
  'opus', 'wma', 'alac', 'm4a', 'ape',
};

/// ─── VIDÉO ───
const Set<String> videoExtensions = {
  'mp4', 'mkv', 'avi', 'mov', 'wmv', 'flv', 'webm',
  'm4v', '3gp', 'ts', 'mts', 'm2ts',
};

/// Résolutions supportées
const Map<String, int> videoResolutions = {
  '4K': 2160,
  '1440p': 1440,
  '1080p': 1080,
  '720p': 720,
  '480p': 480,
  '360p': 360,
};

/// ─── IMAGE ───
const Set<String> imageExtensions = {
  'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp',
  'tiff', 'tif', 'heic', 'heif', 'raw', 'dng',
};

/// ─── COFFRE-FORT ───
const int vaultPinLength = 4;
const int maxFailedAttempts = 3;
const int aesKeySizeBits = 256;

/// ─── TÉLÉCHARGEMENT ───
const int maxConcurrentDownloads = 3;
const int downloadSpeedLimitKbps = 0; // 0 = illimité
const Set<String> supportedPlatforms = {
  'youtube.com', 'youtu.be', 'tiktok.com', 'instagram.com',
  'facebook.com', 'fb.watch', 'twitter.com', 'x.com',
};

/// ─── IA PHOTO ───
const int iaFixTargetMs = 2000; // Objectif 2 secondes
const double defaultIaIntensity = 0.75;
const int maxImageDimension = 4096; // pixels

/// ─── STOCKAGE ───
const int maxAppSizeMb = 90; // APK split < 90MB
const String cacheFolderName = 'media_hub_cache';
const String vaultFolderName = 'media_hub_vault';
const String downloadFolderName = 'MediaHub';

/// ─── THÈMES ───
const int totalCustomThemes = 20;
const int defaultThemeIndex = 0;

/// ─── DÉBOUNCE ───
const int searchDebounceMs = 300;
const int saveDebounceMs = 500;
