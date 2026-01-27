// lib/data/services/ai_service.dart
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';

/// Chat API service for interacting with the AI assistant.
/// 
/// Implements the Chat API as documented in docs/doc.md:
/// - POST /chat - Send message to AI (streaming response)
/// - GET /chat/messages/{thread_id} - Retrieve thread messages
class AiService {
  final Dio _dio;
  final String baseUrl;
  final String? token;
  
  // Required authentication headers
  final String tenantUuid;
  final String userUuid;

  AiService({
    required Dio dio,
    String? baseUrl,
    this.token,
    required this.tenantUuid,
    required this.userUuid,
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
        // Required authentication headers per docs/doc.md
        'x-bluemvmt-tenant-uuid': tenantUuid,
        'x-bluemvmt-user-uuid': userUuid,
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// Sends a message to the Chat API.
  /// 
  /// Parameters:
  /// - [message]: Required. The question or prompt to send to the AI.
  /// - [llmModel]: Optional. LLM model to use: "blueai" (default) or "gemini-2.5-pro".
  /// - [datasourceUuids]: Optional. List of datasource UUIDs to query against.
  /// - [threadId]: Optional. Thread ID for conversation continuity.
  /// - [additionalInstructions]: Optional. Extra instructions for the LLM.
  /// - [history]: Optional. Previous message history.
  /// - [context]: Optional. Additional context for filters.
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async {
    try {
      final requestBody = _buildRequestBody(
        message: message,
        llmModel: llmModel,
        datasourceUuids: datasourceUuids,
        threadId: threadId ?? context?['thread_id'],
        additionalInstructions: additionalInstructions,
        context: context,
      );

      final response = await _dio.post(
        '/chat',
        data: requestBody,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Sends a message to the Chat API and returns a streaming response.
  /// 
  /// The API returns a streaming response (text/event-stream) that delivers
  /// the AI's response in real-time.
  Stream<String> sendMessageStream({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    List<Map<String, dynamic>>? history,
    Map<String, dynamic>? context,
  }) async* {
    try {
      final requestBody = _buildRequestBody(
        message: message,
        llmModel: llmModel,
        datasourceUuids: datasourceUuids,
        threadId: threadId ?? context?['thread_id'],
        additionalInstructions: additionalInstructions,
        context: context,
      );

      final response = await _dio.post(
        '/chat',
        data: requestBody,
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

  /// Retrieves all messages from a conversation thread.
  /// 
  /// GET /chat/messages/{thread_id}
  Future<Map<String, dynamic>> getThreadMessages({
    required String threadId,
  }) async {
    try {
      final response = await _dio.get('/chat/messages/$threadId');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Builds the request body according to the Chat API specification.
  Map<String, dynamic> _buildRequestBody({
    required String message,
    String? llmModel,
    List<String>? datasourceUuids,
    String? threadId,
    String? additionalInstructions,
    Map<String, dynamic>? context,
  }) {
    final body = <String, dynamic>{
      'input': message,
    };

    // Add optional parameters only if provided
    if (llmModel != null) {
      body['llm_model'] = llmModel;
    }

    if (datasourceUuids != null && datasourceUuids.isNotEmpty) {
      body['datasource_uuids'] = datasourceUuids;
    }

    if (threadId != null) {
      body['thread_id'] = threadId;
    }

    if (additionalInstructions != null) {
      body['additional_instructions'] = additionalInstructions;
    }

    return body;
  }

  /// Builds filters matching the JavaScript implementation (legacy support)
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
      // Default date set to 08/01/2025 as this is currently the start of available data.
      return DateTime(2025, 8, 1, 12, 0, 0);
    }

    if (date is DateTime) {
      return date;
    }

    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (e) {
        // Default date set to 08/01/2025 as this is currently the start of available data.
        return DateTime(2025, 8, 1, 12, 0, 0);
      }
    }

    // Default date set to 08/01/2025 as this is currently the start of available data.
    return DateTime(2025, 8, 1, 12, 0, 0);
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