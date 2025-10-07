import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final FlutterAppAuth _appAuth;
  String? _accessToken;
  UserEntity? _currentUser;

  AuthRepositoryImpl({required FlutterAppAuth appAuth}) : _appAuth = appAuth;

  @override
  Future<Either<Failure, UserEntity>> login() async {
    try {
      final AuthorizationTokenResponse? result =
          await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          AppConstants.auth0ClientId,
          AppConstants.auth0CallbackUrl,
          discoveryUrl: 'https://${AppConstants.auth0Domain}/.well-known/openid-configuration',
          scopes: ['openid', 'profile', 'email', 'offline_access'],
          additionalParameters: {
            if (AppConstants.auth0Audience.isNotEmpty)
              'audience': AppConstants.auth0Audience,
          },
        ),
      );

      if (result == null) {
        return Left(const AuthFailure('Login cancelled'));
      }

      _accessToken = result.accessToken;

      // Parse ID token to get user info
      final user = _parseIdToken(result.idToken ?? '');
      _currentUser = user;

      return Right(user);
    } on Exception catch (e) {
      return Left(AuthFailure('Login failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _appAuth.endSession(EndSessionRequest(
        idTokenHint: _accessToken,
        postLogoutRedirectUrl: AppConstants.auth0CallbackUrl,
        discoveryUrl: 'https://${AppConstants.auth0Domain}/.well-known/openid-configuration',
      ));

      _accessToken = null;
      _currentUser = null;

      return const Right(null);
    } on Exception catch (e) {
      return Left(AuthFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getUserProfile() async {
    try {
      if (_currentUser != null) {
        return Right(_currentUser!);
      }
      return Left(const AuthFailure('No user logged in'));
    } on Exception catch (e) {
      return Left(AuthFailure('Failed to get user profile: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> validateAuthConfig() async {
    try {
      final isValid = AppConstants.auth0Domain.isNotEmpty &&
          AppConstants.auth0ClientId.isNotEmpty &&
          AppConstants.auth0CallbackUrl.isNotEmpty;

      return Right(isValid);
    } on Exception catch (e) {
      return Left(AuthFailure('Config validation failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> getAccessToken() async {
    try {
      if (_accessToken == null || _accessToken!.isEmpty) {
        return Left(const AuthFailure('No access token available'));
      }
      return Right(_accessToken!);
    } on Exception catch (e) {
      return Left(AuthFailure('Failed to get access token: ${e.toString()}'));
    }
  }

  UserEntity _parseIdToken(String idToken) {
    // Simple parsing - in production, use proper JWT decoding
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid token format');
      }

      // Decode payload (base64)
      final payload = parts[1];
      final normalized = base64.normalize(payload);
      final decoded = utf8.decode(base64.decode(normalized));
      final Map<String, dynamic> json = jsonDecode(decoded);

      return UserEntity(
        id: json['sub'] ?? '',
        email: json['email'] ?? '',
        name: json['name'],
        picture: json['picture'],
        metadata: json,
      );
    } catch (e) {
      // Fallback user
      return const UserEntity(
        id: 'unknown',
        email: 'unknown@example.com',
      );
    }
  }
}