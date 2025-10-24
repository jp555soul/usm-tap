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
      connectTimeout: const Duration(seconds: 600), // Match JS: 10 minutes
      receiveTimeout: const Duration(seconds: 600), // Match JS: 10 minutes
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
      final filters = _buildFilters(context);

      final response = await _dio.post(
        '/chat/',
        data: {
          'input': message,
          'filters': filters,
          'thread_id': context?['thread_id'] ?? 'ocean_session_${DateTime.now().millisecondsSinceEpoch}',
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
      final filters = _buildFilters(context);

      final response = await _dio.post(
        '/chat/stream',
        data: {
          'input': message,
          'filters': filters,
          'thread_id': context?['thread_id'] ?? 'ocean_session_${DateTime.now().millisecondsSinceEpoch}',
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

  /// Builds filters matching the JavaScript implementation
  Map<String, dynamic> _buildFilters(Map<String, dynamic>? context) {
    if (context == null) {
      return _getDefaultFilters();
    }

    // Extract values from context
    final selectedArea = context['selectedArea'] ?? 'USM';
    final selectedDepth = context['selectedDepth'] ?? 0.0;
    final selectedModel = context['selectedModel'] ?? 'NGOFS2';
    final selectedParameter = context['selectedParameter'] ?? 'Current Speed';
    final dataSource = context['dataSource'] ?? 'simulated';
    final playbackSpeed = context['playbackSpeed'] ?? 1.0;
    final currentFrame = context['currentFrame'] ?? 0;
    final totalFrames = context['totalFrames'] ?? 24;
    
    // Handle dates and create date_range
    final startDate = _parseDate(context['startDate']);
    final endDate = _parseDate(context['endDate'] ?? context['startDate']);
    final dateRange = '${_formatDate(startDate)} to ${_formatDate(endDate)}';
    
    // Handle HoloOcean POV
    final holoOceanPOV = context['holoOceanPOV'] ?? {};
    final povX = holoOceanPOV['x'] ?? 0.0;
    final povY = holoOceanPOV['y'] ?? 0.0;
    final povDepth = holoOceanPOV['z'] ?? holoOceanPOV['depth'] ?? 0.0;
    
    // Handle current data
    final currentData = context['currentData'];
    final currentSpeed = currentData?['currentSpeed'];
    final heading = currentData?['heading'];
    final waveHeight = currentData?['waveHeight'];
    final temperature = currentData?['temperature'];
    
    // Handle time series data
    final timeSeriesData = context['timeSeriesData'] ?? [];
    final dataPoints = timeSeriesData is List ? timeSeriesData.length : 0;
    
    // Build system prompt
    final systemPrompt = 'You are CubeAI, an expert oceanographic analysis assistant for the University of Southern Mississippi\'s marine science platform. '
        'You analyze real-time ocean data including currents, waves, temperature, and environmental conditions. '
        'Provide technical yet accessible responses focused on maritime safety, research insights, and data interpretation. '
        'Current context: $selectedArea at $selectedDepth meters depth using $selectedModel model for the date range $dateRange.';

    // Return flattened oceanographic filters (matching JS structure)
    return {
      'area': selectedArea,
      'date_range': dateRange,
      'depth': '$selectedDepth meters',
      'domain': 'oceanography',
      'model': selectedModel,
      'parameter': selectedParameter,
      'data_source': dataSource,
      'frame': currentFrame,
      'total_frames': totalFrames,
      'playback_speed': playbackSpeed,
      'data_points': dataPoints,
      'pov_x': povX,
      'pov_y': povY,
      'pov_depth': povDepth,
      'current_speed': currentSpeed,
      'heading': heading,
      'wave_height': waveHeight,
      'temperature': temperature,
      'system_prompt': systemPrompt,
    };
  }

  /// Returns default filters with proper values (not empty strings)
  Map<String, dynamic> _getDefaultFilters() {
    final now = DateTime.now();
    final dateRange = '${_formatDate(now)} to ${_formatDate(now)}';
    
    return {
      'area': 'USM',
      'date_range': dateRange,
      'depth': '0 meters',
      'domain': 'oceanography',
      'model': 'NGOFS2',
      'parameter': 'Current Speed',
      'data_source': 'simulated',
      'frame': 0,
      'total_frames': 24,
      'playback_speed': 1.0,
      'data_points': 0,
      'pov_x': 0.0,
      'pov_y': 0.0,
      'pov_depth': 0.0,
      'current_speed': null,
      'heading': null,
      'wave_height': null,
      'temperature': null,
      'system_prompt': 'You are CubeAI, an expert oceanographic analysis assistant for the University of Southern Mississippi\'s marine science platform.',
    };
  }

  /// Parses various date formats to DateTime
  DateTime _parseDate(dynamic date) {
    if (date == null) {
      return DateTime(2025, 8, 1, 12, 0, 0); // Default fallback date
    }
    
    if (date is DateTime) {
      return date;
    }
    
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        return DateTime(2025, 8, 1, 12, 0, 0); // Default fallback date
      }
    }
    
    return DateTime(2025, 8, 1, 12, 0, 0); // Default fallback date
  }

  /// Formats DateTime to YYYY-MM-DD string
  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
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