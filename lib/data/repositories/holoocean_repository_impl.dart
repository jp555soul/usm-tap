// lib/data/repositories/holoocean_repository_impl.dart
import 'dart:async';
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/connection_status_entity.dart';
import '../../domain/repositories/holoocean_repository.dart';
import '../datasources/remote/holoocean_service_remote_datasource.dart';

class HoloOceanRepositoryImpl implements HoloOceanRepository {
  final HoloOceanServiceRemoteDataSource remoteDataSource;
  final StreamController<ConnectionStatusEntity> _statusController =
      StreamController<ConnectionStatusEntity>.broadcast();

  ConnectionStatusEntity _currentStatus = const ConnectionStatusEntity(
    state: ConnectionState.disconnected,
    connected: false,
    endpoint: '',
  );

  HoloOceanRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ConnectionStatusEntity>> connect({
    String? endpoint,
    Map<String, dynamic>? config,
  }) async {
    try {
      _updateStatus(ConnectionStatusEntity(
        state: ConnectionState.connecting,
        message: 'Connecting to HoloOcean...',
        endpoint: endpoint ?? '',
        connected: false,
      ));

      await remoteDataSource.connect(
        endpoint: endpoint,
        config: config,
      );

      final status = ConnectionStatusEntity(
        state: ConnectionState.connected,
        message: 'Connected to HoloOcean',
        connectedAt: DateTime.now(),
        endpoint: endpoint ?? '',
        connected: true,
      );

      _updateStatus(status);
      return Right(status);
    } on ServerException catch (e) {
      final errorStatus = ConnectionStatusEntity(
        state: ConnectionState.error,
        message: e.message,
        endpoint: endpoint ?? '',
        connected: false,
      );
      _updateStatus(errorStatus);
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      final errorStatus = ConnectionStatusEntity(
        state: ConnectionState.error,
        message: e.message,
        endpoint: endpoint ?? '',
        connected: false,
      );
      _updateStatus(errorStatus);
      return Left(NetworkFailure(e.message));
    } catch (e) {
      final errorStatus = ConnectionStatusEntity(
        state: ConnectionState.error,
        message: 'Connection failed: ${e.toString()}',
        endpoint: endpoint ?? '',
        connected: false,
      );
      _updateStatus(errorStatus);
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> disconnect() async {
    try {
      await remoteDataSource.disconnect();

      _updateStatus(const ConnectionStatusEntity(
        state: ConnectionState.disconnected,
        message: 'Disconnected from HoloOcean',
        endpoint: '',
        connected: false,
      ));

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Disconnect failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, ConnectionStatusEntity>> getConnectionStatus() async {
    try {
      final isConnected = await remoteDataSource.isConnected();
      final lastEndpoint = _currentStatus.endpoint;

      final status = ConnectionStatusEntity(
        state: isConnected ? ConnectionState.connected : ConnectionState.disconnected,
        message: isConnected ? 'Connected' : 'Disconnected',
        lastActivity: DateTime.now(),
        endpoint: lastEndpoint,
        connected: isConnected,
      );

      _updateStatus(status);
      return Right(status);
    } catch (e) {
      return Left(ServerFailure('Failed to get status: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> setTarget(HoloOceanTarget target) async {
    try {
      await remoteDataSource.setTarget(
        latitude: target.latitude,
        longitude: target.longitude,
        depth: target.depth,
        parameters: target.parameters,
      );

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Set target failed: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getSensorData() async {
    try {
      final data = await remoteDataSource.getSensorData();
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Get sensor data failed: ${e.toString()}'));
    }
  }

  @override
  Stream<ConnectionStatusEntity> watchConnectionStatus() {
    return _statusController.stream;
  }

  void _updateStatus(ConnectionStatusEntity status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  void dispose() {
    _statusController.close();
  }
}