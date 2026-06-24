import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// AES-256-CBC encryption/decryption for vault photos and files.
/// The encryption key is stored securely in FlutterSecureStorage.
class VaultCrypto {
  static const _storage = FlutterSecureStorage();
  static const _keyId = 'vault_aes256_key';
  static String? _cachedKey;

  /// Get or generate the AES-256 encryption key
  static Future<String> _getKey() async {
    if (_cachedKey != null && _cachedKey!.length == 32) return _cachedKey!;
    var key = await _storage.read(key: _keyId);
    if (key == null || key.length != 32) {
      // Generate a new 256-bit key (32 bytes = 32 UTF-8 chars)
      final randomKey = Key.fromSecureRandom(32);
      key = randomKey.base64.substring(0, 32);
      await _storage.write(key: _keyId, value: key);
    }
    _cachedKey = key;
    return key;
  }

  /// Encrypt bytes using AES-256-CBC
  static Future<Uint8List> encryptBytes(Uint8List data) async {
    final keyStr = await _getKey();
    final key = Key.fromUtf8(keyStr);
    final iv = IV.fromSecureRandom(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final encrypted = encrypter.encryptBytes(data, iv: iv);
    // Prepend IV to encrypted data: [16 bytes IV][encrypted data]
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setRange(0, 16, iv.bytes);
    result.setRange(16, result.length, encrypted.bytes);
    return result;
  }

  /// Decrypt bytes using AES-256-CBC
  static Future<Uint8List> decryptBytes(Uint8List data) async {
    if (data.length < 16) throw Exception('Données invalides: trop courtes');
    final keyStr = await _getKey();
    final key = Key.fromUtf8(keyStr);
    // Extract IV from first 16 bytes
    final ivBytes = data.sublist(0, 16);
    final iv = IV(ivBytes);
    final encryptedBytes = data.sublist(16);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
    final encrypted = Encrypted(encryptedBytes);
    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  /// Encrypt a file and save to vault directory
  /// Returns the path of the encrypted file
  static Future<String> encryptFile(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) throw Exception('Fichier source introuvable');

    final bytes = await sourceFile.readAsBytes();
    final encrypted = await encryptBytes(Uint8List.fromList(bytes));

    // Create vault directory
    final vaultDir = await _getVaultDir();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}.enc';
    final destPath = p.join(vaultDir.path, fileName);

    await File(destPath).writeAsBytes(encrypted);
    return destPath;
  }

  /// Decrypt a vault file and return the decrypted bytes
  static Future<Uint8List> decryptFile(String encryptedPath) async {
    final file = File(encryptedPath);
    if (!await file.exists()) throw Exception('Fichier chiffré introuvable');

    final encryptedBytes = await file.readAsBytes();
    return decryptBytes(Uint8List.fromList(encryptedBytes));
  }

  /// Decrypt a vault file and save to a temp directory for viewing
  /// Returns the path of the decrypted temp file
  static Future<String> decryptToTemp(String encryptedPath, String originalName) async {
    final decrypted = await decryptFile(encryptedPath);
    final tempDir = await getTemporaryDirectory();
    final tempPath = p.join(tempDir.path, originalName);
    await File(tempPath).writeAsBytes(decrypted);
    return tempPath;
  }

  /// Get the vault directory, creating it if needed
  static Future<Directory> _getVaultDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final vaultDir = Directory(p.join(appDir.path, 'vault'));
    if (!await vaultDir.exists()) {
      await vaultDir.create(recursive: true);
    }
    // Create .nomedia to hide from gallery
    final nomedia = File(p.join(vaultDir.path, '.nomedia'));
    if (!await nomedia.exists()) {
      await nomedia.create();
    }
    return vaultDir;
  }

  /// Delete an encrypted file from the vault
  static Future<bool> deleteEncryptedFile(String encryptedPath) async {
    try {
      final file = File(encryptedPath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Wipe all vault encrypted files
  static Future<void> wipeAll() async {
    try {
      final vaultDir = await _getVaultDir();
      if (await vaultDir.exists()) {
        await vaultDir.delete(recursive: true);
      }
      await _storage.delete(key: _keyId);
      _cachedKey = null;
    } catch (_) {}
  }

  /// Calculate file size of encrypted file
  static Future<int> fileSize(String path) async {
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }
}
