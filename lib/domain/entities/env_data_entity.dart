import 'package:equatable/equatable.dart';

class EnvDataEntity extends Equatable {
  final DateTime timestamp;
  final double? windSpeed;
  final double? windDirection;
  final double? airTemperature;
  final double? airPressure;
  final double? humidity;
  final double? waveHeight;
  final double? wavePeriod;
  final double? visibility;
  final double? cloudCover;
  final String? weatherCondition;
  final double? temperature;
  final double? salinity;
  final double? currentDirection;
  final double? currentSpeed;
  final double? pressure;
  final Map<String, dynamic>? additionalData;

  const EnvDataEntity({
    required this.timestamp,
    this.windSpeed,
    this.windDirection,
    this.airTemperature,
    this.airPressure,
    this.humidity,
    this.waveHeight,
    this.wavePeriod,
    this.visibility,
    this.cloudCover,
    this.weatherCondition,
    this.temperature,
    this.salinity,
    this.currentDirection,
    this.currentSpeed,
    this.pressure,
    this.additionalData,
  });

  @override
  List<Object?> get props => [
        timestamp,
        windSpeed,
        windDirection,
        airTemperature,
        airPressure,
        humidity,
        waveHeight,
        wavePeriod,
        visibility,
        cloudCover,
        weatherCondition,
        temperature,
        salinity,
        currentDirection,
        currentSpeed,
        pressure,
        additionalData,
      ];

  EnvDataEntity copyWith({
    DateTime? timestamp,
    double? windSpeed,
    double? windDirection,
    double? airTemperature,
    double? airPressure,
    double? humidity,
    double? waveHeight,
    double? wavePeriod,
    double? visibility,
    double? cloudCover,
    String? weatherCondition,
    double? temperature,
    double? salinity,
    double? currentDirection,
    double? currentSpeed,
    double? pressure,
    Map<String, dynamic>? additionalData,
  }) {
    return EnvDataEntity(
      timestamp: timestamp ?? this.timestamp,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
      airTemperature: airTemperature ?? this.airTemperature,
      airPressure: airPressure ?? this.airPressure,
      humidity: humidity ?? this.humidity,
      waveHeight: waveHeight ?? this.waveHeight,
      wavePeriod: wavePeriod ?? this.wavePeriod,
      visibility: visibility ?? this.visibility,
      cloudCover: cloudCover ?? this.cloudCover,
      weatherCondition: weatherCondition ?? this.weatherCondition,
      temperature: temperature ?? this.temperature,
      salinity: salinity ?? this.salinity,
      currentDirection: currentDirection ?? this.currentDirection,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      pressure: pressure ?? this.pressure,
      additionalData: additionalData ?? this.additionalData,
    );
  }
}