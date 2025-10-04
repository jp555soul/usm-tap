import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/holoocean_repository.dart';

class SetTargetParams {
  final double latitude;
  final double longitude;
  final double depth;
  final Map<String, dynamic>? parameters;

  const SetTargetParams({
    required this.latitude,
    required this.longitude,
    required this.depth,
    this.parameters,
  });
}

class SetTargetUseCase {
  final HoloOceanRepository repository;

  SetTargetUseCase(this.repository);

  Future<Either<Failure, void>> call(SetTargetParams params) async {
    final target = HoloOceanTarget(
      latitude: params.latitude,
      longitude: params.longitude,
      depth: params.depth,
      parameters: params.parameters,
    );
    return await repository.setTarget(target);
  }
}