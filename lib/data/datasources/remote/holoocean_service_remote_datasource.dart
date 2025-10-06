// lib/data/datasources/remote/holoocean_service_remote_datasource.dart
import 'dart:async';
import '../../services/holoocean_service.dart';

// The interface expected by the repository and BLoCs
abstract class HoloOceanServiceRemoteDataSource {
  Future<void> connect({String? token});
  Future<void> disconnect();
  Future<void> setTarget(double lat, double lon, double depth, {String? time});
  Future<void> getStatus();
  Future<void> subscribe();
  void unsubscribe();
  Map<String, dynamic> getConnectionStatus();
  Stream<Map<String, dynamic>> get onStatus;
  Stream<Map<String, dynamic>> get onTargetUpdated;
  Stream<Map<String, dynamic>> get onConnected;
  Stream<Map<String, dynamic>> get onDisconnected;
  Stream<Map<String, dynamic>> get onError;
}

class HoloOceanServiceRemoteDataSourceImpl implements HoloOceanServiceRemoteDataSource {
  final HoloOceanService _holoOceanService;
  StreamSubscription? _sensorSubscription;

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
  Future<void> connect({String? token}) async {
    try {
      // The new service doesn't use a token in the connect method, assuming it's handled by Dio interceptors
      await _holoOceanService.connect();
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
  Future<void> setTarget(double lat, double lon, double depth, {String? time}) async {
    try {
      await _holoOceanService.setTarget(
        latitude: lat,
        longitude: lon,
        depth: depth,
        parameters: time != null ? {'time': time} : null,
      );
       _targetUpdatedController.add({'lat': lat, 'lon': lon, 'depth': depth});
    } catch (e) {
      _errorController.add({'error': 'Set target failed', 'details': e.toString()});
      rethrow;
    }
  }

  @override
  Future<void> getStatus() async {
    try {
      final status = await _holoOceanService.getStatus();
      _statusController.add(status);
    } catch (e) {
      _errorController.add({'error': 'Get status failed', 'details': e.toString()});
      rethrow;
    }
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