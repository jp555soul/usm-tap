// lib/data/datasources/local/session_key_local_datasource.dart
import './session_key_service.dart';

/// Abstract class for local session key data source
abstract class SessionKeyLocalDataSource {
  Future<String?> getSessionKey();
  Future<bool> hasSessionKey();
  Future<void> clearSessionKey();
  Future<String> generateSessionKey();
}

/// Implementation of [SessionKeyLocalDataSource]
class SessionKeyLocalDataSourceImpl implements SessionKeyLocalDataSource {
  final SessionKeyService _sessionKeyService;

  SessionKeyLocalDataSourceImpl({
    required SessionKeyService sessionKeyService,
  }) : _sessionKeyService = sessionKeyService;

  @override
  Future<String?> getSessionKey() async {
    return await _sessionKeyService.getSessionKey();
  }

  @override
  Future<bool> hasSessionKey() async {
    return await _sessionKeyService.hasSessionKey();
  }

  @override
  Future<void> clearSessionKey() async {
    return await _sessionKeyService.clearSessionKey();
  }

  @override
  Future<String> generateSessionKey() async {
    return await _sessionKeyService.generateSessionKey();
  }
}