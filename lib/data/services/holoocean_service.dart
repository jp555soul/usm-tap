// lib/data/services/holoocean_service.dart
import 'package:dio/dio.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/constants/app_constants.dart';

class HoloOceanService {
  final Dio _dio;
  final String baseUrl;
  final String? token;
  WebSocketChannel? _webSocketChannel;
  bool _isConnected = false;

  HoloOceanService({
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
  }

  Future<void> connect({
    String? endpoint,
    Map<String, dynamic>? config,
  }) async {
    try {
      final wsEndpoint = endpoint ?? '${baseUrl.replaceAll('http', 'ws')}/ws/holoocean';
      
      _webSocketChannel = WebSocketChannel.connect(
        Uri.parse(wsEndpoint),
      );

      await _webSocketChannel!.ready;
      _isConnected = true;

      // Send initial config if provided
      if (config != null) {
        _webSocketChannel!.sink.add(config);
      }
    } catch (e) {
      _isConnected = false;
      throw Exception('Failed to connect to HoloOcean: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await _webSocketChannel?.sink.close();
      _webSocketChannel = null;
      _isConnected = false;
    } catch (e) {
      throw Exception('Failed to disconnect from HoloOcean: $e');
    }
  }

  bool get isConnected => _isConnected;

  Future<void> setTarget({
    required double latitude,
    required double longitude,
    required double depth,
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConnected) {
      throw Exception('Not connected to HoloOcean');
    }

    try {
      final command = {
        'type': 'set_target',
        'data': {
          'latitude': latitude,
          'longitude': longitude,
          'depth': depth,
          if (parameters != null) ...parameters,
        },
      };

      _webSocketChannel!.sink.add(command);
    } catch (e) {
      throw Exception('Failed to set target: $e');
    }
  }

  Future<Map<String, dynamic>> getSensorData() async {
    if (!_isConnected) {
      throw Exception('Not connected to HoloOcean');
    }

    try {
      final response = await _dio.get('/api/holoocean/sensors');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Stream<Map<String, dynamic>> get sensorStream {
    if (!_isConnected || _webSocketChannel == null) {
      throw Exception('Not connected to HoloOcean');
    }

    return _webSocketChannel!.stream.map((data) {
      if (data is String) {
        return {'data': data};
      } else if (data is Map) {
        return data as Map<String, dynamic>;
      } else {
        return {'raw': data};
      }
    });
  }

  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected) {
      throw Exception('Not connected to HoloOcean');
    }

    try {
      _webSocketChannel!.sink.add(command);
    } catch (e) {
      throw Exception('Failed to send command: $e');
    }
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _dio.get('/api/holoocean/status');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
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

  void dispose() {
    disconnect();
  }
}