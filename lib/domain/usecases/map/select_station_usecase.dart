import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/station_data_entity.dart';
import '../../repositories/ocean_data_repository.dart';

class SelectStationUseCase {
  final OceanDataRepository repository;

  SelectStationUseCase(this.repository);

  Future<Either<Failure, StationDataEntity>> call(String stationId) async {
    return await repository.getStationById(stationId);
  }
}