import 'package:equatable/equatable.dart';

class MapBounds extends Equatable {
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

  @override
  List<Object?> get props => [north, south, east, west];
}