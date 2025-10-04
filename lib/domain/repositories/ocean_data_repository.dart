import 'package:dartz/dartz.dart';
import '../entities/ocean_data_entity.dart';
import '../entities/station_data_entity.dart';
import '../entities/env_data_entity.dart';
import '../../core/errors/failures.dart';

abstract class OceanDataRepository {
  Future<Either<Failure, List<OceanDataEntity>>> getOceanData({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
    double? depth,
    String? model,
  });

  Future<Either<Failure, List<StationDataEntity>>> getStations();

  Future<Either<Failure, StationDataEntity>> getStationById(String id);

  Future<Either<Failure, EnvDataEntity>> getEnvironmentalData({
    required DateTime timestamp,
    String? stationId,
  });

  Future<Either<Failure, List<String>>> getAvailableModels(String stationId);

  Future<Either<Failure, List<double>>> getAvailableDepths(String stationId);

  Future<Either<Failure, Map<String, dynamic>>> getDataSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  });
}