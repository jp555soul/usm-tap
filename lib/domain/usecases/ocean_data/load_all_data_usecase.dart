import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/ocean_data_repository.dart';

class LoadAllDataResult {
  final List<dynamic> oceanData;
  final List<dynamic> stations;
  final List<String> availableModels;
  final List<double> availableDepths;

  const LoadAllDataResult({
    required this.oceanData,
    required this.stations,
    required this.availableModels,
    required this.availableDepths,
  });
}

class LoadAllDataUseCase {
  final OceanDataRepository repository;

  LoadAllDataUseCase(this.repository);

  Future<Either<Failure, LoadAllDataResult>> call(String stationId) async {
    try {
      final stationsResult = await repository.getStations();
      
      return stationsResult.fold(
        (failure) => Left(failure),
        (stations) async {
          final modelsResult = await repository.getAvailableModels(stationId);
          final depthsResult = await repository.getAvailableDepths(stationId);

          return modelsResult.fold(
            (failure) => Left(failure),
            (models) => depthsResult.fold(
              (failure) => Left(failure),
              (depths) => Right(LoadAllDataResult(
                oceanData: [],
                stations: stations,
                availableModels: models,
                availableDepths: depths,
              )),
            ),
          );
        },
      );
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}