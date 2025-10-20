import 'package:equatable/equatable.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
  excellent,
  good,
  fair,
  poor,
}

class ConnectionStatusEntity extends Equatable {
  final ConnectionState state;
  final String? message;
  final DateTime? connectedAt;
  final DateTime? lastActivity;
  final String endpoint;
  final int? retryCount;
  final Map<String, dynamic>? metadata;
  final bool hasApiKey;
  final bool connected;

  const ConnectionStatusEntity({
    required this.state,
    this.message,
    this.connectedAt,
    this.lastActivity,
    this.endpoint = '',
    this.retryCount,
    this.metadata,
    this.hasApiKey = false,
    this.connected = false,
  });

  bool get isConnected => state == ConnectionState.connected || 
                          state == ConnectionState.excellent ||
                          state == ConnectionState.good ||
                          state == ConnectionState.fair ||
                          state == ConnectionState.poor;
  bool get isConnecting => state == ConnectionState.connecting || 
                          state == ConnectionState.reconnecting;
  bool get hasError => state == ConnectionState.error;

  @override
  List<Object?> get props => [
        state,
        message,
        connectedAt,
        lastActivity,
        endpoint,
        retryCount,
        metadata,
        hasApiKey,
        connected,
      ];

  ConnectionStatusEntity copyWith({
    ConnectionState? state,
    String? message,
    DateTime? connectedAt,
    DateTime? lastActivity,
    String? endpoint,
    int? retryCount,
    Map<String, dynamic>? metadata,
    bool? hasApiKey,
    bool? connected,
  }) {
    return ConnectionStatusEntity(
      state: state ?? this.state,
      message: message ?? this.message,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      endpoint: endpoint ?? this.endpoint,
      retryCount: retryCount ?? this.retryCount,
      metadata: metadata ?? this.metadata,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      connected: connected ?? this.connected,
    );
  }
}