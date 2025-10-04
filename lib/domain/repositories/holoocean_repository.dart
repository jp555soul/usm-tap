import 'package:dartz/dartz.dart';
import '../entities/connection_status_entity.dart';
import '../../core/errors/failures.dart';

class HoloOceanTarget {
  final double latitude;
  final double longitude;
  final double depth;
  final Map<String, dynamic>? parameters;

  const HoloOceanTarget({
    required this.latitude,
    required this.longitude,
    required this.depth,
    this.parameters,
  });
}

abstract class HoloOceanRepository {
  Future<Either<Failure, ConnectionStatusEntity>> connect({
    String? endpoint,
    Map<String, dynamic>? config,
  });

  Future<Either<Failure, void>> disconnect();

  Future<Either<Failure, ConnectionStatusEntity>> getConnectionStatus();

  Future<Either<Failure, void>> setTarget(HoloOceanTarget target);

  Future<Either<Failure, Map<String, dynamic>>> getSensorData();

  Stream<ConnectionStatusEntity> watchConnectionStatus();
}