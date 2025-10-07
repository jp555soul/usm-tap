// lib/data/repositories/map_repository_impl.dart
import 'package:dartz/dartz.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/station_data_entity.dart';
import '../../domain/repositories/map_repository.dart';
import '../datasources/remote/ocean_data_remote_datasource.dart';

class MapRepositoryImpl implements MapRepository {
  final OceanDataRemoteDataSource remoteDataSource;

  MapRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<StationDataEntity>>> getStationsInBounds(
    MapBounds bounds,
  ) async {
    try {
      final dynamicStations = await remoteDataSource.getStations();
      final allStations = (dynamicStations as List).map((s) {
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

      final stationsInBounds = allStations.where((station) {
        return station.latitude >= bounds.south &&
            station.latitude <= bounds.north &&
            station.longitude >= bounds.west &&
            station.longitude <= bounds.east;
      }).toList();

      return Right(stationsInBounds);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, StationDataEntity>> selectStation(
    String stationId,
  ) async {
    try {
      final dynamicStations = await remoteDataSource.getStations();
      final stations = (dynamicStations as List).map((s) {
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
      final station = stations.firstWhere(
        (s) => s.id == stationId,
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
  Future<Either<Failure, void>> clearSelection() async {
    try {
      // Nothing to do here - selection is managed by BLoC
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<StationDataEntity>>> searchStations({
    String? query,
    String? type,
    bool? activeOnly,
  }) async {
    try {
      final dynamicStations = await remoteDataSource.getStations();
      final allStations = (dynamicStations as List).map((s) {
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

      var filtered = allStations;

      if (query != null && query.isNotEmpty) {
        filtered = filtered.where((station) {
          final queryLower = query.toLowerCase();
          return station.name.toLowerCase().contains(queryLower) ||
              (station.description?.toLowerCase().contains(queryLower) ?? false);
        }).toList();
      }

      if (type != null) {
        filtered = filtered.where((station) => station.type == type).toList();
      }

      if (activeOnly == true) {
        filtered = filtered.where((station) => station.isActive).toList();
      }

      return Right(filtered);
    } on ServerException catch (e) {
      return Left(ServerFailure(e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(e.message));
    } catch (e) {
      return Left(ServerFailure('Unexpected error: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, MapBounds>> getOptimalBounds(
    List<StationDataEntity> stations,
  ) async {
    try {
      if (stations.isEmpty) {
        return const Left(ServerFailure('No stations provided'));
      }

      double minLat = stations.first.latitude;
      double maxLat = stations.first.latitude;
      double minLng = stations.first.longitude;
      double maxLng = stations.first.longitude;

      for (final station in stations) {
        if (station.latitude < minLat) minLat = station.latitude;
        if (station.latitude > maxLat) maxLat = station.latitude;
        if (station.longitude < minLng) minLng = station.longitude;
        if (station.longitude > maxLng) maxLng = station.longitude;
      }

      // Add padding (10% of range)
      final latPadding = (maxLat - minLat) * 0.1;
      final lngPadding = (maxLng - minLng) * 0.1;

      final bounds = MapBounds(
        north: maxLat + latPadding,
        south: minLat - latPadding,
        east: maxLng + lngPadding,
        west: minLng - lngPadding,
      );

      return Right(bounds);
    } catch (e) {
      return Left(ServerFailure('Failed to calculate bounds: ${e.toString()}'));
    }
  }
}