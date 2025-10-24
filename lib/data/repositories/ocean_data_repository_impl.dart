// lib/data/repositories/ocean_data_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/ocean_data_entity.dart';
import '../../domain/entities/station_data_entity.dart';
import '../../domain/entities/env_data_entity.dart';
import '../../domain/repositories/ocean_data_repository.dart';
import '../datasources/remote/ocean_data_remote_datasource.dart';

class OceanDataRepositoryImpl implements OceanDataRepository {
  final OceanDataRemoteDataSource remoteDataSource;

  OceanDataRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<OceanDataEntity>>> getOceanData({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
    double? depth,
    String? model,
  }) async {
    try {
      final data = await remoteDataSource.getOceanData(
        startDate: startDate,
        endDate: endDate.toIso8601String(),
      );
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StationDataEntity>>> getStations() async {
    try {
      final stations = await remoteDataSource.getStations();
      final stationEntities = (stations as List).map((s) {
        final map = s as Map<String, dynamic>;
        return StationDataEntity(
          id: map['id'] as String,
          name: map['name'] as String,
          latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
          longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
          type: map['type'] as String?,
          description: map['description'] as String?,
          isActive: map['isActive'] as bool? ?? true,
        );
      }).toList();
      return Right(stationEntities);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, StationDataEntity>> getStationById(String id) async {
    try {
      final stations = await remoteDataSource.getStations();
      final station = stations.firstWhere(
        (s) => s.id == id,
        orElse: () => throw ServerException('Station not found'),
      );
      return Right(station);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, EnvDataEntity>> getEnvironmentalData({
    DateTime? timestamp,
    String? stationId,
    double? depth,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final envData = await remoteDataSource.getEnvironmentalData(
        timestamp: timestamp,
        depth: depth,
        latitude: latitude,
        longitude: longitude,
      );
      return Right(envData);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAvailableModels(
      String stationId) async {
    try {
      final models =
          await remoteDataSource.getAvailableModels(stationId: stationId);
      return Right((models as List).map((m) => m.toString()).toList());
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<double>>> getAvailableDepths(
    String stationId,
  ) async {
    try {
      final depths = await remoteDataSource.getAvailableDepths(stationId);
      return Right(depths);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getDataSummary({
    required DateTime startDate,
    required DateTime endDate,
    String? stationId,
  }) async {
    try {
      final data = await remoteDataSource.getOceanData(
        startDate: startDate,
        endDate: endDate.toIso8601String(),
      );

      // Calculate summary statistics
      final summary = {
        'totalRecords': data.length,
        'dateRange': {
          'start': startDate.toIso8601String(),
          'end': endDate.toIso8601String(),
        },
        'stationId': stationId,
      };

      return Right(summary);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }
}