// lib/core/utils/encryption_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;

abstract class EncryptionService {
  String encryptData(String data, String key);
  String decryptData(String encryptedData, String key);
  String hashData(String data);
  List<int> deriveKey(String password, {String? salt});
}

class EncryptionServiceImpl implements EncryptionService {
  @override
  String encryptData(String data, String key) {
    try {
      // Ensure key is 32 bytes for AES-256
      final keyBytes = _normalizeKey(key);
      final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));
      
      // Generate IV
      final iv = encrypt.IV.fromSecureRandom(16);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(encryptKey, mode: encrypt.AESMode.cbc),
      );
      
      final encrypted = encrypter.encrypt(data, iv: iv);
      
      // Prepend IV to encrypted data
      final combined = iv.bytes + encrypted.bytes;
      return base64.encode(combined);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  @override
  String decryptData(String encryptedData, String key) {
    try {
      final combined = base64.decode(encryptedData);
      
      // Extract IV (first 16 bytes)
      final iv = encrypt.IV(Uint8List.fromList(combined.sublist(0, 16)));
      
      // Extract encrypted data (rest)
      final encryptedBytes = combined.sublist(16);
      
      // Ensure key is 32 bytes for AES-256
      final keyBytes = _normalizeKey(key);
      final encryptKey = encrypt.Key(Uint8List.fromList(keyBytes));
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(encryptKey, mode: encrypt.AESMode.cbc),
      );
      
      final encrypted = encrypt.Encrypted(Uint8List.fromList(encryptedBytes));
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      return decrypted;
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  @override
  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  List<int> deriveKey(String password, {String? salt}) {
    final saltBytes = salt != null 
        ? utf8.encode(salt) 
        : List<int>.filled(16, 0);
    
    final passwordBytes = utf8.encode(password);
    final combined = [...passwordBytes, ...saltBytes];
    
    // Simple key derivation - in production, use PBKDF2
    var key = sha256.convert(combined).bytes;
    
    // Additional rounds for stronger key
    for (var i = 0; i < 1000; i++) {
      key = sha256.convert(key).bytes;
    }
    
    return key;
  }

  List<int> _normalizeKey(String key) {
    final keyBytes = utf8.encode(key);
    
    if (keyBytes.length == 32) {
      return keyBytes;
    } else if (keyBytes.length > 32) {
      return keyBytes.sublist(0, 32);
    } else {
      // Pad with zeros if less than 32 bytes
      return [...keyBytes, ...List<int>.filled(32 - keyBytes.length, 0)];
    }
  }
}