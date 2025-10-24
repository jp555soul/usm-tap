// lib/data/datasources/local/session_key_service.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionKeyService {
  static const String _sessionKeyKey = 'session_encryption_key';
  static const String _sessionIdKey = 'session_id';
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  bool _useSecureStorage = true;

  SessionKeyService({
    required FlutterSecureStorage secureStorage,
    required SharedPreferences prefs,
  })  : _secureStorage = secureStorage,
        _prefs = prefs;

  /// Generate a new session key
  Future<String> generateSessionKey() async {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(32, (_) => random.nextInt(256)),
    );
    final key = base64Url.encode(bytes);
    
    await _writeSecure(_sessionKeyKey, key);
    
    // Generate session ID
    final sessionId = _generateSessionId();
    await _writeSecure(_sessionIdKey, sessionId);
    
    return key;
  }

  /// Get the current session key
  Future<String?> getSessionKey() async {
    return await _readSecure(_sessionKeyKey);
  }

  /// Get the current session ID
  Future<String?> getSessionId() async {
    return await _readSecure(_sessionIdKey);
  }

  /// Set a specific session key
  Future<void> setSessionKey(String key) async {
    await _writeSecure(_sessionKeyKey, key);
  }

  /// Clear the session key
  Future<void> clearSessionKey() async {
    await _deleteSecure(_sessionKeyKey);
    await _deleteSecure(_sessionIdKey);
  }

  /// Check if a session key exists
  Future<bool> hasSessionKey() async {
    final key = await getSessionKey();
    return key != null && key.isNotEmpty;
  }

  /// Rotate the session key
  Future<String> rotateSessionKey() async {
    await clearSessionKey();
    return await generateSessionKey();
  }

  /// Derive a key from the session key
  Future<Uint8List> deriveKey({String? salt}) async {
    final sessionKey = await getSessionKey();
    if (sessionKey == null) {
      throw Exception('No session key found');
    }

    final saltBytes = salt != null 
        ? utf8.encode(salt) 
        : utf8.encode('default_salt');
    
    final keyBytes = utf8.encode(sessionKey);
    final combined = [...keyBytes, ...saltBytes];
    
    final digestBytes = sha256.convert(combined).bytes;
    return Uint8List.fromList(digestBytes);
  }

  String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random.secure().nextInt(1000000);
    final combined = '$timestamp-$random';
    return base64Url.encode(utf8.encode(combined));
  }

  // Secure storage with fallback to SharedPreferences
  Future<String?> _readSecure(String key) async {
    if (_useSecureStorage) {
      try {
        return await _secureStorage.read(key: key);
      } catch (e) {
        // debugPrint('Secure storage read failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences
    return _prefs.getString(key);
  }

  Future<void> _writeSecure(String key, String value) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.write(key: key, value: value);
        return;
      } catch (e) {
        // debugPrint('Secure storage write failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences
    await _prefs.setString(key, value);
  }

  Future<void> _deleteSecure(String key) async {
    if (_useSecureStorage) {
      try {
        await _secureStorage.delete(key: key);
        return;
      } catch (e) {
        // debugPrint('Secure storage delete failed, falling back to SharedPreferences: $e');
        _useSecureStorage = false;
      }
    }
    
    // Fallback to SharedPreferences
    await _prefs.remove(key);
  }
}