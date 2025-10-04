import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/connection_status_entity.dart';
import '../../repositories/holoocean_repository.dart';

class ConnectHoloOceanParams {
  final String? endpoint;
  final Map<String, dynamic>? config;

  const ConnectHoloOceanParams({
    this.endpoint,
    this.config,
  });
}

class ConnectHoloOceanUseCase {
  final HoloOceanRepository repository;

  ConnectHoloOceanUseCase(this.repository);

  Future<Either<Failure, ConnectionStatusEntity>> call(
    ConnectHoloOceanParams params,
  ) async {
    return await repository.connect(
      endpoint: params.endpoint,
      config: params.config,
    );
  }
}