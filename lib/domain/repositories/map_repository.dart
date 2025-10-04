import 'package:dartz/dartz.dart';
import '../entities/station_data_entity.dart';
import '../../core/errors/failures.dart';

class MapBounds {
  final double north;
  final double south;
  final double east;
  final double west;

  const MapBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });
}

abstract class MapRepository {
  Future<Either<Failure, List<StationDataEntity>>> getStationsInBounds(
    MapBounds bounds,
  );

  Future<Either<Failure, StationDataEntity>> selectStation(String stationId);

  Future<Either<Failure, void>> clearSelection();

  Future<Either<Failure, List<StationDataEntity>>> searchStations({
    String? query,
    String? type,
    bool? activeOnly,
  });

  Future<Either<Failure, MapBounds>> getOptimalBounds(
    List<StationDataEntity> stations,
  );
}