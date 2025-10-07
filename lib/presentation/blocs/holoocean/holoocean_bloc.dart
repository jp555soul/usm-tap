import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:math' as math;

import '../../../data/datasources/remote/holoocean_service_remote_datasource.dart';
import '../../../domain/usecases/holoocean/connect_holoocean_usecase.dart';
import '../../../domain/usecases/holoocean/set_target_usecase.dart';
import '../auth/auth_bloc.dart';

// EVENTS
abstract class HoloOceanEvent extends Equatable {
  const HoloOceanEvent();
  
  @override
  List<Object?> get props => [];
}

class InitializeHoloOceanEvent extends HoloOceanEvent {
  final bool autoConnect;
  const InitializeHoloOceanEvent({this.autoConnect = false});
  
  @override
  List<Object?> get props => [autoConnect];
}

class ConnectHoloOceanEvent extends HoloOceanEvent {
  const ConnectHoloOceanEvent();
}

class DisconnectHoloOceanEvent extends HoloOceanEvent {
  const DisconnectHoloOceanEvent();
}

class ReconnectHoloOceanEvent extends HoloOceanEvent {
  const ReconnectHoloOceanEvent();
}

class SetHoloOceanTargetEvent extends HoloOceanEvent {
  final double lat;
  final double lon;
  final double depth;
  final String? time;
  
  const SetHoloOceanTargetEvent({
    required this.lat,
    required this.lon,
    required this.depth,
    this.time,
  });
  
  @override
  List<Object?> get props => [lat, lon, depth, time];
}

class GetHoloOceanStatusEvent extends HoloOceanEvent {
  const GetHoloOceanStatusEvent();
}

class SubscribeHoloOceanEvent extends HoloOceanEvent {
  const SubscribeHoloOceanEvent();
}

class UnsubscribeHoloOceanEvent extends HoloOceanEvent {
  const UnsubscribeHoloOceanEvent();
}

class ClearHoloOceanErrorEvent extends HoloOceanEvent {
  const ClearHoloOceanErrorEvent();
}

class HandleHoloOceanConnectedEvent extends HoloOceanEvent {
  final Map<String, dynamic> data;
  const HandleHoloOceanConnectedEvent(this.data);
  
  @override
  List<Object?> get props => [data];
}

class HandleHoloOceanDisconnectedEvent extends HoloOceanEvent {
  final Map<String, dynamic> data;
  const HandleHoloOceanDisconnectedEvent(this.data);
  
  @override
  List<Object?> get props => [data];
}

class HandleHoloOceanStatusEvent extends HoloOceanEvent {
  final Map<String, dynamic> statusData;
  const HandleHoloOceanStatusEvent(this.statusData);
  
  @override
  List<Object?> get props => [statusData];
}

class HandleHoloOceanTargetUpdatedEvent extends HoloOceanEvent {
  final Map<String, dynamic> targetData;
  const HandleHoloOceanTargetUpdatedEvent(this.targetData);
  
  @override
  List<Object?> get props => [targetData];
}

class HandleHoloOceanErrorEvent extends HoloOceanEvent {
  final Map<String, dynamic> errorData;
  const HandleHoloOceanErrorEvent(this.errorData);
  
  @override
  List<Object?> get props => [errorData];
}

class HandleHoloOceanConnectionErrorEvent extends HoloOceanEvent {
  final Map<String, dynamic> errorData;
  const HandleHoloOceanConnectionErrorEvent(this.errorData);
  
  @override
  List<Object?> get props => [errorData];
}

// STATES
abstract class HoloOceanState extends Equatable {
  const HoloOceanState();
  
  @override
  List<Object?> get props => [];
}

class HoloOceanInitialState extends HoloOceanState {
  const HoloOceanInitialState();
}

class HoloOceanLoadedState extends HoloOceanState {
  // Connection state
  final bool isConnected;
  final bool isConnecting;
  final int reconnectAttempts;
  final String? connectionError;
  
  // Subscription state
  final bool isSubscribed;
  
  // Data state
  final Map<String, dynamic>? status;
  final Map<String, dynamic>? target;
  final Map<String, dynamic>? current;
  final Map<String, dynamic>? holoOceanState;
  final String? lastUpdated;
  
  // Error state
  final String? error;
  final String? serverError;
  
  // Command state
  final bool isSettingTarget;
  final bool isGettingStatus;
  
  const HoloOceanLoadedState({
    required this.isConnected,
    required this.isConnecting,
    required this.reconnectAttempts,
    this.connectionError,
    required this.isSubscribed,
    this.status,
    this.target,
    this.current,
    this.holoOceanState,
    this.lastUpdated,
    this.error,
    this.serverError,
    required this.isSettingTarget,
    required this.isGettingStatus,
  });
  
  // Derived state
  bool get isHoloOceanRunning => holoOceanState?['running'] as bool? ?? false;
  int get tickCount => holoOceanState?['tick_count'] as int? ?? 0;
  String? get holoOceanError => holoOceanState?['last_error'] as String?;
  
  bool get hasTarget =>
      target != null &&
      target!['lat'] is num &&
      target!['lon'] is num;
  
  bool get hasCurrent =>
      current != null &&
      current!['lat'] is num &&
      current!['lon'] is num;
  
  double? get distanceToTarget {
    if (!hasTarget || !hasCurrent) return null;
    
    final lat1 = (current!['lat'] as num).toDouble();
    final lon1 = (current!['lon'] as num).toDouble();
    final lat2 = (target!['lat'] as num).toDouble();
    final lon2 = (target!['lon'] as num).toDouble();
    
    return _calculateDistance(lat1, lon1, lat2, lon2);
  }
  
  double? get depthDifference {
    if (!hasTarget || !hasCurrent) return null;
    if (current!['depth'] == null || target!['depth'] == null) return null;
    
    final currentDepth = (current!['depth'] as num).toDouble();
    final targetDepth = (target!['depth'] as num).toDouble();
    
    return (currentDepth - targetDepth).abs();
  }
  
  bool get isAtTarget {
    final distance = distanceToTarget;
    final depthDiff = depthDifference;
    if (distance == null || depthDiff == null) return false;
    return distance < 10 && depthDiff < 1; // Within 10m horizontally and 1m vertically
  }
  
  Map<String, dynamic> get connectionStatus => {
    'isConnected': isConnected,
    'isConnecting': isConnecting,
    'reconnectAttempts': reconnectAttempts,
    'maxAttempts': 10, // From HoloOceanService
    'readyState': isConnected ? 'OPEN' : 'CLOSED',
  };
  
  Map<String, dynamic> get summary => {
    'connection': connectionStatus,
    'subscription': {'isSubscribed': isSubscribed},
    'simulation': {
      'isRunning': isHoloOceanRunning,
      'tickCount': tickCount,
      'error': holoOceanError,
    },
    'position': {
      'hasTarget': hasTarget,
      'hasCurrent': hasCurrent,
      'target': target,
      'current': current,
      'distanceToTarget': distanceToTarget,
      'depthDifference': depthDifference,
      'isAtTarget': isAtTarget,
    },
    'lastUpdated': lastUpdated,
    'errors': {
      'connection': connectionError,
      'general': error,
      'server': serverError,
    },
  };
  
  // Calculate distance between two coordinates (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0; // Earth's radius in meters
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final deltaPhi = (lat2 - lat1) * math.pi / 180;
    final deltaLambda = (lon2 - lon1) * math.pi / 180;
    
    final a = math.sin(deltaPhi / 2) * math.sin(deltaPhi / 2) +
              math.cos(phi1) * math.cos(phi2) *
              math.sin(deltaLambda / 2) * math.sin(deltaLambda / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return R * c;
  }
  
  @override
  List<Object?> get props => [
    isConnected,
    isConnecting,
    reconnectAttempts,
    connectionError,
    isSubscribed,
    status,
    target,
    current,
    holoOceanState,
    lastUpdated,
    error,
    serverError,
    isSettingTarget,
    isGettingStatus,
  ];
  
  HoloOceanLoadedState copyWith({
    bool? isConnected,
    bool? isConnecting,
    int? reconnectAttempts,
    String? connectionError,
    bool? isSubscribed,
    Map<String, dynamic>? status,
    Map<String, dynamic>? target,
    Map<String, dynamic>? current,
    Map<String, dynamic>? holoOceanState,
    String? lastUpdated,
    String? error,
    String? serverError,
    bool? isSettingTarget,
    bool? isGettingStatus,
  }) {
    return HoloOceanLoadedState(
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      connectionError: connectionError ?? this.connectionError,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      status: status ?? this.status,
      target: target ?? this.target,
      current: current ?? this.current,
      holoOceanState: holoOceanState ?? this.holoOceanState,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      error: error ?? this.error,
      serverError: serverError ?? this.serverError,
      isSettingTarget: isSettingTarget ?? this.isSettingTarget,
      isGettingStatus: isGettingStatus ?? this.isGettingStatus,
    );
  }
}

// BLOC
class HoloOceanBloc extends Bloc<HoloOceanEvent, HoloOceanState> {
  final HoloOceanServiceRemoteDataSource _holoOceanService;
  final AuthBloc _authBloc;
  
  StreamSubscription? _connectedSubscription;
  StreamSubscription? _disconnectedSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _targetUpdatedSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _connectionErrorSubscription;
  
  HoloOceanBloc({
    required HoloOceanServiceRemoteDataSource holoOceanService,
    required AuthBloc authBloc,
  }) : _holoOceanService = holoOceanService,
       _authBloc = authBloc,
       super(const HoloOceanInitialState()) {
    
    on<InitializeHoloOceanEvent>(_onInitialize);
    on<ConnectHoloOceanEvent>(_onConnect);
    on<DisconnectHoloOceanEvent>(_onDisconnect);
    on<ReconnectHoloOceanEvent>(_onReconnect);
    on<SetHoloOceanTargetEvent>(_onSetTarget);
    on<GetHoloOceanStatusEvent>(_onGetStatus);
    on<SubscribeHoloOceanEvent>(_onSubscribe);
    on<UnsubscribeHoloOceanEvent>(_onUnsubscribe);
    on<ClearHoloOceanErrorEvent>(_onClearError);
    on<HandleHoloOceanConnectedEvent>(_onHandleConnected);
    on<HandleHoloOceanDisconnectedEvent>(_onHandleDisconnected);
    on<HandleHoloOceanStatusEvent>(_onHandleStatus);
    on<HandleHoloOceanTargetUpdatedEvent>(_onHandleTargetUpdated);
    on<HandleHoloOceanErrorEvent>(_onHandleError);
    on<HandleHoloOceanConnectionErrorEvent>(_onHandleConnectionError);
  }
  
  Future<void> _onInitialize(InitializeHoloOceanEvent event, Emitter<HoloOceanState> emit) async {
    // Setup event listeners
    _connectedSubscription = _holoOceanService.onConnected.listen((data) {
      add(HandleHoloOceanConnectedEvent(data));
    });
    
    _disconnectedSubscription = _holoOceanService.onDisconnected.listen((data) {
      add(HandleHoloOceanDisconnectedEvent(data));
    });
    
    _statusSubscription = _holoOceanService.onStatus.listen((statusData) {
      add(HandleHoloOceanStatusEvent(statusData));
    });
    
    _targetUpdatedSubscription = _holoOceanService.onTargetUpdated.listen((targetData) {
      add(HandleHoloOceanTargetUpdatedEvent(targetData));
    });
    
    _errorSubscription = _holoOceanService.onError.listen((errorData) {
      add(HandleHoloOceanErrorEvent(errorData));
    });
    
    _connectionErrorSubscription = _holoOceanService.onConnectionError.listen((errorData) {
      add(HandleHoloOceanConnectionErrorEvent(errorData));
    });
    
    // Initialize state from service
    final serviceStatus = _holoOceanService.getConnectionStatus();
    final lastStatus = await _holoOceanService.getLastStatus();
    
    emit(HoloOceanLoadedState(
      isConnected: serviceStatus['isConnected'] as bool? ?? false,
      isConnecting: false,
      reconnectAttempts: serviceStatus['reconnectAttempts'] as int? ?? 0,
      isSubscribed: serviceStatus['isSubscribed'] as bool? ?? false,
      status: lastStatus,
      target: lastStatus?['target'] as Map<String, dynamic>?,
      current: lastStatus?['current'] as Map<String, dynamic>?,
      holoOceanState: lastStatus?['holoocean'] as Map<String, dynamic>?,
      lastUpdated: lastStatus?['updated_at'] as String?,
      isSettingTarget: false,
      isGettingStatus: false,
    ));
    
    // Auto-connect if requested
    if (event.autoConnect && !(serviceStatus['isConnected'] as bool? ?? false)) {
      add(const ConnectHoloOceanEvent());
    }
  }
  
  Future<void> _onConnect(ConnectHoloOceanEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      if (currentState.isConnecting || currentState.isConnected) return;
      
      emit(currentState.copyWith(
        isConnecting: true,
        connectionError: null,
        error: null,
      ));
      
      try {
        // Get token from AuthBloc
        String? token;
        if (_authBloc.state is AuthenticatedState) {
          final authState = _authBloc.state as AuthenticatedState;
          token = authState.accessToken;
        }
        
        await _holoOceanService.connect();
      } catch (error) {
        emit(currentState.copyWith(
          connectionError: error.toString(),
          isConnecting: false,
        ));
      }
    }
  }
  
  Future<void> _onDisconnect(DisconnectHoloOceanEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      await _holoOceanService.disconnect();
      
      emit(currentState.copyWith(
        isConnected: false,
        isConnecting: false,
        isSubscribed: false,
        connectionError: null,
      ));
    }
  }
  
  Future<void> _onReconnect(ReconnectHoloOceanEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      emit(currentState.copyWith(
        isConnecting: true,
        connectionError: null,
        error: null,
      ));
      
      try {
        // Get token from AuthBloc
        String? token;
        if (_authBloc.state is AuthenticatedState) {
          final authState = _authBloc.state as AuthenticatedState;
          token = authState.accessToken;
        }
        
        // Reconnect via service (Note: need to add reconnect to remote datasource interface)
        await _holoOceanService.disconnect();
        await _holoOceanService.connect();
      } catch (error) {
        emit(currentState.copyWith(
          connectionError: error.toString(),
          isConnecting: false,
        ));
      }
    }
  }
  
  Future<void> _onSetTarget(SetHoloOceanTargetEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      if (!currentState.isConnected) {
        emit(currentState.copyWith(error: 'Not connected to HoloOcean service'));
        return;
      }
      
      emit(currentState.copyWith(
        isSettingTarget: true,
        error: null,
        serverError: null,
      ));
      
      try {
        await _holoOceanService.setTarget(
          latitude: event.lat,
          longitude: event.lon,
          depth: event.depth,
          parameters: event.time != null ? {'time': event.time} : null,
        );
        emit(currentState.copyWith(isSettingTarget: false));
      } catch (error) {
        emit(currentState.copyWith(
          error: error.toString(),
          isSettingTarget: false,
        ));
      }
    }
  }
  
  Future<void> _onGetStatus(GetHoloOceanStatusEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      if (!currentState.isConnected) {
        emit(currentState.copyWith(error: 'Not connected to HoloOcean service'));
        return;
      }
      
      emit(currentState.copyWith(
        isGettingStatus: true,
        error: null,
        serverError: null,
      ));
      
      try {
        await _holoOceanService.getStatus();
        emit(currentState.copyWith(isGettingStatus: false));
      } catch (error) {
        emit(currentState.copyWith(
          error: error.toString(),
          isGettingStatus: false,
        ));
      }
    }
  }
  
  Future<void> _onSubscribe(SubscribeHoloOceanEvent event, Emitter<HoloOceanState> emit) async {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      if (!currentState.isConnected) {
        emit(currentState.copyWith(error: 'Not connected to HoloOcean service'));
        return;
      }
      
      if (currentState.isSubscribed) {
        return;
      }
      
      emit(currentState.copyWith(
        error: null,
        serverError: null,
      ));
      
      try {
        await _holoOceanService.subscribe();
        emit(currentState.copyWith(isSubscribed: true));
      } catch (error) {
        emit(currentState.copyWith(error: error.toString()));
      }
    }
  }
  
  void _onUnsubscribe(UnsubscribeHoloOceanEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      _holoOceanService.unsubscribe();
      emit(currentState.copyWith(isSubscribed: false));
    }
  }
  
  void _onClearError(ClearHoloOceanErrorEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      emit(currentState.copyWith(
        error: null,
        serverError: null,
        connectionError: null,
      ));
    }
  }
  
  void _onHandleConnected(HandleHoloOceanConnectedEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      emit(currentState.copyWith(
        isConnected: true,
        isConnecting: false,
        reconnectAttempts: 0,
        connectionError: null,
        error: null,
      ));
    }
  }
  
  void _onHandleDisconnected(HandleHoloOceanDisconnectedEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      emit(currentState.copyWith(
        isConnected: false,
        isConnecting: false,
        isSubscribed: false,
      ));
    }
  }
  
  void _onHandleStatus(HandleHoloOceanStatusEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      emit(currentState.copyWith(
        status: event.statusData,
        target: event.statusData['target'] as Map<String, dynamic>?,
        current: event.statusData['current'] as Map<String, dynamic>?,
        holoOceanState: event.statusData['holoocean'] as Map<String, dynamic>?,
        lastUpdated: event.statusData['updated_at'] as String? ?? DateTime.now().toIso8601String(),
        error: null,
      ));
    }
  }
  
  void _onHandleTargetUpdated(HandleHoloOceanTargetUpdatedEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      emit(currentState.copyWith(target: event.targetData));
    }
  }
  
  void _onHandleError(HandleHoloOceanErrorEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      
      final errorType = event.errorData['type'] as String?;
      final errorMessage = event.errorData['message'] as String?;
      
      if (errorType == 'server_error') {
        emit(currentState.copyWith(serverError: errorMessage));
      } else {
        emit(currentState.copyWith(error: errorMessage));
      }
    }
  }
  
  void _onHandleConnectionError(HandleHoloOceanConnectionErrorEvent event, Emitter<HoloOceanState> emit) {
    if (state is HoloOceanLoadedState) {
      final currentState = state as HoloOceanLoadedState;
      final serviceStatus = _holoOceanService.getConnectionStatus();
      
      emit(currentState.copyWith(
        connectionError: event.errorData['error'] as String?,
        isConnecting: false,
        reconnectAttempts: serviceStatus['reconnectAttempts'] as int? ?? 0,
      ));
    }
  }
  
  @override
  Future<void> close() {
    _connectedSubscription?.cancel();
    _disconnectedSubscription?.cancel();
    _statusSubscription?.cancel();
    _targetUpdatedSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionErrorSubscription?.cancel();
    return super.close();
  }
}