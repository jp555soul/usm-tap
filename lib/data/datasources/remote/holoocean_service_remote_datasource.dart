import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';

/// HoloOcean WebSocket Service
/// Manages WebSocket connection and communication with HoloOcean agent
class HoloOceanService {
  final String endpoint;
  WebSocketChannel? _ws;
  StreamSubscription? _wsSubscription;
  bool isConnected = false;
  bool isSubscribed = false;
  int reconnectAttempts = 0;
  final int maxReconnectAttempts = 10;
  int reconnectDelay = 1000; // Initial delay in ms
  final int maxReconnectDelay = 30000; // Max delay in ms
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool shouldReconnect = true;
  
  // Event streams
  final _connectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _targetUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionErrorController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Last known status
  Map<String, dynamic>? lastStatus;
  
  HoloOceanService(this.endpoint);
  
  /// Event streams
  Stream<Map<String, dynamic>> get onConnected => _connectedController.stream;
  Stream<Map<String, dynamic>> get onDisconnected => _disconnectedController.stream;
  Stream<Map<String, dynamic>> get onStatus => _statusController.stream;
  Stream<Map<String, dynamic>> get onTargetUpdated => _targetUpdatedController.stream;
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  Stream<Map<String, dynamic>> get onConnectionError => _connectionErrorController.stream;
  
  /// Validate coordinates and depth
  /// @param lat - Latitude
  /// @param lon - Longitude
  /// @param depth - Depth in meters
  /// @returns Validation result
  Map<String, dynamic> validateCoordinates(double lat, double lon, double depth) {
    final errors = <String>[];
    
    if (lat < -90 || lat > 90) {
      errors.add('Latitude must be a number between -90 and 90');
    }
    
    if (lon < -180 || lon > 180) {
      errors.add('Longitude must be a number between -180 and 180');
    }
    
    if (depth < -11000 || depth > 11000) {
      errors.add('Depth must be a number between -11000 and 11000 meters');
    }
    
    return {
      'isValid': errors.isEmpty,
      'errors': errors,
    };
  }
  
  /// Validate ISO-8601 time string
  /// @param timeStr - ISO-8601 time string
  /// @returns Is valid time string
  bool validateTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return true; // Optional field
    try {
      final date = DateTime.parse(timeStr);
      return timeStr.contains('T');
    } catch (e) {
      return false;
    }
  }
  
  /// Connect to WebSocket endpoint
  /// @param token - The JWT token for authentication
  /// @returns Connection future
  Future<void> connect({String? token}) async {
    shouldReconnect = true;
    final uri = token != null && token.isNotEmpty
        ? '$endpoint?token=$token'
        : endpoint;
    
    try {
      _ws = WebSocketChannel.connect(Uri.parse(uri));
      
      // Set up message listener
      _wsSubscription = _ws!.stream.listen(
        (data) {
          handleMessage(data.toString());
        },
        onError: (error) {
          debugPrint('HoloOcean WebSocket error: $error');
          _connectionErrorController.add({
            'error': error.toString(),
          });
          if (!isConnected) {
            throw Exception('Failed to connect to HoloOcean WebSocket');
          }
        },
        onDone: () {
          debugPrint('HoloOcean WebSocket disconnected');
          handleDisconnection();
        },
      );
      
      // Mark as connected after a short delay to ensure connection is established
      await Future.delayed(const Duration(milliseconds: 100));
      
      debugPrint('HoloOcean WebSocket connected');
      isConnected = true;
      reconnectAttempts = 0;
      reconnectDelay = 1000;
      _clearReconnectTimer();
      _connectedController.add({'endpoint': endpoint});
      
    } catch (error) {
      debugPrint('Failed to connect to HoloOcean: $error');
      throw Exception('Failed to connect to HoloOcean WebSocket');
    }
  }
  
  /// Handle WebSocket disconnection
  void handleDisconnection() {
    isConnected = false;
    isSubscribed = false;
    _clearPingTimer();
    _disconnectedController.add({
      'willReconnect': shouldReconnect && reconnectAttempts < maxReconnectAttempts,
    });
    
    if (shouldReconnect && reconnectAttempts < maxReconnectAttempts) {
      _scheduleReconnect();
    }
  }
  
  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    _clearReconnectTimer();
    
    reconnectAttempts++;
    final delay = math.min(
      reconnectDelay * math.pow(2, reconnectAttempts - 1).toInt(),
      maxReconnectDelay,
    );
    
    debugPrint('Scheduling HoloOcean reconnect attempt $reconnectAttempts in ${delay}ms');
    
    _reconnectTimer = Timer(Duration(milliseconds: delay), () {
      if (shouldReconnect) {
        debugPrint('Attempting HoloOcean reconnect $reconnectAttempts/$maxReconnectAttempts');
        connect().catchError((error) {
          debugPrint('Reconnection failed: $error');
        });
      }
    });
  }
  
  /// Clear reconnection timer
  void _clearReconnectTimer() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }
  
  /// Clear ping timer
  void _clearPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
  
  /// Handle incoming WebSocket messages
  /// @param data - Message data
  void handleMessage(String data) {
    try {
      final message = jsonDecode(data) as Map<String, dynamic>;
      
      // Handle different message types
      final event = message['event'] as String?;
      
      switch (event) {
        case 'target_updated':
          _targetUpdatedController.add(message['target'] as Map<String, dynamic>);
          break;
          
        case 'status':
          lastStatus = message['status'] as Map<String, dynamic>;
          _statusController.add(lastStatus!);
          break;
          
        default:
          // Handle responses with 'ok' field
          if (message.containsKey('ok')) {
            if (message['ok'] == true) {
              // Success responses
              if (event == 'target_updated' && message['target'] != null) {
                _targetUpdatedController.add(message['target'] as Map<String, dynamic>);
              } else if (message['status'] != null) {
                lastStatus = message['status'] as Map<String, dynamic>;
                _statusController.add(lastStatus!);
              }
            } else {
              // Error responses
              debugPrint('HoloOcean server error: ${message['error']}');
              _errorController.add({
                'type': 'server_error',
                'message': message['error'],
              });
            }
          }
          break;
      }
    } catch (error) {
      debugPrint('Error parsing HoloOcean message: $error');
      _errorController.add({
        'type': 'parse_error',
        'message': 'Failed to parse server message',
        'rawData': data,
      });
    }
  }
  
  /// Send command to server
  /// @param command - Command object
  /// @returns Send future
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (!isConnected || _ws == null) {
      throw Exception('WebSocket not connected');
    }
    
    try {
      final message = jsonEncode(command);
      _ws!.sink.add(message);
    } catch (error) {
      throw Exception('Failed to send command: $error');
    }
  }
  
  /// Set target position for HoloOcean agent
  /// @param lat - Latitude (-90 to 90)
  /// @param lon - Longitude (-180 to 180)
  /// @param depth - Depth in meters (-11000 to 11000)
  /// @param time - Optional ISO-8601 time string
  /// @returns Command future
  Future<void> setTarget(double lat, double lon, double depth, {String? time}) async {
    // Validate coordinates
    final validation = validateCoordinates(lat, lon, depth);
    if (validation['isValid'] != true) {
      final errors = validation['errors'] as List<String>;
      throw Exception('Invalid coordinates: ${errors.join(', ')}');
    }
    
    // Validate time if provided
    if (time != null && !validateTime(time)) {
      throw Exception('Invalid time format. Use ISO-8601 format (e.g., "2025-08-14T00:00:00Z")');
    }
    
    final command = <String, dynamic>{
      'type': 'set_target',
      'lat': lat,
      'lon': lon,
      'depth': depth,
    };
    
    if (time != null) {
      command['time'] = time;
    }
    
    try {
      await sendCommand(command);
      debugPrint('Target set: $command');
    } catch (error) {
      debugPrint('Failed to set target: $error');
      rethrow;
    }
  }
  
  /// Request one-shot status from server
  /// @returns Status future
  Future<void> getStatus() async {
    try {
      await sendCommand({'type': 'get_status'});
      debugPrint('Status requested');
    } catch (error) {
      debugPrint('Failed to get status: $error');
      rethrow;
    }
  }
  
  /// Subscribe to continuous status updates
  /// @returns Subscribe future
  Future<void> subscribe() async {
    try {
      await sendCommand({'type': 'subscribe'});
      isSubscribed = true;
      debugPrint('Subscribed to status updates');
    } catch (error) {
      debugPrint('Failed to subscribe: $error');
      rethrow;
    }
  }
  
  /// Unsubscribe from status updates (by closing connection)
  void unsubscribe() {
    isSubscribed = false;
    // Note: The protocol doesn't specify an unsubscribe command
    // Status updates stop when the WebSocket connection is closed
    debugPrint('Unsubscribed from status updates');
  }
  
  /// Disconnect from WebSocket
  void disconnect() {
    shouldReconnect = false;
    _clearReconnectTimer();
    _clearPingTimer();
    
    _wsSubscription?.cancel();
    _ws?.sink.close(status.normalClosure, 'Client disconnect');
    
    isConnected = false;
    isSubscribed = false;
    _ws = null;
    
    debugPrint('HoloOcean WebSocket disconnected');
  }
  
  /// Get connection status
  /// @returns Connection status
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': isConnected,
      'isSubscribed': isSubscribed,
      'reconnectAttempts': reconnectAttempts,
      'maxReconnectAttempts': maxReconnectAttempts,
      'endpoint': endpoint,
      'readyState': getReadyStateString(),
      'lastStatus': lastStatus,
    };
  }
  
  /// Get last known status
  /// @returns Last status object
  Map<String, dynamic>? getLastStatus() {
    return lastStatus;
  }
  
  /// Reset reconnection attempts (useful for manual reconnect)
  void resetReconnection() {
    reconnectAttempts = 0;
    reconnectDelay = 1000;
  }
  
  /// Manual reconnect
  /// @param token - The JWT token for authentication
  /// @returns Connection future
  Future<void> reconnect({String? token}) async {
    disconnect();
    shouldReconnect = true;
    resetReconnection();
    return connect(token: token);
  }
  
  /// Check if coordinates are within valid ranges
  /// @param lat - Latitude
  /// @param lon - Longitude
  /// @param depth - Depth
  /// @returns Are coordinates valid
  bool areCoordinatesValid(double lat, double lon, double depth) {
    return validateCoordinates(lat, lon, depth)['isValid'] == true;
  }
  
  /// Format coordinates for display
  /// @param lat - Latitude
  /// @param lon - Longitude
  /// @param depth - Depth
  /// @returns Formatted coordinates
  String formatCoordinates(double lat, double lon, double depth) {
    final latDir = lat >= 0 ? 'N' : 'S';
    final lonDir = lon >= 0 ? 'E' : 'W';
    
    return '${lat.abs().toStringAsFixed(6)}°$latDir, ${lon.abs().toStringAsFixed(6)}°$lonDir, ${depth}m depth';
  }
  
  /// Get current timestamp in ISO-8601 format
  /// @returns ISO-8601 timestamp
  String getCurrentTime() {
    return DateTime.now().toIso8601String();
  }
  
  /// Parse time string to DateTime object
  /// @param timeStr - ISO-8601 time string
  /// @returns Parsed date or null if invalid
  DateTime? parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    try {
      return DateTime.parse(timeStr);
    } catch (e) {
      return null;
    }
  }
  
  /// Calculate distance between two coordinates (Haversine formula)
  /// @param lat1 - First latitude
  /// @param lon1 - First longitude
  /// @param lat2 - Second latitude
  /// @param lon2 - Second longitude
  /// @returns Distance in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Earth's radius in meters
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
  
  /// Get WebSocket ready state as string
  /// @returns Ready state description
  String getReadyStateString() {
    if (_ws == null || !isConnected) return 'CLOSED';
    return isConnected ? 'OPEN' : 'CLOSED';
  }
  
  /// Send ping to server (for testing connection)
  void ping() {
    if (isConnected && _ws != null) {
      // Send a get_status as ping since protocol doesn't specify ping format
      getStatus().catchError((error) {
        debugPrint('Ping failed: $error');
      });
    }
  }
  
  /// Start periodic ping timer
  void startPingTimer() {
    _clearPingTimer();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      ping();
    }); // Slightly more than server's 20 second ping interval
  }
  
  /// Stop ping timer
  void stopPingTimer() {
    _clearPingTimer();
  }
  
  /// Get service statistics
  /// @returns Service statistics
  Map<String, dynamic> getStats() {
    return {
      'isConnected': isConnected,
      'isSubscribed': isSubscribed,
      'reconnectAttempts': reconnectAttempts,
      'maxReconnectAttempts': maxReconnectAttempts,
      'currentDelay': reconnectDelay,
      'maxDelay': maxReconnectDelay,
      'hasLastStatus': lastStatus != null,
      'readyState': getReadyStateString(),
      'endpoint': endpoint,
      'shouldReconnect': shouldReconnect,
    };
  }
  
  /// Clean up resources
  void cleanup() {
    shouldReconnect = false;
    disconnect();
    _clearReconnectTimer();
    _clearPingTimer();
    
    // Close all stream controllers
    _connectedController.close();
    _disconnectedController.close();
    _statusController.close();
    _targetUpdatedController.close();
    _errorController.close();
    _connectionErrorController.close();
    
    lastStatus = null;
  }
}

/// Singleton instance and configuration
class HoloOceanServiceProvider {
  static HoloOceanService? _instance;
  
  static HoloOceanService getInstance() {
    if (_instance == null) {
      final endpoint = _getEndpoint();
      _instance = HoloOceanService(endpoint);
    }
    return _instance!;
  }
  
  static String _getEndpoint() {
    const holooceanEndpoint = String.fromEnvironment('HOLOOCEAN_ENDPOINT', defaultValue: '');
    
    if (kReleaseMode) {
      // In production, enforce a secure WebSocket connection
      if (holooceanEndpoint.isEmpty) {
        throw Exception('HOLOOCEAN_ENDPOINT is not defined in the production environment. Please set it to a secure WebSocket URL (wss://).');
      }
      if (!holooceanEndpoint.startsWith('wss://')) {
        throw Exception('HOLOOCEAN_ENDPOINT in production must start with wss://');
      }
      return holooceanEndpoint;
    } else {
      // In development, allow http and default to localhost
      final endpoint = holooceanEndpoint.isNotEmpty ? holooceanEndpoint : 'ws://localhost:8080';
      
      // Optional: warn if a production-like URL is used in development
      if (endpoint.startsWith('wss://')) {
        debugPrint('Using a secure WebSocket (wss://) in a non-production environment. Ensure this is intended.');
      }
      return endpoint;
    }
  }
  
  /// Reset singleton (useful for testing)
  static void resetInstance() {
    _instance?.cleanup();
    _instance = null;
  }
}

/// Remote data source implementation for HoloOcean service
abstract class HoloOceanServiceRemoteDataSource {
  Future<void> connect({String? token});
  Future<void> disconnect();
  Future<void> setTarget(double lat, double lon, double depth, {String? time});
  Future<void> getStatus();
  Future<void> subscribe();
  void unsubscribe();
  Map<String, dynamic> getConnectionStatus();
  Map<String, dynamic>? getLastStatus();
  Stream<Map<String, dynamic>> get onStatus;
  Stream<Map<String, dynamic>> get onTargetUpdated;
  Stream<Map<String, dynamic>> get onConnected;
  Stream<Map<String, dynamic>> get onDisconnected;
  Stream<Map<String, dynamic>> get onError;
}

class HoloOceanServiceRemoteDataSourceImpl implements HoloOceanServiceRemoteDataSource {
  final HoloOceanService _holoOceanService;
  
  HoloOceanServiceRemoteDataSourceImpl({
    required HoloOceanService holoOceanService,
  }) : _holoOceanService = holoOceanService;
  
  @override
  Future<void> connect({String? token}) async {
    return await _holoOceanService.connect(token: token);
  }
  
  @override
  Future<void> disconnect() async {
    _holoOceanService.disconnect();
  }
  
  @override
  Future<void> setTarget(double lat, double lon, double depth, {String? time}) async {
    return await _holoOceanService.setTarget(lat, lon, depth, time: time);
  }
  
  @override
  Future<void> getStatus() async {
    return await _holoOceanService.getStatus();
  }
  
  @override
  Future<void> subscribe() async {
    return await _holoOceanService.subscribe();
  }
  
  @override
  void unsubscribe() {
    _holoOceanService.unsubscribe();
  }
  
  @override
  Map<String, dynamic> getConnectionStatus() {
    return _holoOceanService.getConnectionStatus();
  }
  
  @override
  Map<String, dynamic>? getLastStatus() {
    return _holoOceanService.getLastStatus();
  }
  
  @override
  Stream<Map<String, dynamic>> get onStatus => _holoOceanService.onStatus;
  
  @override
  Stream<Map<String, dynamic>> get onTargetUpdated => _holoOceanService.onTargetUpdated;
  
  @override
  Stream<Map<String, dynamic>> get onConnected => _holoOceanService.onConnected;
  
  @override
  Stream<Map<String, dynamic>> get onDisconnected => _holoOceanService.onDisconnected;
  
  @override
  Stream<Map<String, dynamic>> get onError => _holoOceanService.onError;
}