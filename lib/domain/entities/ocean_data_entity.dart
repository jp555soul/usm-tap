import 'package:equatable/equatable.dart';

class OceanDataEntity extends Equatable {
  final String id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double depth;
  final double? temperature;
  final double? salinity;
  final double? pressure;
  final double? chlorophyll;
  final double? oxygen;
  final String? stationId;
  final Map<String, dynamic>? additionalData;

  const OceanDataEntity({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.depth,
    this.temperature,
    this.salinity,
    this.pressure,
    this.chlorophyll,
    this.oxygen,
    this.stationId,
    this.additionalData,
  });

  @override
  List<Object?> get props => [
        id,
        timestamp,
        latitude,
        longitude,
        depth,
        temperature,
        salinity,
        pressure,
        chlorophyll,
        oxygen,
        stationId,
        additionalData,
      ];

  OceanDataEntity copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? depth,
    double? temperature,
    double? salinity,
    double? pressure,
    double? chlorophyll,
    double? oxygen,
    String? stationId,
    Map<String, dynamic>? additionalData,
  }) {
    return OceanDataEntity(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      depth: depth ?? this.depth,
      temperature: temperature ?? this.temperature,
      salinity: salinity ?? this.salinity,
      pressure: pressure ?? this.pressure,
      chlorophyll: chlorophyll ?? this.chlorophyll,
      oxygen: oxygen ?? this.oxygen,
      stationId: stationId ?? this.stationId,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}