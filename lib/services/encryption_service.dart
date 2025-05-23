import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

class EncryptionService {
  static String generateKey(String userId1, String userId2) {
    // Sort user IDs to ensure same key generation regardless of order
    final sortedIds = [userId1, userId2]..sort();
    final combinedString = '${sortedIds[0]}:${sortedIds[1]}';
    
    // Generate a consistent key using SHA-256
    final bytes = utf8.encode(combinedString);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 32); // Use first 32 chars for AES-256
  }

  static String encryptMessage(String message, String encryptionKey) {
    try {
      final key = encrypt.Key.fromUtf8(encryptionKey);
      final iv = encrypt.IV.fromLength(16); // AES uses 16 bytes IV
      final encrypter = encrypt.Encrypter(encrypt.AES(key));

      final encrypted = encrypter.encrypt(message, iv: iv);
      return '${encrypted.base64}:${iv.base64}'; // Store IV with encrypted message
    } catch (e) {
      print('Encryption error: $e');
      return message;
    }
  }

  static String decryptMessage(String encryptedMessage, String encryptionKey) {
    try {
      final parts = encryptedMessage.split(':');
      if (parts.length != 2) return encryptedMessage;

      final key = encrypt.Key.fromUtf8(encryptionKey);
      final encrypter = encrypt.Encrypter(encrypt.AES(key));
      final encrypted = encrypt.Encrypted.fromBase64(parts[0]);
      final iv = encrypt.IV.fromBase64(parts[1]);

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      print('Decryption error: $e');
      return 'Message cannot be decrypted';
    }
  }
}