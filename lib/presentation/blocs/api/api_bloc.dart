// lib/presentation/blocs/api/api_bloc.dart
import 'dart:async';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Events
abstract class ApiEvent extends Equatable {
  const ApiEvent();

  @override
  List<Object?> get props => [];
}

class CheckApiHealthEvent extends ApiEvent {
  const CheckApiHealthEvent();
}

class ApiRequestStartedEvent extends ApiEvent {
  final String endpoint;

  const ApiRequestStartedEvent(this.endpoint);

  @override
  List<Object?> get props => [endpoint];
}

class ApiRequestCompletedEvent extends ApiEvent {
  final String endpoint;
  final bool success;
  final int? statusCode;

  const ApiRequestCompletedEvent({
    required this.endpoint,
    required this.success,
    this.statusCode,
  });

  @override
  List<Object?> get props => [endpoint, success, statusCode];
}

class ApiRequestFailedEvent extends ApiEvent {
  final String endpoint;
  final String error;

  const ApiRequestFailedEvent({
    required this.endpoint,
    required this.error,
  });

  @override
  List<Object?> get props => [endpoint, error];
}

class CheckNetworkConnectivityEvent extends ApiEvent {
  const CheckNetworkConnectivityEvent();
}

class NetworkConnectivityChangedEvent extends ApiEvent {
  final bool isConnected;

  const NetworkConnectivityChangedEvent(this.isConnected);

  @override
  List<Object?> get props => [isConnected];
}

class RetryFailedRequestsEvent extends ApiEvent {
  const RetryFailedRequestsEvent();
}

class ClearApiErrorsEvent extends ApiEvent {
  const ClearApiErrorsEvent();
}

// States
abstract class ApiState extends Equatable {
  const ApiState();

  @override
  List<Object?> get props => [];
}

class ApiInitial extends ApiState {
  const ApiInitial();
}

class ApiHealthy extends ApiState {
  final bool isHealthy;
  final bool isConnected;
  final int activeRequests;
  final List<String> recentErrors;
  final Map<String, int> requestCounts;
  final DateTime lastHealthCheck;

  const ApiHealthy({
    required this.isHealthy,
    required this.isConnected,
    this.activeRequests = 0,
    this.recentErrors = const [],
    this.requestCounts = const {},
    required this.lastHealthCheck,
  });

  @override
  List<Object?> get props => [
        isHealthy,
        isConnected,
        activeRequests,
        recentErrors,
        requestCounts,
        lastHealthCheck,
      ];

  ApiHealthy copyWith({
    bool? isHealthy,
    bool? isConnected,
    int? activeRequests,
    List<String>? recentErrors,
    Map<String, int>? requestCounts,
    DateTime? lastHealthCheck,
  }) {
    return ApiHealthy(
      isHealthy: isHealthy ?? this.isHealthy,
      isConnected: isConnected ?? this.isConnected,
      activeRequests: activeRequests ?? this.activeRequests,
      recentErrors: recentErrors ?? this.recentErrors,
      requestCounts: requestCounts ?? this.requestCounts,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
    );
  }
}

class ApiRequestInProgress extends ApiState {
  final String endpoint;
  final int activeRequests;

  const ApiRequestInProgress({
    required this.endpoint,
    required this.activeRequests,
  });

  @override
  List<Object?> get props => [endpoint, activeRequests];
}

class ApiError extends ApiState {
  final String message;
  final bool isConnected;
  final List<String> recentErrors;

  const ApiError({
    required this.message,
    required this.isConnected,
    this.recentErrors = const [],
  });

  @override
  List<Object?> get props => [message, isConnected, recentErrors];
}

class NetworkDisconnected extends ApiState {
  const NetworkDisconnected();
}

// BLoC
class ApiBloc extends Bloc<ApiEvent, ApiState> {
  final Connectivity _connectivity;
  StreamSubscription? _connectivitySubscription;

  int _activeRequests = 0;
  List<String> _recentErrors = [];
  Map<String, int> _requestCounts = {};
  bool _isConnected = true;

  ApiBloc({Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity(),
        super(const ApiInitial()) {
    on<CheckApiHealthEvent>(_onCheckHealth);
    on<ApiRequestStartedEvent>(_onRequestStarted);
    on<ApiRequestCompletedEvent>(_onRequestCompleted);
    on<ApiRequestFailedEvent>(_onRequestFailed);
    on<CheckNetworkConnectivityEvent>(_onCheckConnectivity);
    on<NetworkConnectivityChangedEvent>(_onConnectivityChanged);
    on<RetryFailedRequestsEvent>(_onRetryFailed);
    on<ClearApiErrorsEvent>(_onClearErrors);

    _initConnectivityListener();
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        final isConnected = result != ConnectivityResult.none;
        add(NetworkConnectivityChangedEvent(isConnected));
      },
    );
  }

  Future<void> _onCheckHealth(
    CheckApiHealthEvent event,
    Emitter<ApiState> emit,
  ) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      emit(ApiHealthy(
        isHealthy: true,
        isConnected: isConnected,
        activeRequests: _activeRequests,
        recentErrors: _recentErrors,
        requestCounts: _requestCounts,
        lastHealthCheck: DateTime.now(),
      ));
    } catch (e) {
      emit(ApiError(
        message: 'Health check failed: ${e.toString()}',
        isConnected: _isConnected,
        recentErrors: _recentErrors,
      ));
    }
  }

  void _onRequestStarted(
    ApiRequestStartedEvent event,
    Emitter<ApiState> emit,
  ) {
    _activeRequests++;
    _requestCounts[event.endpoint] = (_requestCounts[event.endpoint] ?? 0) + 1;

    emit(ApiRequestInProgress(
      endpoint: event.endpoint,
      activeRequests: _activeRequests,
    ));
  }

  void _onRequestCompleted(
    ApiRequestCompletedEvent event,
    Emitter<ApiState> emit,
  ) {
    _activeRequests = (_activeRequests - 1).clamp(0, double.infinity).toInt();

    if (event.success) {
      emit(ApiHealthy(
        isHealthy: true,
        isConnected: _isConnected,
        activeRequests: _activeRequests,
        recentErrors: _recentErrors,
        requestCounts: _requestCounts,
        lastHealthCheck: DateTime.now(),
      ));
    }
  }

  void _onRequestFailed(
    ApiRequestFailedEvent event,
    Emitter<ApiState> emit,
  ) {
    _activeRequests = (_activeRequests - 1).clamp(0, double.infinity).toInt();

    // Add to recent errors (keep last 10)
    _recentErrors = [
      '${event.endpoint}: ${event.error}',
      ..._recentErrors,
    ].take(10).toList();

    emit(ApiError(
      message: 'Request failed: ${event.error}',
      isConnected: _isConnected,
      recentErrors: _recentErrors,
    ));
  }

  Future<void> _onCheckConnectivity(
    CheckNetworkConnectivityEvent event,
    Emitter<ApiState> emit,
  ) async {
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isConnected = connectivityResult != ConnectivityResult.none;

      _isConnected = isConnected;

      if (!isConnected) {
        emit(const NetworkDisconnected());
      } else {
        emit(ApiHealthy(
          isHealthy: true,
          isConnected: true,
          activeRequests: _activeRequests,
          recentErrors: _recentErrors,
          requestCounts: _requestCounts,
          lastHealthCheck: DateTime.now(),
        ));
      }
    } catch (e) {
      emit(ApiError(
        message: 'Connectivity check failed: ${e.toString()}',
        isConnected: _isConnected,
        recentErrors: _recentErrors,
      ));
    }
  }

  void _onConnectivityChanged(
    NetworkConnectivityChangedEvent event,
    Emitter<ApiState> emit,
  ) {
    _isConnected = event.isConnected;

    if (!event.isConnected) {
      emit(const NetworkDisconnected());
    } else {
      emit(ApiHealthy(
        isHealthy: true,
        isConnected: true,
        activeRequests: _activeRequests,
        recentErrors: _recentErrors,
        requestCounts: _requestCounts,
        lastHealthCheck: DateTime.now(),
      ));
    }
  }

  void _onRetryFailed(
    RetryFailedRequestsEvent event,
    Emitter<ApiState> emit,
  ) {
    // Clear recent errors and reset state
    _recentErrors = [];
    
    emit(ApiHealthy(
      isHealthy: true,
      isConnected: _isConnected,
      activeRequests: _activeRequests,
      recentErrors: [],
      requestCounts: _requestCounts,
      lastHealthCheck: DateTime.now(),
    ));
  }

  void _onClearErrors(
    ClearApiErrorsEvent event,
    Emitter<ApiState> emit,
  ) {
    _recentErrors = [];

    emit(ApiHealthy(
      isHealthy: true,
      isConnected: _isConnected,
      activeRequests: _activeRequests,
      recentErrors: [],
      requestCounts: _requestCounts,
      lastHealthCheck: DateTime.now(),
    ));
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}