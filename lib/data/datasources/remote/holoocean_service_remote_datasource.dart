// lib/data/datasources/remote/holoocean_service_remote_datasource.dart
import 'dart:async';
import '../../services/holoocean_service.dart';

// The interface expected by the repository and BLoCs
abstract class HoloOceanServiceRemoteDataSource {
  Future<void> connect({String? endpoint, Map<String, dynamic>? config});
  Future<void> disconnect();
  Future<void> setTarget({required double latitude, required double longitude, required double depth, Map<String, dynamic>? parameters});
  Future<Map<String, dynamic>> getStatus();
  Future<void> subscribe();
  void unsubscribe();
  Future<bool> isConnected();
  Map<String, dynamic> getConnectionStatus();
  Future<Map<String, dynamic>> getSensorData();
  Future<Map<String, dynamic>> getLastStatus();
  Stream<Map<String, dynamic>> get onStatus;
  Stream<Map<String, dynamic>> get onTargetUpdated;
  Stream<Map<String, dynamic>> get onConnected;
  Stream<Map<String, dynamic>> get onDisconnected;
  Stream<Map<String, dynamic>> get onError;
  Stream<Map<String, dynamic>> get onConnectionError;
}

class HoloOceanServiceRemoteDataSourceImpl implements HoloOceanServiceRemoteDataSource {
  final HoloOceanService _holoOceanService;
  StreamSubscription? _sensorSubscription;
  Map<String, dynamic>? _lastStatus;

  // Stream controllers to emulate the event-based interface
  final _statusController = StreamController<Map<String, dynamic>>.broadcast();
  final _targetUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _disconnectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<Map<String, dynamic>>.broadcast();

  HoloOceanServiceRemoteDataSourceImpl({required HoloOceanService holoOceanService})
      : _holoOceanService = holoOceanService;

  @override
  Stream<Map<String, dynamic>> get onStatus => _statusController.stream;
  @override
  Stream<Map<String, dynamic>> get onTargetUpdated => _targetUpdatedController.stream;
  @override
  Stream<Map<String, dynamic>> get onConnected => _connectedController.stream;
  @override
  Stream<Map<String, dynamic>> get onDisconnected => _disconnectedController.stream;
  @override
  Stream<Map<String, dynamic>> get onError => _errorController.stream;
  @override
  Stream<Map<String, dynamic>> get onConnectionError => _errorController.stream;

  @override
  Future<void> connect({String? endpoint, Map<String, dynamic>? config}) async {
    try {
      await _holoOceanService.connect(endpoint: endpoint, config: config);
      _connectedController.add({'status': 'connected'});
      subscribe(); // Automatically subscribe to the sensor stream on connect
    } catch (e) {
      _errorController.add({'error': 'Connection failed', 'details': e.toString()});
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    unsubscribe();
    await _holoOceanService.disconnect();
    _disconnectedController.add({'status': 'disconnected'});
  }

  @override
  Future<void> setTarget({required double latitude, required double longitude, required double depth, Map<String, dynamic>? parameters}) async {
    try {
      await _holoOceanService.setTarget(
        latitude: latitude,
        longitude: longitude,
        depth: depth,
        parameters: parameters,
      );
       _targetUpdatedController.add({'lat': latitude, 'lon': longitude, 'depth': depth});
    } catch (e) {
      _errorController.add({'error': 'Set target failed', 'details': e.toString()});
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getStatus() async {
    try {
      final status = await _holoOceanService.getStatus();
      _lastStatus = status;
      _statusController.add(status);
      return status;
    } catch (e) {
      _errorController.add({'error': 'Get status failed', 'details': e.toString()});
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> getLastStatus() async {
    return _lastStatus ?? await getStatus();
  }

  @override
  Future<void> subscribe() async {
    if (_sensorSubscription != null) return; // Already subscribed
    try {
      _sensorSubscription = _holoOceanService.sensorStream.listen(
        (data) {
          // The new service provides a generic stream; we assume it's status data
          _statusController.add(data);
        },
        onError: (error) {
          _errorController.add({'error': 'Stream error', 'details': error.toString()});
        },
        onDone: () {
          _disconnectedController.add({'status': 'stream closed'});
        },
      );
    } catch (e) {
       _errorController.add({'error': 'Subscribe failed', 'details': e.toString()});
    }
  }

  @override
  void unsubscribe() {
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
  }

  @override
  Future<bool> isConnected() async {
    return _holoOceanService.isConnected;
  }

  @override
  Future<Map<String, dynamic>> getSensorData() async {
    try {
      return await _holoOceanService.getSensorData();
    } catch (e) {
      _errorController.add({'error': 'Get sensor data failed', 'details': e.toString()});
      rethrow;
    }
  }

  @override
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isConnected': _holoOceanService.isConnected,
    };
  }

  // It's good practice to have a dispose method to clean up controllers
  void dispose() {
    _statusController.close();
    _targetUpdatedController.close();
    _connectedController.close();
    _disconnectedController.close();
    _errorController.close();
    unsubscribe();
    _holoOceanService.dispose();
  }
}