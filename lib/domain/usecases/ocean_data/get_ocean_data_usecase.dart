import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/ocean_data_entity.dart';
import '../../repositories/ocean_data_repository.dart';

class GetOceanDataParams {
  final DateTime startDate;
  final DateTime endDate;
  final String? stationId;
  final double? depth;
  final String? model;

  const GetOceanDataParams({
    required this.startDate,
    required this.endDate,
    this.stationId,
    this.depth,
    this.model,
  });
}

class GetOceanDataUseCase {
  final OceanDataRepository repository;

  GetOceanDataUseCase(this.repository);

  Future<Either<Failure, List<OceanDataEntity>>> call(
    GetOceanDataParams params,
  ) async {
    return await repository.getOceanData(
      startDate: params.startDate,
      endDate: params.endDate,
      stationId: params.stationId,
      depth: params.depth,
      model: params.model,
    );
  }
}