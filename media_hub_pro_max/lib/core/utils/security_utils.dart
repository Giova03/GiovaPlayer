import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Security utilities: hashing, password strength, file encryption.
class SecurityUtils {
  /// Compute MD5 hash of a file
  static Future<String> md5HashFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return md5.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  /// Compute SHA-256 hash of a file
  static Future<String> sha256HashFile(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();
      return sha256.convert(bytes).toString();
    } catch (_) {
      return '';
    }
  }

  /// Compute MD5 hash of a string
  static String md5HashString(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }

  /// Compute SHA-256 hash of a string
  static String sha256HashString(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Evaluate password strength (0-100 score + label)
  static PasswordStrength evaluatePassword(String password) {
    int score = 0;
    final issues = <String>[];

    if (password.length < 8) { issues.add('Trop court (min 8 caractères)'); }
    else if (password.length >= 12) score += 25;
    else if (password.length >= 8) score += 15;

    if (password.contains(RegExp(r'[a-z]'))) score += 10;
    else issues.add('Aucune minuscule');

    if (password.contains(RegExp(r'[A-Z]'))) score += 15;
    else issues.add('Aucune majuscule');

    if (password.contains(RegExp(r'[0-9]'))) score += 15;
    else issues.add('Aucun chiffre');

    if (password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{}|;:,.<>?]'))) score += 20;
    else issues.add('Aucun symbole');

    // Bonus for variety
    final uniqueChars = password.split('').toSet().length;
    if (uniqueChars >= password.length * 0.7) score += 15;

    // Penalties
    if (password.toLowerCase() == password && password.toUpperCase() == password) score -= 10;
    if (RegExp(r'^\d+$').hasMatch(password)) { score -= 20; issues.add('Mot de passe uniquement numérique'); }
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) { score -= 10; issues.add('Caractères répétés'); }

    score = score.clamp(0, 100);

    String label;
    Color color;
    if (score < 30) { label = 'Très faible'; color = const Color(0xFFE53935); }
    else if (score < 50) { label = 'Faible'; color = const Color(0xFFFB8C00); }
    else if (score < 70) { label = 'Moyen'; color = const Color(0xFFFDD835); }
    else if (score < 90) { label = 'Fort'; color = const Color(0xFF43A047); }
    else { label = 'Excellent'; color = const Color(0xFF2E7D32); }

    return PasswordStrength(score: score, label: label, color: color, issues: issues);
  }

  /// Generate a cryptographic key (hex string)
  static String generateKey({int bytes = 32}) {
    final random = Random.secure();
    final keyBytes = Uint8List(bytes);
    for (int i = 0; i < bytes; i++) {
      keyBytes[i] = random.nextInt(256);
    }
    return keyBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Generate an RSA-like key pair (simulated — returns two hex strings)
  static KeyPair generateKeyPair() {
    return KeyPair(
      privateKey: generateKey(bytes: 32),
      publicKey: generateKey(bytes: 16),
    );
  }

  /// Simple XOR-based file obfuscation (not real encryption — for demo purposes)
  /// For real file encryption, use VaultCrypto (AES-256)
  static Future<String> obfuscateFile(String inputPath, String key) async {
    try {
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      final keyBytes = utf8.encode(key);
      final output = Uint8List(bytes.length);
      for (int i = 0; i < bytes.length; i++) {
        output[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
      }
      final outputPath = inputPath + '.enc';
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } catch (_) {
      return '';
    }
  }

  /// Reverse the obfuscation
  static Future<String> deobfuscateFile(String inputPath, String key) async {
    try {
      final file = File(inputPath);
      final bytes = await file.readAsBytes();
      final keyBytes = utf8.encode(key);
      final output = Uint8List(bytes.length);
      for (int i = 0; i < bytes.length; i++) {
        output[i] = bytes[i] ^ keyBytes[i % keyBytes.length];
      }
      final outputPath = inputPath.replaceAll('.enc', '.dec');
      await File(outputPath).writeAsBytes(output);
      return outputPath;
    } catch (_) {
      return '';
    }
  }

  /// Compare two file hashes
  static bool compareHashes(String hash1, String hash2) {
    return hash1.toLowerCase() == hash2.toLowerCase();
  }
}

class PasswordStrength {
  final int score;
  final String label;
  final Color color;
  final List<String> issues;

  PasswordStrength({required this.score, required this.label, required this.color, required this.issues});
}

class KeyPair {
  final String privateKey;
  final String publicKey;
  KeyPair({required this.privateKey, required this.publicKey});
}

// Re-export Color from material for the PasswordStrength
import 'package:flutter/material.dart' show Color;
