import 'package:flutter/foundation.dart';

/// Session Key Service
/// Manages the encryption session key for encrypted storage
class SessionKeyService {
  static String? _sessionKey;
  
  /// Sets the session key for encryption
  /// @param key - The session key to use for encryption
  static void setSessionKey(String key) {
    _sessionKey = key;
    if (kDebugMode) {
      debugPrint('Session key has been set');
    }
  }
  
  /// Gets the current session key
  /// @returns The session key or null if not set
  String? getSessionKey() {
    return _sessionKey;
  }
  
  /// Checks if a session key is set
  /// @returns True if session key exists
  bool hasSessionKey() {
    return _sessionKey != null && _sessionKey!.isNotEmpty;
  }
  
  /// Clears the session key
  static void clearSessionKey() {
    _sessionKey = null;
    if (kDebugMode) {
      debugPrint('Session key has been cleared');
    }
  }
}

/// Local data source implementation for session key management
abstract class SessionKeyLocalDataSource {
  String? getSessionKey();
  bool hasSessionKey();
}

class SessionKeyLocalDataSourceImpl implements SessionKeyLocalDataSource {
  final SessionKeyService _sessionKeyService;
  
  SessionKeyLocalDataSourceImpl({
    required SessionKeyService sessionKeyService,
  }) : _sessionKeyService = sessionKeyService;
  
  @override
  String? getSessionKey() {
    return _sessionKeyService.getSessionKey();
  }
  
  @override
  bool hasSessionKey() {
    return _sessionKeyService.hasSessionKey();
  }
}