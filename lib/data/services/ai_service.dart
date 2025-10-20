// lib/data/services/ai_service.dart
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';

class AiService {
  final Dio _dio;
  final String baseUrl;
  final String? token;

  AiService({
    required Dio dio,
    String? baseUrl,
    this.token,
  })  : _dio = dio,
        baseUrl = baseUrl ?? AppConstants.baseUrl {
    _configureDio();
  }

  void _configureDio() {
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    // Add interceptors for logging
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<Map<String, dynamic>> sendMessage({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      // Merge default filters with provided context
      final filters = {
        'area': context?['area'] ?? {},
        'date_range': context?['date_range'] ?? {},
        'depth': context?['depth'] ?? {},
        ...?context,
      };

      final response = await _dio.post(
        '/chat/',
        data: {
          'input': message,
          'filters': filters,
          'thread_id': 'thread_${DateTime.now().millisecondsSinceEpoch}',
        },
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Stream<String> sendMessageStream({
    required String message,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async* {
    try {
      // Merge default filters with provided context
      final filters = {
        'area': context?['area'] ?? {},
        'date_range': context?['date_range'] ?? {},
        'depth': context?['depth'] ?? {},
        ...?context,
      };

      final response = await _dio.post(
        '/chat/stream',
        data: {
          'input': message,
          'filters': filters,
          'thread_id': 'thread_${DateTime.now().millisecondsSinceEpoch}',
        },
        options: Options(
          responseType: ResponseType.stream,
        ),
      );

      final stream = response.data.stream;
      await for (final chunk in stream) {
        final decoded = String.fromCharCodes(chunk);
        yield decoded;
      }
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await _dio.get('/healthz');
      return response.statusCode == 200;
    } on DioException catch (_) {
      return false;
    }
  }

  Exception _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Connection timeout');
      case DioExceptionType.badResponse:
        return Exception('Server error: ${error.response?.statusCode}');
      case DioExceptionType.cancel:
        return Exception('Request cancelled');
      default:
        return Exception('Network error: ${error.message}');
    }
  }
}