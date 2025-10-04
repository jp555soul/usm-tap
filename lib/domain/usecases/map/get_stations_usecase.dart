import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../entities/station_data_entity.dart';
import '../../repositories/ocean_data_repository.dart';

class GetStationsUseCase {
  final OceanDataRepository repository;

  GetStationsUseCase(this.repository);

  Future<Either<Failure, List<StationDataEntity>>> call() async {
    return await repository.getStations();
  }
}