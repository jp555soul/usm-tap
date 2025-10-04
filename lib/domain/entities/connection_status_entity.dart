import 'package:equatable/equatable.dart';

enum ConnectionState {
  disconnected,
  connecting,
  connected,
  error,
  reconnecting,
}

class ConnectionStatusEntity extends Equatable {
  final ConnectionState state;
  final String? message;
  final DateTime? connectedAt;
  final DateTime? lastActivity;
  final String? endpoint;
  final int? retryCount;
  final Map<String, dynamic>? metadata;

  const ConnectionStatusEntity({
    required this.state,
    this.message,
    this.connectedAt,
    this.lastActivity,
    this.endpoint,
    this.retryCount,
    this.metadata,
  });

  bool get isConnected => state == ConnectionState.connected;
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
      ];

  ConnectionStatusEntity copyWith({
    ConnectionState? state,
    String? message,
    DateTime? connectedAt,
    DateTime? lastActivity,
    String? endpoint,
    int? retryCount,
    Map<String, dynamic>? metadata,
  }) {
    return ConnectionStatusEntity(
      state: state ?? this.state,
      message: message ?? this.message,
      connectedAt: connectedAt ?? this.connectedAt,
      lastActivity: lastActivity ?? this.lastActivity,
      endpoint: endpoint ?? this.endpoint,
      retryCount: retryCount ?? this.retryCount,
      metadata: metadata ?? this.metadata,
    );
  }
}