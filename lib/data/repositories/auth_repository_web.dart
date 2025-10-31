import 'dart:convert';
import 'dart:html' as html;
import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:math';
import '../../core/constants/app_constants.dart';
import '../../core/errors/failures.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';

class WebAuthRepository implements AuthRepository {
  String? _accessToken;
  String? _idToken;
  UserEntity? _currentUser;

  static const String _storageKeyAccessToken = 'auth_access_token';
  static const String _storageKeyIdToken = 'auth_id_token';
  static const String _storageKeyUserData = 'auth_user_data';
  static const String _storageKeyState = 'auth_state';
  static const String _storageKeyCodeVerifier = 'auth_code_verifier';

  WebAuthRepository() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    try {
      final storage = html.window.localStorage;
      _accessToken = storage[_storageKeyAccessToken];
      _idToken = storage[_storageKeyIdToken];
      final userData = storage[_storageKeyUserData];
      if (userData != null && userData.isNotEmpty) {
        final json = jsonDecode(userData) as Map<String, dynamic>;
        _currentUser = UserEntity.fromJson(json);
      }
    } catch (e) {}
  }

  void _saveToStorage() {
    try {
      final storage = html.window.localStorage;
      if (_accessToken != null) storage[_storageKeyAccessToken] = _accessToken!;
      if (_idToken != null) storage[_storageKeyIdToken] = _idToken!;
      if (_currentUser != null) storage[_storageKeyUserData] = jsonEncode(_currentUser!.toJson());
    } catch (e) {}
  }

  void _clearStorage() {
    try {
      final storage = html.window.localStorage;
      storage.remove(_storageKeyAccessToken);
      storage.remove(_storageKeyIdToken);
      storage.remove(_storageKeyUserData);
      storage.remove(_storageKeyState);
      storage.remove(_storageKeyCodeVerifier);
    } catch (e) {}
  }

  @override
  Future<Either<Failure, UserEntity>> login() async {
    try {
      final uri = Uri.parse(html.window.location.href);
      if (uri.queryParameters.containsKey('code')) {
        return await _handleCallback(uri);
      } else {
        await _initiateOAuthFlow();
        return Left(const AuthFailure('Redirecting to login...'));
      }
    } on Exception catch (e) {
      return Left(AuthFailure('Login failed: ${e.toString()}'));
    }
  }

  Future<void> _initiateOAuthFlow() async {
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);
    final state = _generateRandomString(32);

    html.window.localStorage[_storageKeyState] = state;
    html.window.localStorage[_storageKeyCodeVerifier] = codeVerifier;

    final authUrl = Uri.https(AppConstants.auth0Domain, '/authorize', {
      'response_type': 'code',
      'client_id': AppConstants.auth0ClientId,
      'redirect_uri': AppConstants.auth0CallbackUrl,
      'scope': 'openid profile email offline_access',
      'state': state,
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
      if (AppConstants.auth0Audience.isNotEmpty) 'audience': AppConstants.auth0Audience,
    });

    html.window.location.href = authUrl.toString();
  }

  Future<Either<Failure, UserEntity>> _handleCallback(Uri uri) async {
    try {
      final code = uri.queryParameters['code'];
      final state = uri.queryParameters['state'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        _clearStorage();
        return Left(AuthFailure('Auth error: $error'));
      }
      if (code == null) return Left(const AuthFailure('No authorization code received'));

      final storedState = html.window.localStorage[_storageKeyState];
      if (state != storedState) {
        _clearStorage();
        return Left(const AuthFailure('Invalid state parameter'));
      }

      final codeVerifier = html.window.localStorage[_storageKeyCodeVerifier];
      if (codeVerifier == null) return Left(const AuthFailure('Missing code verifier'));

      final tokenUrl = Uri.https(AppConstants.auth0Domain, '/oauth/token');
      final response = await http.post(tokenUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'grant_type': 'authorization_code',
          'client_id': AppConstants.auth0ClientId,
          'code': code,
          'redirect_uri': AppConstants.auth0CallbackUrl,
          'code_verifier': codeVerifier,
        }),
      );

      if (response.statusCode != 200) {
        return Left(AuthFailure('Token exchange failed: ${response.body}'));
      }

      final tokenData = jsonDecode(response.body) as Map<String, dynamic>;
      _accessToken = tokenData['access_token'] as String?;
      _idToken = tokenData['id_token'] as String?;

      if (_idToken == null) return Left(const AuthFailure('No ID token received'));

      _currentUser = _parseIdToken(_idToken!);
      _saveToStorage();

      final cleanUrl = uri.replace(queryParameters: {}).toString();
      html.window.history.pushState(null, '', cleanUrl);

      html.window.localStorage.remove(_storageKeyState);
      html.window.localStorage.remove(_storageKeyCodeVerifier);

      return Right(_currentUser!);
    } on Exception catch (e) {
      return Left(AuthFailure('Callback handling failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      final logoutUrl = Uri.https(AppConstants.auth0Domain, '/v2/logout', {
        'client_id': AppConstants.auth0ClientId,
        'returnTo': AppConstants.auth0CallbackUrl,
      });

      _accessToken = null;
      _idToken = null;
      _currentUser = null;
      _clearStorage();

      html.window.location.href = logoutUrl.toString();
      return const Right(null);
    } on Exception catch (e) {
      return Left(AuthFailure('Logout failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getUserProfile() async {
    try {
      if (_currentUser != null) return Right(_currentUser!);
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
    try {
      final parts = idToken.split('.');
      if (parts.length != 3) throw Exception('Invalid token format');
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
      return const UserEntity(id: 'unknown', email: 'unknown@example.com');
    }
  }

  String _generateCodeVerifier() => _generateRandomString(128);

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return base64Url.encode(digest.bytes).replaceAll('=', '');
  }

  String _generateRandomString(int length) {
    const charset = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}

AuthRepository createPlatformAuthRepository(dynamic appAuth) {
  return WebAuthRepository();
}
