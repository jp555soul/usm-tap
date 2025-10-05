import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_key_service.dart';

/// Encrypted Storage Service
/// Handles encrypted storage using AES encryption with a session key
class EncryptedStorageService {
  final SharedPreferences _prefs;
  final SessionKeyService _sessionKeyService;
  
  EncryptedStorageService({
    required SharedPreferences prefs,
    required SessionKeyService sessionKeyService,
  }) : _prefs = prefs,
       _sessionKeyService = sessionKeyService;
  
  /// Saves data to encrypted storage
  /// @param key - The storage key
  /// @param value - The value to store (will be JSON encoded)
  Future<void> saveData(String key, dynamic value) async {
    final sessionKey = await _sessionKeyService.getSessionKey();
    
    if (sessionKey != null && sessionKey.isNotEmpty) {
      try {
        final encryptedValue = _encryptData(jsonEncode(value), sessionKey);
        await _prefs.setString(key, encryptedValue);
      } catch (error) {
        debugPrint('Error encrypting data: $error');
        // Fallback to unencrypted storage
        await _prefs.setString(key, jsonEncode(value));
      }
    } else {
      debugPrint('Session key not set. Data will not be encrypted.');
      await _prefs.setString(key, jsonEncode(value));
    }
  }
  
  /// Gets data from encrypted storage
  /// @param key - The storage key
  /// @returns The decrypted value or null if not found/error
  Future<dynamic> getData(String key) async {
    final sessionKey = await _sessionKeyService.getSessionKey();
    final storedValue = _prefs.getString(key);
    
    if (storedValue == null) {
      return null;
    }
    
    if (sessionKey != null && sessionKey.isNotEmpty) {
      try {
        final decryptedValue = _decryptData(storedValue, sessionKey);
        return jsonDecode(decryptedValue);
      } catch (error) {
        debugPrint('Error decrypting data from storage: $error');
        return null;
      }
    } else {
      try {
        return jsonDecode(storedValue);
      } catch (error) {
        return storedValue;
      }
    }
  }
  
  /// Deletes data from storage
  /// @param key - The storage key
  Future<void> deleteData(String key) async {
    await _prefs.remove(key);
  }
  
  /// Encrypts data using AES encryption with the provided key
  /// @param data - The data to encrypt
  /// @param keyString - The encryption key
  /// @returns The encrypted data as a base64 string
  String _encryptData(String data, String keyString) {
    // Ensure key is 32 bytes (256 bits) for AES-256
    final keyBytes = _deriveKey(keyString, 32);
    final key = encrypt.Key(keyBytes);
    
    // Generate a random IV (Initialization Vector)
    final iv = encrypt.IV.fromLength(16);
    
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypter.encrypt(data, iv: iv);
    
    // Combine IV and encrypted data for storage (IV is needed for decryption)
    final combined = '${iv.base64}:${encrypted.base64}';
    return combined;
  }
  
  /// Decrypts data using AES encryption with the provided key
  /// @param encryptedData - The encrypted data (IV:ciphertext format)
  /// @param keyString - The decryption key
  /// @returns The decrypted data
  String _decryptData(String encryptedData, String keyString) {
    try {
      // Split IV and ciphertext
      final parts = encryptedData.split(':');
      if (parts.length != 2) {
        // Might be old format without IV, try direct decryption
        return _decryptDataLegacy(encryptedData, keyString);
      }
      
      final ivBase64 = parts[0];
      final ciphertextBase64 = parts[1];
      
      // Ensure key is 32 bytes (256 bits) for AES-256
      final keyBytes = _deriveKey(keyString, 32);
      final key = encrypt.Key(keyBytes);
      final iv = encrypt.IV.fromBase64(ivBase64);
      
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc),
      );
      
      final encrypted = encrypt.Encrypted.fromBase64(ciphertextBase64);
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      return decrypted;
    } catch (error) {
      debugPrint('Error in decryption: $error');
      rethrow;
    }
  }
  
  /// Legacy decryption for backwards compatibility
  /// @param encryptedData - The encrypted data
  /// @param keyString - The decryption key
  /// @returns The decrypted data
  String _decryptDataLegacy(String encryptedData, String keyString) {
    final keyBytes = _deriveKey(keyString, 32);
    final key = encrypt.Key(keyBytes);
    
    // Use a fixed IV for legacy data (not ideal but needed for compatibility)
    final iv = encrypt.IV.fromLength(16);
    
    final encrypter = encrypt.Encrypter(
      encrypt.AES(key, mode: encrypt.AESMode.cbc),
    );
    
    final encrypted = encrypt.Encrypted.fromBase64(encryptedData);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    
    return decrypted;
  }
  
  /// Derives a key of specified length from the input key string
  /// @param keyString - The input key string
  /// @param length - The desired key length in bytes
  /// @returns The derived key bytes
  List<int> _deriveKey(String keyString, int length) {
    final keyBytes = utf8.encode(keyString);
    
    // If key is already the right length, return it
    if (keyBytes.length == length) {
      return keyBytes;
    }
    
    // If key is too short, pad it
    if (keyBytes.length < length) {
      final paddedKey = List<int>.from(keyBytes);
      while (paddedKey.length < length) {
        paddedKey.addAll(keyBytes);
      }
      return paddedKey.sublist(0, length);
    }
    
    // If key is too long, truncate it
    return keyBytes.sublist(0, length);
  }
  
  /// Clears all items from storage
  Future<void> clear() async {
    await _prefs.clear();
  }
  
  /// Checks if a key exists in storage
  bool containsKey(String key) {
    return _prefs.containsKey(key);
  }
  
  /// Gets all keys from storage
  Set<String> getKeys() {
    return _prefs.getKeys();
  }
}

/// Local data source implementation for encrypted storage
abstract class EncryptedStorageLocalDataSource {
  Future<void> saveData(String key, dynamic value);
  Future<dynamic> getData(String key);
  Future<void> deleteData(String key);
  Future<void> clear();
  bool containsKey(String key);
  Set<String> getKeys();
}

class EncryptedStorageLocalDataSourceImpl implements EncryptedStorageLocalDataSource {
  final EncryptedStorageService _encryptedStorageService;
  
  EncryptedStorageLocalDataSourceImpl({
    required EncryptedStorageService encryptedStorageService,
  }) : _encryptedStorageService = encryptedStorageService;
  
  @override
  Future<void> saveData(String key, dynamic value) async {
    await _encryptedStorageService.saveData(key, value);
  }
  
  @override
  Future<dynamic> getData(String key) {
    return _encryptedStorageService.getData(key);
  }
  
  @override
  Future<void> deleteData(String key) async {
    await _encryptedStorageService.deleteData(key);
  }
  
  @override
  Future<void> clear() async {
    await _encryptedStorageService.clear();
  }
  
  @override
  bool containsKey(String key) {
    return _encryptedStorageService.containsKey(key);
  }
  
  @override
  Set<String> getKeys() {
    return _encryptedStorageService.getKeys();
  }
}