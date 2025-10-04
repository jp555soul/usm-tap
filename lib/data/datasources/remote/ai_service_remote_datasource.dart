import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/errors/exceptions.dart';

/// AI Service with External API Integration
/// Handles communication with demo-chat.isdata.ai API (API-only mode)
class AiService {
  final Dio _dio;
  
  // API Configuration
  late final ApiConfig _apiConfig;
  
  AiService(this._dio) {
    _initializeConfig();
  }
  
  void _initializeConfig() {
    // Security warning for production
    if (kReleaseMode && 
        AppConstants.baseUrl.isNotEmpty && 
        !AppConstants.baseUrl.startsWith('https://')) {
      debugPrint('Insecure API endpoint configured for production environment. Please use https.');
    }
    
    _apiConfig = ApiConfig(
      baseUrl: AppConstants.baseUrl,
      healthCheckEndpoint: '${AppConstants.baseUrl}/healthz',
      endpoint: '/chat/',
      timeout: const Duration(minutes: 10), // Increased timeout to 10 minutes
      retries: 2,
      token: AppConstants.bearerToken,
    );
  }
  
  /// Main function to get AI response - API only (no fallbacks)
  /// @param message - The user's input message
  /// @param context - Current oceanographic data context
  /// @param threadId - Thread ID for conversation continuity
  /// @returns AI response
  Future<String> getAIResponse(
    String message,
    Map<String, dynamic> context, {
    String? threadId,
  }) async {
    try {
      final apiResponse = await _getAPIResponse(message, context, threadId);
      if (apiResponse.isNotEmpty) {
        return apiResponse;
      } else {
        throw ServerException('Empty response from API');
      }
    } catch (error) {
      debugPrint('API request failed: $error');
      throw ServerException('AI service unavailable: $error');
    }
  }
  
  /// Makes request to external AI API
  /// @param message - User message
  /// @param context - Oceanographic context
  /// @param threadId - Thread ID for conversation continuity
  /// @returns API response
  Future<String> _getAPIResponse(
    String message,
    Map<String, dynamic> context,
    String? threadId,
  ) async {
    final cancelToken = CancelToken();
    
    // Set up timeout
    Timer? timeoutTimer;
    timeoutTimer = Timer(_apiConfig.timeout, () {
      if (!cancelToken.isCancelled) {
        cancelToken.cancel('Request timeout');
      }
    });
    
    try {
      final payload = _formatAPIPayload(message, context, threadId);
      
      final response = await _dio.post(
        '${_apiConfig.baseUrl}${_apiConfig.endpoint}',
        data: payload,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_apiConfig.token}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: _apiConfig.timeout,
          sendTimeout: _apiConfig.timeout,
        ),
        cancelToken: cancelToken,
      );
      
      timeoutTimer.cancel();
      
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return _extractResponseFromAPI(response.data);
      } else {
        throw ServerException('HTTP ${response.statusCode}: ${response.statusMessage}');
      }
    } on DioException catch (e) {
      timeoutTimer?.cancel();
      
      if (e.type == DioExceptionType.cancel) {
        throw ServerException('API request timed out');
      }
      throw ServerException(e.message ?? 'Network error');
    } catch (error) {
      timeoutTimer?.cancel();
      rethrow;
    }
  }
  
  /// Formats a flattened payload for the external API
  /// @param message - User message
  /// @param context - Oceanographic context
  /// @param threadId - Thread ID for conversation continuity
  /// @returns Formatted API payload
  Map<String, dynamic> _formatAPIPayload(
    String message,
    Map<String, dynamic> context,
    String? threadId,
  ) {
    final currentData = context['currentData'] as Map<String, dynamic>?;
    final timeSeriesData = context['timeSeriesData'] as List? ?? [];
    final dataSource = context['dataSource'] as String? ?? 'simulated';
    final selectedDepth = context['selectedDepth'] ?? 0;
    final selectedModel = context['selectedModel'] as String? ?? 'NGOSF2';
    final selectedParameter = context['selectedParameter'] as String? ?? 'Current Speed';
    final selectedArea = context['selectedArea'] as String? ?? 'USM'; // Provide a fallback since this is required
    final playbackSpeed = context['playbackSpeed'] ?? 1;
    final holoOceanPOV = context['holoOceanPOV'] as Map<String, dynamic>? ?? {'x': 0, 'y': 0, 'depth': 0};
    final currentFrame = context['currentFrame'] ?? 0;
    final totalFrames = context['totalFrames'] ?? 24;
    final startDate = context['startDate'] as DateTime?;
    final endDate = context['endDate'] as DateTime?;
    final envData = context['envData'] as Map<String, dynamic>? ?? {};
    
    // Helper to format date to YYYY-MM-DD
    String formatDate(DateTime? date) {
      // Fallback to a default date if input is invalid
      final validDate = date ?? DateTime.parse('2025-08-01T12:00:00Z');
      return validDate.toIso8601String().split('T')[0];
    }
    
    // Create date_range string, ensuring it's always present as it's required
    final formattedStartDate = formatDate(startDate);
    final formattedEndDate = formatDate(endDate ?? startDate);
    final dateRange = '$formattedStartDate to $formattedEndDate';
    
    // Create flattened oceanographic context for filters
    final oceanographicFilters = {
      'area': selectedArea,
      'date_range': dateRange,
      'depth': '$selectedDepth meters', // Use meters to match API schema
      'domain': 'oceanography',
      'model': selectedModel,
      'parameter': selectedParameter,
      'data_source': dataSource,
      'frame': currentFrame,
      'total_frames': totalFrames,
      'playback_speed': playbackSpeed,
      'data_points': timeSeriesData.length,
      'pov_x': holoOceanPOV['x'] ?? 0,
      'pov_y': holoOceanPOV['y'] ?? 0,
      'pov_depth': holoOceanPOV['depth'] ?? 0,
      'current_speed': currentData?['currentSpeed'],
      'heading': currentData?['heading'],
      'wave_height': currentData?['waveHeight'],
      'temperature': currentData?['temperature'],
      'system_prompt': '''You are CubeAI, an expert oceanographic analysis assistant for the University of Southern Mississippi's marine science platform. 
    You analyze real-time ocean data including currents, waves, temperature, and environmental conditions. 
    Provide technical yet accessible responses focused on maritime safety, research insights, and data interpretation.
    Current context: $selectedArea at $selectedDepth meters depth using $selectedModel model for the date range $dateRange.''',
    };
    
    // Format for API (matching working Postman structure)
    return {
      'input': message,
      'filters': oceanographicFilters,
      'thread_id': threadId ?? 'ocean_session_${DateTime.now().millisecondsSinceEpoch}',
    };
  }
  
  /// Extracts the response text from API response
  /// @param apiData - Raw API response
  /// @returns Extracted response text
  String _extractResponseFromAPI(dynamic apiData) {
    if (apiData is Map<String, dynamic>) {
      // Handle the documented API response structure
      if (apiData['run_items'] != null && apiData['run_items'] is List) {
        final runItems = apiData['run_items'] as List;
        for (final item in runItems) {
          if (item is Map<String, dynamic> && item['content'] != null && item['content'] is List) {
            final content = item['content'] as List;
            for (final contentItem in content) {
              if (contentItem is Map<String, dynamic> && 
                  contentItem['type'] == 'output_text' && 
                  contentItem['text'] != null) {
                return contentItem['text'] as String;
              }
            }
          }
        }
      }
      
      // Fallback to common response formats
      if (apiData['response'] != null) {
        return apiData['response'] as String;
      }
      if (apiData['message'] != null) {
        return apiData['message'] as String;
      }
      if (apiData['content'] != null) {
        return apiData['content'] as String;
      }
      if (apiData['text'] != null) {
        return apiData['text'] as String;
      }
      if (apiData['output'] != null) {
        return apiData['output'] as String;
      }
      if (apiData['result'] != null) {
        return apiData['result'] as String;
      }
    }
    
    // If response is just a string
    if (apiData is String) {
      return apiData;
    }
    
    // Log the response structure for debugging
    // debugPrint('API Response Structure: $apiData');
    
    throw ServerException('Invalid API response format');
  }
  
  /// Detects user intent from message for better API context
  /// @param message - User message
  /// @returns Detected intent
  String detectUserIntent(String message) {
    final msg = message.toLowerCase();
    
    if (msg.contains('current') || msg.contains('flow')) return 'current_analysis';
    if (msg.contains('wave') || msg.contains('swell')) return 'wave_analysis';
    if (msg.contains('temperature') || msg.contains('thermal')) return 'temperature_analysis';
    if (msg.contains('predict') || msg.contains('forecast')) return 'prediction';
    if (msg.contains('safety') || msg.contains('risk')) return 'safety_assessment';
    if (msg.contains('data') || msg.contains('source')) return 'data_inquiry';
    if (msg.contains('model') || msg.contains('accuracy')) return 'model_info';
    if (msg.contains('export') || msg.contains('download')) return 'data_export';
    
    return 'general_inquiry';
  }
  
  /// Test API connectivity (Updated endpoint)
  /// @returns True if API is accessible
  Future<bool> testAPIConnection() async {
    try {
      final cancelToken = CancelToken();
      
      // Set up timeout
      Timer? timeoutTimer;
      timeoutTimer = Timer(_apiConfig.timeout, () {
        if (!cancelToken.isCancelled) {
          cancelToken.cancel('Request timeout');
        }
      });
      
      final response = await _dio.get(
        _apiConfig.healthCheckEndpoint,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${_apiConfig.token}',
            'Content-Type': 'application/json',
          },
          receiveTimeout: _apiConfig.timeout,
        ),
        cancelToken: cancelToken,
      );
      
      timeoutTimer.cancel();
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (error) {
      return false;
    }
  }
  
  /// Get API status for monitoring
  /// @returns API status information
  Future<Map<String, dynamic>> getAPIStatus() async {
    final isConnected = await testAPIConnection();
    
    return {
      'connected': isConnected,
      'endpoint': '${_apiConfig.baseUrl}${_apiConfig.endpoint}',
      'timestamp': DateTime.now().toIso8601String(),
      'hasApiKey': true, // Updated to reflect the use of a Bearer token
    };
  }
}

/// API Configuration class
class ApiConfig {
  final String baseUrl;
  final String healthCheckEndpoint;
  final String endpoint;
  final Duration timeout;
  final int retries;
  final String token;
  
  const ApiConfig({
    required this.baseUrl,
    required this.healthCheckEndpoint,
    required this.endpoint,
    required this.timeout,
    required this.retries,
    required this.token,
  });
}

/// Remote data source implementation for AI service
abstract class AiServiceRemoteDataSource {
  Future<String> getAIResponse(
    String message,
    Map<String, dynamic> context, {
    String? threadId,
  });
  
  Future<bool> testAPIConnection();
  
  Future<Map<String, dynamic>> getAPIStatus();
}

class AiServiceRemoteDataSourceImpl implements AiServiceRemoteDataSource {
  final AiService _aiService;
  
  AiServiceRemoteDataSourceImpl({required AiService aiService})
      : _aiService = aiService;
  
  @override
  Future<String> getAIResponse(
    String message,
    Map<String, dynamic> context, {
    String? threadId,
  }) async {
    return await _aiService.getAIResponse(message, context, threadId: threadId);
  }
  
  @override
  Future<bool> testAPIConnection() async {
    return await _aiService.testAPIConnection();
  }
  
  @override
  Future<Map<String, dynamic>> getAPIStatus() async {
    return await _aiService.getAPIStatus();
  }
}