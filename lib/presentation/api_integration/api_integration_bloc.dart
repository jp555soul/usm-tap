// ============================================================================
// FILE: lib/presentation/blocs/api_integration/api_integration_bloc.dart
// ============================================================================

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../domain/entities/api_status.dart';
import '../../../domain/entities/api_config.dart';
import '../../../domain/entities/api_metrics.dart';
import '../../../domain/repositories/api_repository.dart';
import '../../../data/datasources/local/encrypted_storage_local_datasource.dart';

// ============================================================================
// EVENTS
// ============================================================================

abstract class ApiIntegrationEvent extends Equatable {
  const ApiIntegrationEvent();

  @override
  List<Object?> get props => [];
}

class CheckApiStatus extends ApiIntegrationEvent {
  const CheckApiStatus();
}

class TestApiConnection extends ApiIntegrationEvent {
  const TestApiConnection();
}

class UpdateApiConfig extends ApiIntegrationEvent {
  final Map<String, dynamic> newConfig;

  const UpdateApiConfig(this.newConfig);

  @override
  List<Object?> get props => [newConfig];
}

class RecordApiRequest extends ApiIntegrationEvent {
  final bool success;
  final int responseTime;
  final String? error;

  const RecordApiRequest({
    required this.success,
    required this.responseTime,
    this.error,
  });

  @override
  List<Object?> get props => [success, responseTime, error];
}

class ResetApiMetrics extends ApiIntegrationEvent {
  const ResetApiMetrics();
}

class StartMonitoring extends ApiIntegrationEvent {
  final int interval;

  const StartMonitoring({this.interval = 60000});

  @override
  List<Object?> get props => [interval];
}

class StopMonitoring extends ApiIntegrationEvent {
  const StopMonitoring();
}

class LoadSavedConfig extends ApiIntegrationEvent {
  const LoadSavedConfig();
}

class _MonitoringTick extends ApiIntegrationEvent {
  const _MonitoringTick();
}

class _HealthCheckTick extends ApiIntegrationEvent {
  const _HealthCheckTick();
}

// ============================================================================
// STATES
// ============================================================================

class ApiIntegrationState extends Equatable {
  final ApiStatus apiStatus;
  final ApiConfig apiConfig;
  final ApiMetrics apiMetrics;
  final String connectionQuality;
  final bool isMonitoring;
  final String? error;

  const ApiIntegrationState({
    required this.apiStatus,
    required this.apiConfig,
    required this.apiMetrics,
    this.connectionQuality = 'unknown',
    this.isMonitoring = false,
    this.error,
  });

  // Initial state
  factory ApiIntegrationState.initial() {
    return ApiIntegrationState(
      apiStatus: ApiStatus.initial(),
      apiConfig: ApiConfig.initial(),
      apiMetrics: ApiMetrics.initial(),
      connectionQuality: 'unknown',
      isMonitoring: false,
    );
  }

  // Connection status for display
  String get connectionStatus {
    if (!apiStatus.connected) return 'disconnected';

    switch (connectionQuality) {
      case 'excellent':
        return 'excellent';
      case 'good':
        return 'connected';
      case 'poor':
        return 'poor';
      default:
        return 'unknown';
    }
  }

  // Connection details
  Map<String, dynamic> get connectionDetails => {
        'api': apiStatus.connected,
        'endpoint': apiStatus.endpoint,
        'hasApiKey': apiStatus.hasApiKey,
        'responseTime': apiStatus.responseTime,
        'lastError': apiStatus.lastError,
        'quality': connectionQuality,
        'monitoring': isMonitoring,
      };

  // Helper getters
  bool get isConnected => apiStatus.connected;
  bool get hasApiKey => apiStatus.hasApiKey;
  bool get isEnabled => apiConfig.enabled;
  bool get shouldFallback => !apiStatus.connected && apiConfig.fallbackToLocal;

  // API health summary
  Map<String, dynamic> get apiHealthSummary {
    final successRate = apiMetrics.totalRequests > 0
        ? (apiMetrics.successfulRequests / apiMetrics.totalRequests * 100)
        : 0.0;

    final recentRequests = apiMetrics.requestHistory.length > 10
        ? apiMetrics.requestHistory.sublist(apiMetrics.requestHistory.length - 10)
        : apiMetrics.requestHistory;

    final recentSuccessRate = recentRequests.isNotEmpty
        ? (recentRequests.where((r) => r['success'] == true).length /
                recentRequests.length *
                100)
        : 0.0;

    return {
      'overall': {
        'successRate': double.parse(successRate.toStringAsFixed(1)),
        'totalRequests': apiMetrics.totalRequests,
        'averageResponseTime': apiMetrics.averageResponseTime,
      },
      'recent': {
        'successRate': double.parse(recentSuccessRate.toStringAsFixed(1)),
        'requestCount': recentRequests.length,
      },
      'status': apiStatus.connected ? 'online' : 'offline',
      'quality': connectionQuality,
      'lastCheck': apiStatus.timestamp,
    };
  }

  ApiIntegrationState copyWith({
    ApiStatus? apiStatus,
    ApiConfig? apiConfig,
    ApiMetrics? apiMetrics,
    String? connectionQuality,
    bool? isMonitoring,
    String? error,
  }) {
    return ApiIntegrationState(
      apiStatus: apiStatus ?? this.apiStatus,
      apiConfig: apiConfig ?? this.apiConfig,
      apiMetrics: apiMetrics ?? this.apiMetrics,
      connectionQuality: connectionQuality ?? this.connectionQuality,
      isMonitoring: isMonitoring ?? this.isMonitoring,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
        apiStatus,
        apiConfig,
        apiMetrics,
        connectionQuality,
        isMonitoring,
        error,
      ];
}

// ============================================================================
// BLOC
// ============================================================================

class ApiIntegrationBloc extends Bloc<ApiIntegrationEvent, ApiIntegrationState> {
  final ApiRepository _apiRepository;
  final EncryptedStorageLocalDataSource _encryptedStorage;

  Timer? _monitoringTimer;
  Timer? _healthCheckTimer;

  ApiIntegrationBloc({
    required ApiRepository apiRepository,
    required EncryptedStorageLocalDataSource encryptedStorage,
  })  : _apiRepository = apiRepository,
        _encryptedStorage = encryptedStorage,
        super(ApiIntegrationState.initial()) {
    on<CheckApiStatus>(_onCheckApiStatus);
    on<TestApiConnection>(_onTestApiConnection);
    on<UpdateApiConfig>(_onUpdateApiConfig);
    on<RecordApiRequest>(_onRecordApiRequest);
    on<ResetApiMetrics>(_onResetApiMetrics);
    on<StartMonitoring>(_onStartMonitoring);
    on<StopMonitoring>(_onStopMonitoring);
    on<LoadSavedConfig>(_onLoadSavedConfig);
    on<_MonitoringTick>(_onMonitoringTick);
    on<_HealthCheckTick>(_onHealthCheckTick);

    // Load saved config and check status on initialization
    add(const LoadSavedConfig());
    add(const CheckApiStatus());
  }

  // --- Check API status ---
  Future<void> _onCheckApiStatus(
    CheckApiStatus event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    final startTime = DateTime.now();

    try {
      final status = await _apiRepository.getApiStatus();
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      final updatedStatus = status.copyWith(
        lastError: null,
        responseTime: responseTime,
        lastSuccessTime:
            status.connected ? DateTime.now().toIso8601String() : status.lastSuccessTime,
      );

      // Update connection quality based on response time
      String quality;
      if (status.connected) {
        if (responseTime < 1000) {
          quality = 'excellent';
        } else if (responseTime < 3000) {
          quality = 'good';
        } else {
          quality = 'poor';
        }
      } else {
        quality = 'offline';
      }

      emit(state.copyWith(
        apiStatus: updatedStatus,
        connectionQuality: quality,
      ));
    } catch (error) {
      final responseTime = DateTime.now().difference(startTime).inMilliseconds;

      final updatedStatus = state.apiStatus.copyWith(
        connected: false,
        lastError: error.toString(),
        timestamp: DateTime.now().toIso8601String(),
        responseTime: responseTime,
      );

      // Track downtime event
      final downtimeEvent = {
        'timestamp': DateTime.now().toIso8601String(),
        'error': error.toString(),
        'duration': responseTime,
      };

      final updatedMetrics = state.apiMetrics.copyWith(
        downtimeEvents: [
          ...state.apiMetrics.downtimeEvents.length >= 10
              ? state.apiMetrics.downtimeEvents.sublist(1)
              : state.apiMetrics.downtimeEvents,
          downtimeEvent,
        ],
      );

      emit(state.copyWith(
        apiStatus: updatedStatus,
        connectionQuality: 'offline',
        apiMetrics: updatedMetrics,
        error: error.toString(),
      ));
    }
  }

  // --- Test API connectivity ---
  Future<void> _onTestApiConnection(
    TestApiConnection event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    try {
      final isConnected = await _apiRepository.testApiConnection();

      if (isConnected) {
        emit(state.copyWith(
          apiStatus: state.apiStatus.copyWith(
            connected: true,
            lastError: null,
            lastSuccessTime: DateTime.now().toIso8601String(),
          ),
          connectionQuality: 'good',
        ));
      } else {
        emit(state.copyWith(
          apiStatus: state.apiStatus.copyWith(
            connected: false,
            lastError: 'Connection test failed',
          ),
          connectionQuality: 'offline',
        ));
      }
    } catch (error) {
      emit(state.copyWith(
        apiStatus: state.apiStatus.copyWith(
          connected: false,
          lastError: error.toString(),
        ),
        connectionQuality: 'offline',
        error: error.toString(),
      ));
    }
  }

  // --- Update API configuration ---
  Future<void> _onUpdateApiConfig(
    UpdateApiConfig event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    final updatedConfig = state.apiConfig.copyWithMap(event.newConfig);

    // Persist certain config to EncryptedStorage
    try {
      await _encryptedStorage.storeEncryptedData(
        'ocean-api-config',
        {
          'timeout': updatedConfig.timeout,
          'retries': updatedConfig.retries,
          'fallbackToLocal': updatedConfig.fallbackToLocal,
        },
      );
    } catch (error) {
      print('Failed to persist API config: $error');
    }

    emit(state.copyWith(apiConfig: updatedConfig));

    // Restart monitoring if enabled state changed
    if (event.newConfig.containsKey('enabled')) {
      if (updatedConfig.enabled && !state.isMonitoring) {
        add(const StartMonitoring());
      } else if (!updatedConfig.enabled && state.isMonitoring) {
        add(const StopMonitoring());
      }
    }
  }

  // --- Record API request metrics ---
  Future<void> _onRecordApiRequest(
    RecordApiRequest event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    final requestRecord = {
      'timestamp': DateTime.now().toIso8601String(),
      'success': event.success,
      'responseTime': event.responseTime,
      'error': event.error,
    };

    final newHistory = [
      ...state.apiMetrics.requestHistory.length >= 100
          ? state.apiMetrics.requestHistory.sublist(1)
          : state.apiMetrics.requestHistory,
      requestRecord,
    ];

    final totalRequests = state.apiMetrics.totalRequests + 1;
    final successfulRequests =
        state.apiMetrics.successfulRequests + (event.success ? 1 : 0);
    final failedRequests = state.apiMetrics.failedRequests + (event.success ? 0 : 1);

    // Calculate average response time
    final successfulResponses =
        newHistory.where((r) => r['success'] == true && r['responseTime'] != null).toList();
    final averageResponseTime = successfulResponses.isNotEmpty
        ? (successfulResponses.fold<int>(
                0, (sum, r) => sum + (r['responseTime'] as int? ?? 0)) /
            successfulResponses.length)
        : 0.0;

    final updatedMetrics = state.apiMetrics.copyWith(
      totalRequests: totalRequests,
      successfulRequests: successfulRequests,
      failedRequests: failedRequests,
      averageResponseTime: averageResponseTime.round(),
      lastRequestTime: DateTime.now().toIso8601String(),
      requestHistory: newHistory,
    );

    emit(state.copyWith(apiMetrics: updatedMetrics));
  }

  // --- Reset API metrics ---
  Future<void> _onResetApiMetrics(
    ResetApiMetrics event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    emit(state.copyWith(apiMetrics: ApiMetrics.initial()));
  }

  // --- Start monitoring ---
  Future<void> _onStartMonitoring(
    StartMonitoring event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    if (state.isMonitoring) return;

    emit(state.copyWith(isMonitoring: true));

    // Health check at specified interval
    _healthCheckTimer = Timer.periodic(
      Duration(milliseconds: event.interval),
      (_) => add(const _HealthCheckTick()),
    );

    // Detailed monitoring every 5x the interval
    _monitoringTimer = Timer.periodic(
      Duration(milliseconds: event.interval * 5),
      (_) => add(const _MonitoringTick()),
    );
  }

  // --- Stop monitoring ---
  Future<void> _onStopMonitoring(
    StopMonitoring event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    _monitoringTimer?.cancel();
    _monitoringTimer = null;

    emit(state.copyWith(isMonitoring: false));
  }

  // --- Load saved configuration ---
  Future<void> _onLoadSavedConfig(
    LoadSavedConfig event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    try {
      final savedConfig = await _encryptedStorage.getEncryptedData('ocean-api-config');
      if (savedConfig != null) {
        final updatedConfig = state.apiConfig.copyWithMap(savedConfig);
        emit(state.copyWith(apiConfig: updatedConfig));
      }
    } catch (error) {
      print('Failed to load saved API config: $error');
    }
  }

  // --- Monitoring tick (detailed check) ---
  Future<void> _onMonitoringTick(
    _MonitoringTick event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    add(const TestApiConnection());
  }

  // --- Health check tick ---
  Future<void> _onHealthCheckTick(
    _HealthCheckTick event,
    Emitter<ApiIntegrationState> emit,
  ) async {
    add(const CheckApiStatus());
  }

  @override
  Future<void> close() {
    _healthCheckTimer?.cancel();
    _monitoringTimer?.cancel();
    return super.close();
  }
}

// ============================================================================
// FILE: lib/domain/entities/api_status.dart
// ============================================================================

class ApiStatus extends Equatable {
  final bool connected;
  final String endpoint;
  final String? timestamp;
  final bool hasApiKey;
  final String? lastError;
  final String? lastSuccessTime;
  final int? responseTime;

  const ApiStatus({
    required this.connected,
    required this.endpoint,
    this.timestamp,
    required this.hasApiKey,
    this.lastError,
    this.lastSuccessTime,
    this.responseTime,
  });

  factory ApiStatus.initial() {
    return ApiStatus(
      connected: false,
      endpoint: '',
      timestamp: null,
      hasApiKey: false,
      lastError: null,
      lastSuccessTime: null,
      responseTime: null,
    );
  }

  ApiStatus copyWith({
    bool? connected,
    String? endpoint,
    String? timestamp,
    bool? hasApiKey,
    String? lastError,
    String? lastSuccessTime,
    int? responseTime,
  }) {
    return ApiStatus(
      connected: connected ?? this.connected,
      endpoint: endpoint ?? this.endpoint,
      timestamp: timestamp ?? this.timestamp,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      lastError: lastError,
      lastSuccessTime: lastSuccessTime ?? this.lastSuccessTime,
      responseTime: responseTime ?? this.responseTime,
    );
  }

  @override
  List<Object?> get props => [
        connected,
        endpoint,
        timestamp,
        hasApiKey,
        lastError,
        lastSuccessTime,
        responseTime,
      ];
}

// ============================================================================
// FILE: lib/domain/entities/api_config.dart
// ============================================================================

class ApiConfig extends Equatable {
  final bool enabled;
  final int timeout;
  final int retries;
  final bool fallbackToLocal;
  final bool autoRetry;
  final int retryDelay;
  final int maxRetryDelay;

  const ApiConfig({
    required this.enabled,
    required this.timeout,
    required this.retries,
    required this.fallbackToLocal,
    required this.autoRetry,
    required this.retryDelay,
    required this.maxRetryDelay,
  });

  factory ApiConfig.initial() {
    return const ApiConfig(
      enabled: true,
      timeout: 10000,
      retries: 2,
      fallbackToLocal: true,
      autoRetry: true,
      retryDelay: 1000,
      maxRetryDelay: 8000,
    );
  }

  ApiConfig copyWith({
    bool? enabled,
    int? timeout,
    int? retries,
    bool? fallbackToLocal,
    bool? autoRetry,
    int? retryDelay,
    int? maxRetryDelay,
  }) {
    return ApiConfig(
      enabled: enabled ?? this.enabled,
      timeout: timeout ?? this.timeout,
      retries: retries ?? this.retries,
      fallbackToLocal: fallbackToLocal ?? this.fallbackToLocal,
      autoRetry: autoRetry ?? this.autoRetry,
      retryDelay: retryDelay ?? this.retryDelay,
      maxRetryDelay: maxRetryDelay ?? this.maxRetryDelay,
    );
  }

  ApiConfig copyWithMap(Map<String, dynamic> map) {
    return ApiConfig(
      enabled: map['enabled'] ?? enabled,
      timeout: map['timeout'] ?? timeout,
      retries: map['retries'] ?? retries,
      fallbackToLocal: map['fallbackToLocal'] ?? fallbackToLocal,
      autoRetry: map['autoRetry'] ?? autoRetry,
      retryDelay: map['retryDelay'] ?? retryDelay,
      maxRetryDelay: map['maxRetryDelay'] ?? maxRetryDelay,
    );
  }

  @override
  List<Object?> get props => [
        enabled,
        timeout,
        retries,
        fallbackToLocal,
        autoRetry,
        retryDelay,
        maxRetryDelay,
      ];
}

// ============================================================================
// FILE: lib/domain/entities/api_metrics.dart
// ============================================================================

class ApiMetrics extends Equatable {
  final int totalRequests;
  final int successfulRequests;
  final int failedRequests;
  final int averageResponseTime;
  final String? lastRequestTime;
  final int uptime;
  final List<Map<String, dynamic>> downtimeEvents;
  final List<Map<String, dynamic>> requestHistory;

  const ApiMetrics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageResponseTime,
    this.lastRequestTime,
    required this.uptime,
    required this.downtimeEvents,
    required this.requestHistory,
  });

  factory ApiMetrics.initial() {
    return const ApiMetrics(
      totalRequests: 0,
      successfulRequests: 0,
      failedRequests: 0,
      averageResponseTime: 0,
      lastRequestTime: null,
      uptime: 0,
      downtimeEvents: [],
      requestHistory: [],
    );
  }

  ApiMetrics copyWith({
    int? totalRequests,
    int? successfulRequests,
    int? failedRequests,
    int? averageResponseTime,
    String? lastRequestTime,
    int? uptime,
    List<Map<String, dynamic>>? downtimeEvents,
    List<Map<String, dynamic>>? requestHistory,
  }) {
    return ApiMetrics(
      totalRequests: totalRequests ?? this.totalRequests,
      successfulRequests: successfulRequests ?? this.successfulRequests,
      failedRequests: failedRequests ?? this.failedRequests,
      averageResponseTime: averageResponseTime ?? this.averageResponseTime,
      lastRequestTime: lastRequestTime ?? this.lastRequestTime,
      uptime: uptime ?? this.uptime,
      downtimeEvents: downtimeEvents ?? this.downtimeEvents,
      requestHistory: requestHistory ?? this.requestHistory,
    );
  }

  @override
  List<Object?> get props => [
        totalRequests,
        successfulRequests,
        failedRequests,
        averageResponseTime,
        lastRequestTime,
        uptime,
        downtimeEvents,
        requestHistory,
      ];
}

// ============================================================================
// FILE: lib/domain/repositories/api_repository.dart
// ============================================================================

abstract class ApiRepository {
  /// Get current API status
  Future<ApiStatus> getApiStatus();

  /// Test API connection
  Future<bool> testApiConnection();
}

// ============================================================================
// FILE: lib/data/repositories/api_repository_impl.dart
// ============================================================================

import '../../domain/entities/api_status.dart';
import '../../domain/repositories/api_repository.dart';
import '../datasources/remote/api_remote_datasource.dart';

class ApiRepositoryImpl implements ApiRepository {
  final ApiRemoteDataSource _remoteDataSource;

  ApiRepositoryImpl(this._remoteDataSource);

  @override
  Future<ApiStatus> getApiStatus() async {
    try {
      final statusModel = await _remoteDataSource.getApiStatus();
      return ApiStatus(
        connected: statusModel['connected'] ?? false,
        endpoint: statusModel['endpoint'] ?? '',
        timestamp: statusModel['timestamp'],
        hasApiKey: statusModel['hasApiKey'] ?? false,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> testApiConnection() async {
    try {
      return await _remoteDataSource.testApiConnection();
    } catch (e) {
      rethrow;
    }
  }
}

// ============================================================================
// FILE: lib/data/datasources/remote/api_remote_datasource.dart
// ============================================================================

import 'package:dio/dio.dart';

abstract class ApiRemoteDataSource {
  Future<Map<String, dynamic>> getApiStatus();
  Future<bool> testApiConnection();
}

class ApiRemoteDataSourceImpl implements ApiRemoteDataSource {
  final Dio _dio;
  final String Function() _getToken;

  ApiRemoteDataSourceImpl(this._dio, this._getToken);

  @override
  Future<Map<String, dynamic>> getApiStatus() async {
    try {
      final token = _getToken();
      final response = await _dio.get(
        '/api/status',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      return {
        'connected': response.statusCode == 200,
        'endpoint': response.data['endpoint'] ?? '',
        'timestamp': DateTime.now().toIso8601String(),
        'hasApiKey': response.data['hasApiKey'] ?? false,
      };
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> testApiConnection() async {
    try {
      final token = _getToken();
      final response = await _dio.get(
        '/api/test',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

// ============================================================================
// FILE: lib/data/datasources/local/encrypted_storage_local_datasource.dart
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';

class EncryptedStorageLocalDataSource {
  final SharedPreferences _sharedPreferences;
  final String _encryptionKey;

  EncryptedStorageLocalDataSource(
    this._sharedPreferences,
    this._encryptionKey,
  );

  /// Store encrypted data
  Future<void> storeEncryptedData(String key, Map<String, dynamic> data) async {
    try {
      final jsonString = jsonEncode(data);
      final encrypted = _encrypt(jsonString);
      await _sharedPreferences.setString(key, encrypted);
    } catch (e) {
      throw Exception('Failed to store encrypted data: $e');
    }
  }

  /// Get encrypted data
  Future<Map<String, dynamic>?> getEncryptedData(String key) async {
    try {
      final encrypted = _sharedPreferences.getString(key);
      if (encrypted == null) return null;

      final decrypted = _decrypt(encrypted);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to get encrypted data: $e');
    }
  }

  /// Remove encrypted data
  Future<void> removeEncryptedData(String key) async {
    await _sharedPreferences.remove(key);
  }

  /// Simple encryption (for demonstration - use proper encryption in production)
  String _encrypt(String data) {
    final bytes = utf8.encode(data + _encryptionKey);
    final digest = sha256.convert(bytes);
    return base64Encode(utf8.encode(data)) + '.' + digest.toString();
  }

  /// Simple decryption (for demonstration - use proper encryption in production)
  String _decrypt(String encrypted) {
    final parts = encrypted.split('.');
    if (parts.length != 2) throw Exception('Invalid encrypted data');
    return utf8.decode(base64Decode(parts[0]));
  }
}
