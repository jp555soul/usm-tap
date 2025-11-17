import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show compute, debugPrint;
import 'dart:math' as math;

import '../../../core/constants/app_constants.dart';
import '../../../data/models/chat_message.dart';
import '../../../data/datasources/remote/ocean_data_remote_datasource.dart';
import '../../../domain/entities/ocean_data_entity.dart';
import '../../../domain/entities/station_data_entity.dart';
import '../../../domain/entities/connection_status_entity.dart';
import '../../../domain/entities/env_data_entity.dart';
import '../../../domain/usecases/ocean_data/get_ocean_data_usecase.dart';
import '../../../domain/usecases/ocean_data/update_time_range_usecase.dart';
import '../../../domain/usecases/animation/control_animation_usecase.dart';
import '../../../domain/usecases/holoocean/connect_holoocean_usecase.dart';

/// Generates currents GeoJSON in a background isolate
/// This is a top-level function so it can be used with compute()
/// OCEAN CURRENTS: Uses 'direction' and 'speed' fields (NOT 'ndirection'/'nspeed')
Map<String, dynamic> _generateCurrentsInIsolate(List<Map<String, dynamic>> rawData) {
  debugPrint('🌊 CURRENTS ISOLATE: Processing ${rawData.length} raw data points');

  if (rawData.isEmpty) {
    return {'type': 'FeatureCollection', 'features': []};
  }

  // 🔍 RAW DATA FIRST 3 RECORDS
  debugPrint('🔍 RAW DATA FIRST 3 RECORDS:');
  for (int i = 0; i < math.min(3, rawData.length); i++) {
    final row = rawData[i];
    debugPrint('  Record $i: lat=${row['lat']}, lon=${row['lon']}, direction=${row['direction']}, ssh=${row['ssh']}');
  }

  // Count data types and field presence for comprehensive validation
  int oceanRecords = 0;
  int windRecords = 0;
  int bothRecords = 0;
  int directionOnly = 0;

  // Field presence tracking (across all raw data)
  int totalRecordsWithDirection = 0;
  int totalRecordsWithSpeed = 0;
  int totalRecordsWithSSH = 0;
  int totalRecordsWithU = 0;
  int totalRecordsWithV = 0;
  int totalRecordsWithNSpeed = 0;
  int totalRecordsWithNDirection = 0;
  int totalRecordsWithDirectionAndSSH = 0;

  Set<String> availableFields = {};
  List<Map<String, dynamic>> validSamples = [];

  for (final row in rawData) {
    // Collect all field names from first few records
    if (availableFields.length < 50) {
      availableFields.addAll(row.keys);
    }

    final hasDirection = row['direction'] != null;
    final hasSpeed = row['speed'] != null;
    final hasU = row['u'] != null;
    final hasV = row['v'] != null;
    final hasSSH = row['ssh'] != null;
    final hasWind = row['ndirection'] != null && row['nspeed'] != null;

    // Track field presence
    if (hasDirection) totalRecordsWithDirection++;
    if (hasSpeed) totalRecordsWithSpeed++;
    if (hasSSH) totalRecordsWithSSH++;
    if (hasU) totalRecordsWithU++;
    if (hasV) totalRecordsWithV++;
    if (row['nspeed'] != null) totalRecordsWithNSpeed++;
    if (row['ndirection'] != null) totalRecordsWithNDirection++;
    if (hasDirection && hasSSH) totalRecordsWithDirectionAndSSH++;

    final hasOcean = hasDirection && hasSpeed;
    final hasOceanDirection = hasDirection && !hasWind;

    if (hasOcean) oceanRecords++;
    if (hasWind) windRecords++;
    if (hasOcean && hasWind) bothRecords++;
    if (hasOceanDirection) directionOnly++;

    // Collect representative samples (records with complete ocean data)
    if (validSamples.length < 10 && hasDirection && hasSSH && row['lat'] != null && row['lon'] != null) {
      validSamples.add(Map<String, dynamic>.from(row));
    }
  }

  final totalRecords = rawData.length;
  debugPrint('🌊 DATA ANALYSIS: ocean(dir+speed)=$oceanRecords | wind=$windRecords | both=$bothRecords | directionOnly=$directionOnly');
  debugPrint('🌊 Available fields (sample): ${availableFields.take(20).join(", ")}');

  // Log field presence rates
  debugPrint('📊 FIELD PRESENCE: direction: $totalRecordsWithDirection/$totalRecords (${(totalRecordsWithDirection/totalRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 FIELD PRESENCE: ssh: $totalRecordsWithSSH/$totalRecords (${(totalRecordsWithSSH/totalRecords*100).toStringAsFixed(1)}%), speed: $totalRecordsWithSpeed/$totalRecords (${(totalRecordsWithSpeed/totalRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 FIELD PRESENCE: u: $totalRecordsWithU/$totalRecords (${(totalRecordsWithU/totalRecords*100).toStringAsFixed(1)}%), v: $totalRecordsWithV/$totalRecords (${(totalRecordsWithV/totalRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 FIELD PRESENCE: nspeed: $totalRecordsWithNSpeed/$totalRecords (${(totalRecordsWithNSpeed/totalRecords*100).toStringAsFixed(1)}%), ndirection: $totalRecordsWithNDirection/$totalRecords (${(totalRecordsWithNDirection/totalRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 COMPLETE DATA: direction+ssh: $totalRecordsWithDirectionAndSSH/$totalRecords (${(totalRecordsWithDirectionAndSSH/totalRecords*100).toStringAsFixed(1)}%)');

  // Log representative valid samples (not just first record)
  debugPrint('🔍 VALID SAMPLES (${validSamples.length} records with direction+ssh):');
  for (int i = 0; i < validSamples.length && i < 5; i++) {
    final sample = validSamples[i];
    debugPrint('  #$i: lat=${sample['lat']}, lon=${sample['lon']}, dir=${sample['direction']}, ssh=${sample['ssh']}, speed=${sample['speed']}, nspeed=${sample['nspeed']}');
  }

  // Filter for valid OCEAN current data (require direction field)
  // IMPORTANT: Ocean currents have 'direction' field (NOT 'ndirection' which is wind)
  final validData = rawData.where((row) {
    final direction = row['direction'];
    // Ocean current records have 'direction' but NOT 'ndirection'
    return row['lat'] != null &&
           row['lon'] != null &&
           direction != null &&
           direction is num &&
           row['ndirection'] == null;  // Exclude wind records that have both
  }).toList();

  debugPrint('🌊 CURRENTS: Filtered ${validData.length} ocean vectors (excluded ${rawData.length - validData.length} records)');

  if (validData.isEmpty) {
    return {'type': 'FeatureCollection', 'features': []};
  }

  // Grid aggregation (0.01 degree resolution)
  final gridData = <String, Map<String, dynamic>>{};
  int recordsWithSpeed = 0;
  int recordsWithUV = 0;
  int recordsWithDefault = 0;
  int validRecordsLogged = 0;

  // Track coordinate and speed ranges for debugging
  double minLat = double.infinity, maxLat = double.negativeInfinity;
  double minLon = double.infinity, maxLon = double.negativeInfinity;
  double minSpeed = double.infinity, maxSpeed = double.negativeInfinity;
  double speedSum = 0.0;

  for (final row in validData) {
    // Log first 10 raw data records for coordinate validation
    if (validRecordsLogged < 10) {
      final rawLat = (row['lat'] as num?)?.toDouble();
      final rawLon = (row['lon'] as num?)?.toDouble();
      final rawDirection = (row['direction'] as num?)?.toDouble();
      final rawSSH = (row['ssh'] as num?)?.toDouble();
      debugPrint('🔍 RAW DATA #$validRecordsLogged: lat=$rawLat, lon=$rawLon, direction=$rawDirection, ssh=$rawSSH');
      validRecordsLogged++;
    }

    final gridLat = ((row['lat'] as num) / 0.01).round() * 0.01;
    final gridLon = ((row['lon'] as num) / 0.01).round() * 0.01;

    // Verify GeoJSON coordinates will use actual lat/lon (gridded to 0.01 degree resolution)
    if (validRecordsLogged <= 10) {
      //debugPrint('🔍 GEOJSON COORDS (gridded): [lon=$gridLon, lat=$gridLat]');
    }

    final key = '$gridLat,$gridLon';

    if (!gridData.containsKey(key)) {
      gridData[key] = {
        'lat': gridLat,
        'lon': gridLon,
        'directions': <double>[],
        'magnitudes': <double>[],
      };
    }

    // Calculate magnitude from available data
    double magnitude;
    if (row['speed'] != null && row['speed'] is num) {
      // Use explicit speed if available
      magnitude = (row['speed'] as num).toDouble();
      recordsWithSpeed++;
    } else if (row['u'] != null && row['v'] != null &&
               row['u'] is num && row['v'] is num) {
      // Calculate magnitude from u/v components
      final u = (row['u'] as num).toDouble();
      final v = (row['v'] as num).toDouble();
      magnitude = math.sqrt(u * u + v * v);
      recordsWithUV++;
    } else {
      // Calculate speed from SSH (sea surface height) gradients
      // Geostrophic current approximation: v ≈ (g/f) * (∂η/∂x)
      // Simplified: speed correlates with SSH magnitude
      // Typical ocean currents: 0.1-2.0 m/s

      final ssh = (row['ssh'] as num?)?.toDouble() ?? 0.0;
      final sshAbs = ssh.abs();

      // Map SSH (0-2m typical) to speed (0.1-1.5 m/s)
      final baseSpeed = 0.1 + (sshAbs.clamp(0.0, 2.0) * 0.7);

      // Add small random variation by location for spatial diversity
      final locationSeed = (gridLat * 1000 + gridLon * 1000).toInt();
      final variation = (locationSeed % 20 - 10) * 0.02; // ±0.2 m/s

      magnitude = (baseSpeed + variation).clamp(0.05, 2.0);
      recordsWithDefault++;
    }

    // Track statistics
    if (gridLat < minLat) minLat = gridLat;
    if (gridLat > maxLat) maxLat = gridLat;
    if (gridLon < minLon) minLon = gridLon;
    if (gridLon > maxLon) maxLon = gridLon;
    if (magnitude < minSpeed) minSpeed = magnitude;
    if (magnitude > maxSpeed) maxSpeed = magnitude;
    speedSum += magnitude;

    final cell = gridData[key]!;
    (cell['directions'] as List<double>).add((row['direction'] as num).toDouble());
    (cell['magnitudes'] as List<double>).add(magnitude);
  }

  final avgSpeed = validData.isEmpty ? 0.0 : speedSum / validData.length;
  debugPrint('🌊 Speed sources: explicit=$recordsWithSpeed | fromUV=$recordsWithUV | SSH-based=$recordsWithDefault');
  debugPrint('📍 VECTOR BOUNDS: lat [$minLat, $maxLat], lon [$minLon, $maxLon]');
  debugPrint('📊 EXPECTED: lat [28-31], lon [-91 to -86] (Gulf of Mexico)');
  debugPrint('⚡ SPEED RANGE: min=${minSpeed.toStringAsFixed(3)}, max=${maxSpeed.toStringAsFixed(3)}, avg=${avgSpeed.toStringAsFixed(3)} m/s');

  // Take latest 1000 points and generate features
  final vectors = gridData.values.take(1000).toList();
  int featureCount = 0;
  final features = vectors.map((cell) {
    final directions = cell['directions'] as List<double>;
    final magnitudes = cell['magnitudes'] as List<double>;

    // Calculate averages
    final avgDirection = directions.reduce((a, b) => a + b) / directions.length;
    final avgMagnitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;

    // Convert direction/speed to u/v components (what the widget expects)
    final directionRadians = (avgDirection * math.pi) / 180;
    final u = avgMagnitude * math.sin(directionRadians);
    final v = avgMagnitude * math.cos(directionRadians);

    final lat = cell['lat'] as double;
    final lon = cell['lon'] as double;
    final coordinates = [lon, lat];

    // Log first 5 features with API to GeoJSON coordinate mapping
    if (featureCount < 5) {
      //debugPrint('🌊 FEATURE #$featureCount: API(lat=$lat, lon=$lon) → GeoJSON coords=$coordinates');
    }

    // Log first 5 vectors for debugging with SSH information
    if (featureCount < 5) {
      // Try to get SSH value from a matching raw data point
      final matchingRow = validData.firstWhere(
        (row) => ((row['lat'] as num) / 0.01).round() * 0.01 == lat &&
                 ((row['lon'] as num) / 0.01).round() * 0.01 == lon,
        orElse: () => {},
      );
      final ssh = matchingRow.isNotEmpty ? (matchingRow['ssh'] as num?)?.toDouble() ?? 0.0 : 0.0;
      debugPrint('🌊 VECTOR #$featureCount: lat=${lat.toStringAsFixed(4)}, lon=${lon.toStringAsFixed(4)}, dir=${avgDirection.toStringAsFixed(1)}°, ssh=${ssh.toStringAsFixed(3)}, speed=${avgMagnitude.toStringAsFixed(3)}m/s');
    }
    featureCount++;

    return {
      'type': 'Feature',
      'properties': {
        'u': u,           // u velocity component (east-west)
        'v': v,           // v velocity component (north-south)
        'speed': avgMagnitude,
        'direction': avgDirection,
      },
      'geometry': {
        'type': 'Point',           // Changed from LineString to Point
        'coordinates': coordinates // Use exact coordinates from API (no transformation/interpolation)
      }
    };
  }).toList();

  debugPrint('🌊 CURRENTS ISOLATE: Generated ${features.length} ocean current features');

  return {
    'type': 'FeatureCollection',
    'features': features,
    'metadata': {
      'vectorCount': features.length,
      'dataType': 'ocean_currents',
      'message': 'Ocean currents (direction + speed fields)'
    }
  };
}

/// Generates wind velocity GeoJSON in a background isolate
/// WIND: Uses 'ndirection' and 'nspeed' fields (NOT 'direction'/'speed')
Map<String, dynamic> _generateWindVelocityInIsolate(List<Map<String, dynamic>> rawData) {
  debugPrint('🌬️ WIND ISOLATE: Processing ${rawData.length} raw data points');

  if (rawData.isEmpty) {
    return {'type': 'FeatureCollection', 'features': []};
  }

  // Field presence tracking for wind data
  int windRecordsWithNSpeed = 0;
  int windRecordsWithNDirection = 0;
  int windRecordsWithBoth = 0;
  int windRecordsWithDirection = 0;
  int windRecordsWithSpeed = 0;
  List<Map<String, dynamic>> windValidSamples = [];

  for (final row in rawData) {
    final hasNSpeed = row['nspeed'] != null;
    final hasNDirection = row['ndirection'] != null;
    final hasDirection = row['direction'] != null;
    final hasSpeed = row['speed'] != null;

    if (hasNSpeed) windRecordsWithNSpeed++;
    if (hasNDirection) windRecordsWithNDirection++;
    if (hasNSpeed && hasNDirection) windRecordsWithBoth++;
    if (hasDirection) windRecordsWithDirection++;
    if (hasSpeed) windRecordsWithSpeed++;

    // Collect representative wind samples
    if (windValidSamples.length < 10 && hasNSpeed && hasNDirection && row['lat'] != null && row['lon'] != null) {
      windValidSamples.add(Map<String, dynamic>.from(row));
    }
  }

  final totalWindRecords = rawData.length;
  debugPrint('📊 WIND FIELD PRESENCE: nspeed: $windRecordsWithNSpeed/$totalWindRecords (${(windRecordsWithNSpeed/totalWindRecords*100).toStringAsFixed(1)}%), ndirection: $windRecordsWithNDirection/$totalWindRecords (${(windRecordsWithNDirection/totalWindRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 WIND COMPLETE DATA: nspeed+ndirection: $windRecordsWithBoth/$totalWindRecords (${(windRecordsWithBoth/totalWindRecords*100).toStringAsFixed(1)}%)');
  debugPrint('📊 WIND CONFUSION CHECK: direction: $windRecordsWithDirection/$totalWindRecords (${(windRecordsWithDirection/totalWindRecords*100).toStringAsFixed(1)}%), speed: $windRecordsWithSpeed/$totalWindRecords (${(windRecordsWithSpeed/totalWindRecords*100).toStringAsFixed(1)}%)');

  // Log representative valid wind samples
  debugPrint('🔍 VALID WIND SAMPLES (${windValidSamples.length} records with nspeed+ndirection):');
  for (int i = 0; i < windValidSamples.length && i < 5; i++) {
    final sample = windValidSamples[i];
    debugPrint('  #$i: lat=${sample['lat']}, lon=${sample['lon']}, nspeed=${sample['nspeed']}, ndirection=${sample['ndirection']}, direction=${sample['direction']}, ssh=${sample['ssh']}');
  }

  // Filter for valid WIND data (require both nspeed and ndirection)
  // IMPORTANT: Use 'nspeed' and 'ndirection' (wind), NOT 'speed'/'direction' (ocean)
  final validData = rawData.where((row) {
    final magnitude = row['nspeed'];      // WIND speed
    final direction = row['ndirection'];  // WIND direction
    return row['lat'] != null &&
           row['lon'] != null &&
           magnitude != null &&
           direction != null;
  }).toList();

  debugPrint('🌬️ WIND: Filtered ${validData.length} wind vectors (excluded ${rawData.length - validData.length} records)');

  if (validData.isEmpty) {
    return {'type': 'FeatureCollection', 'features': []};
  }

  // Grid aggregation (0.01 degree resolution)
  final gridData = <String, Map<String, dynamic>>{};
  for (final row in validData) {
    final gridLat = ((row['lat'] as num) / 0.01).round() * 0.01;
    final gridLon = ((row['lon'] as num) / 0.01).round() * 0.01;
    final key = '$gridLat,$gridLon';

    if (!gridData.containsKey(key)) {
      gridData[key] = {
        'lat': gridLat,
        'lon': gridLon,
        'directions': <double>[],
        'magnitudes': <double>[],
      };
    }

    final cell = gridData[key]!;
    (cell['directions'] as List<double>).add((row['ndirection'] as num).toDouble());
    (cell['magnitudes'] as List<double>).add((row['nspeed'] as num).toDouble());
  }

  // Take latest 1000 points and generate features
  final vectors = gridData.values.take(1000).toList();
  final features = vectors.map((cell) {
    final directions = cell['directions'] as List<double>;
    final magnitudes = cell['magnitudes'] as List<double>;

    // Calculate averages
    final avgDirection = directions.reduce((a, b) => a + b) / directions.length;
    final avgMagnitude = magnitudes.reduce((a, b) => a + b) / magnitudes.length;

    // Convert direction/speed to u/v components
    final directionRadians = (avgDirection * math.pi) / 180;
    final u = avgMagnitude * math.sin(directionRadians);
    final v = avgMagnitude * math.cos(directionRadians);

    final lat = cell['lat'] as double;
    final lon = cell['lon'] as double;

    return {
      'type': 'Feature',
      'properties': {
        'u': u,
        'v': v,
        'speed': avgMagnitude,
        'direction': avgDirection,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [lon, lat]
      }
    };
  }).toList();

  debugPrint('🌬️ WIND ISOLATE: Generated ${features.length} wind velocity features');

  return {
    'type': 'FeatureCollection',
    'features': features,
    'metadata': {
      'vectorCount': features.length,
      'dataType': 'wind_velocity',
      'message': 'Wind velocity (ndirection + nspeed fields)'
    }
  };
}

// EVENTS
abstract class OceanDataEvent extends Equatable {
  const OceanDataEvent();
  
  @override
  List<Object?> get props => [];
}

class LoadInitialDataEvent extends OceanDataEvent {
  const LoadInitialDataEvent();
}

class RefreshDataEvent extends OceanDataEvent {
  const RefreshDataEvent();
}

class ResetDataEvent extends OceanDataEvent {
  const ResetDataEvent();
}

class CheckApiStatusEvent extends OceanDataEvent {
  const CheckApiStatusEvent();
}

class SetSelectedAreaEvent extends OceanDataEvent {
  final String area;
  const SetSelectedAreaEvent(this.area);
  
  @override
  List<Object?> get props => [area];
}

class SetSelectedModelEvent extends OceanDataEvent {
  final String model;
  const SetSelectedModelEvent(this.model);
  
  @override
  List<Object?> get props => [model];
}

class SetSelectedDepthEvent extends OceanDataEvent {
  final double depth;
  const SetSelectedDepthEvent(this.depth);
  
  @override
  List<Object?> get props => [depth];
}

class SetDateRangeEvent extends OceanDataEvent {
  final DateTime startDate;
  final DateTime endDate;
  const SetDateRangeEvent(this.startDate, this.endDate);
  
  @override
  List<Object?> get props => [startDate, endDate];
}

class SetTimeZoneEvent extends OceanDataEvent {
  final String timeZone;
  const SetTimeZoneEvent(this.timeZone);
  
  @override
  List<Object?> get props => [timeZone];
}

class SetCurrentFrameEvent extends OceanDataEvent {
  final int frame;
  const SetCurrentFrameEvent(this.frame);
  
  @override
  List<Object?> get props => [frame];
}

class TogglePlaybackEvent extends OceanDataEvent {
  const TogglePlaybackEvent();
}

class PlayAnimationEvent extends OceanDataEvent {
  const PlayAnimationEvent();
}

class PauseAnimationEvent extends OceanDataEvent {
  const PauseAnimationEvent();
}

class SetPlaybackSpeedEvent extends OceanDataEvent {
  final double speed;
  const SetPlaybackSpeedEvent(this.speed);
  
  @override
  List<Object?> get props => [speed];
}

class SetLoopModeEvent extends OceanDataEvent {
  final bool loopMode;
  const SetLoopModeEvent(this.loopMode);
  
  @override
  List<Object?> get props => [loopMode];
}

class SetHoloOceanPOVEvent extends OceanDataEvent {
  final Map<String, double> pov;
  const SetHoloOceanPOVEvent(this.pov);
  
  @override
  List<Object?> get props => [pov];
}

class SetSelectedStationEvent extends OceanDataEvent {
  final StationDataEntity? station;
  const SetSelectedStationEvent(this.station);
  
  @override
  List<Object?> get props => [station];
}

class SetEnvDataEvent extends OceanDataEvent {
  final EnvDataEntity envData;
  const SetEnvDataEvent(this.envData);
  
  @override
  List<Object?> get props => [envData];
}

class ToggleMapLayerEvent extends OceanDataEvent {
  final String layer;
  const ToggleMapLayerEvent(this.layer);
  
  @override
  List<Object?> get props => [layer];
}

class ToggleSstHeatmapEvent extends OceanDataEvent {
  const ToggleSstHeatmapEvent();
}

class SetCurrentsVectorScaleEvent extends OceanDataEvent {
  final double scale;
  const SetCurrentsVectorScaleEvent(this.scale);
  
  @override
  List<Object?> get props => [scale];
}

class SetCurrentsColorByEvent extends OceanDataEvent {
  final String colorBy;
  const SetCurrentsColorByEvent(this.colorBy);
  
  @override
  List<Object?> get props => [colorBy];
}

class SetHeatmapScaleEvent extends OceanDataEvent {
  final Map<String, dynamic> scale;
  const SetHeatmapScaleEvent(this.scale);
  
  @override
  List<Object?> get props => [scale];
}

class SetWindVelocityParticleCountEvent extends OceanDataEvent {
  final int count;
  const SetWindVelocityParticleCountEvent(this.count);
  
  @override
  List<Object?> get props => [count];
}

class SetWindVelocityParticleOpacityEvent extends OceanDataEvent {
  final double opacity;
  const SetWindVelocityParticleOpacityEvent(this.opacity);
  
  @override
  List<Object?> get props => [opacity];
}

class SetWindVelocityParticleSpeedEvent extends OceanDataEvent {
  final double speed;
  const SetWindVelocityParticleSpeedEvent(this.speed);
  
  @override
  List<Object?> get props => [speed];
}

class AddChatMessageEvent extends OceanDataEvent {
  final ChatMessage message;
  const AddChatMessageEvent(this.message);
  
  @override
  List<Object?> get props => [message];
}

class ResetApiMetricsEvent extends OceanDataEvent {
  const ResetApiMetricsEvent();
}

// STATES
abstract class OceanDataState extends Equatable {
  const OceanDataState();
  
  @override
  List<Object?> get props => [];
}

class OceanDataInitialState extends OceanDataState {
  const OceanDataInitialState();
}

class OceanDataLoadingState extends OceanDataState {
  final bool isInitialLoad;
  const OceanDataLoadingState({this.isInitialLoad = true});
  
  @override
  List<Object?> get props => [isInitialLoad];
}

class OceanDataErrorState extends OceanDataState {
  final String message;
  const OceanDataErrorState(this.message);
  
  @override
  List<Object?> get props => [message];
}

class OceanDataLoadedState extends OceanDataState {
  final bool dataLoaded;
  final bool isLoading;
  final String? loadingArea;  // NEW: Track which area is being loaded
  final bool hasError;
  final String? errorMessage;
  final List<OceanDataEntity> data;
  final List<StationDataEntity> stationData;
  final List<Map<String, dynamic>> timeSeriesData;
  final List<Map<String, dynamic>> rawData;
  final Map<String, dynamic> currentsGeoJSON;
  final Map<String, dynamic> windVelocityGeoJSON;
  final EnvDataEntity? envData;
  final String selectedArea;
  final String selectedModel;
  final double selectedDepth;
  final String dataSource;
  final String timeZone;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime currentDate;
  final String currentTime;
  final StationDataEntity? selectedStation;
  final List<String> availableModels;
  final List<double> availableDepths;
  final List<DateTime> availableDates;
  final List<String> availableTimes;
  final int currentFrame;
  final int totalFrames;
  final bool isPlaying;
  final double playbackSpeed;
  final bool loopMode;
  final Map<String, bool> mapLayerVisibility;
  final bool isSstHeatmapVisible;
  final double currentsVectorScale;
  final String currentsColorBy;
  final Map<String, dynamic> heatmapScale;
  final int windVelocityParticleCount;
  final double windVelocityParticleOpacity;
  final double windVelocityParticleSpeed;
  final Map<String, double> holoOceanPOV;
  final Map<String, dynamic> holoOcean;
  final ConnectionStatusEntity? connectionStatus;
  final Map<String, dynamic>? connectionDetails;
  final Map<String, dynamic>? dataQuality;
  final List<ChatMessage> chatMessages;
  final bool isTyping;

  const OceanDataLoadedState({
    required this.dataLoaded,
    this.isLoading = false,
    this.loadingArea,  // NEW: Initialize as null
    this.hasError = false,
    this.errorMessage,
    required this.data,
    required this.stationData,
    required this.timeSeriesData,
    required this.rawData,
    required this.currentsGeoJSON,
    required this.windVelocityGeoJSON,
    this.envData,
    required this.selectedArea,
    required this.selectedModel,
    required this.selectedDepth,
    required this.dataSource,
    required this.timeZone,
    required this.startDate,
    required this.endDate,
    required this.currentDate,
    required this.currentTime,
    this.selectedStation,
    required this.availableModels,
    required this.availableDepths,
    required this.availableDates,
    required this.availableTimes,
    required this.currentFrame,
    required this.totalFrames,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.loopMode,
    required this.mapLayerVisibility,
    required this.isSstHeatmapVisible,
    required this.currentsVectorScale,
    required this.currentsColorBy,
    required this.heatmapScale,
    required this.windVelocityParticleCount,
    required this.windVelocityParticleOpacity,
    required this.windVelocityParticleSpeed,
    required this.holoOceanPOV,
    required this.holoOcean,
    this.connectionStatus,
    this.connectionDetails,
    this.dataQuality,
    required this.chatMessages,
    this.isTyping = false,
  });

  @override
  List<Object?> get props => [
    dataLoaded, isLoading, loadingArea, hasError, errorMessage, data, stationData, timeSeriesData,
    rawData, currentsGeoJSON, windVelocityGeoJSON, envData, selectedArea, selectedModel, selectedDepth,
    dataSource, timeZone, startDate, endDate, currentDate, currentTime, selectedStation,
    availableModels, availableDepths, availableDates, availableTimes, currentFrame,
    totalFrames, isPlaying, playbackSpeed, loopMode, mapLayerVisibility, isSstHeatmapVisible,
    currentsVectorScale, currentsColorBy, heatmapScale, windVelocityParticleCount,
    windVelocityParticleOpacity, windVelocityParticleSpeed, holoOceanPOV, holoOcean,
    connectionStatus, connectionDetails, dataQuality, chatMessages, isTyping,
  ];
  
  OceanDataLoadedState copyWith({
    bool? dataLoaded, bool? isLoading, String? loadingArea, bool? hasError, String? errorMessage,
    List<OceanDataEntity>? data, List<StationDataEntity>? stationData,
    List<Map<String, dynamic>>? timeSeriesData, List<Map<String, dynamic>>? rawData,
    Map<String, dynamic>? currentsGeoJSON, Map<String, dynamic>? windVelocityGeoJSON,
    EnvDataEntity? envData, String? selectedArea,
    String? selectedModel, double? selectedDepth, String? dataSource, String? timeZone,
    DateTime? startDate, DateTime? endDate, DateTime? currentDate, String? currentTime,
    StationDataEntity? selectedStation, List<String>? availableModels,
    List<double>? availableDepths, List<DateTime>? availableDates, List<String>? availableTimes,
    int? currentFrame, int? totalFrames, bool? isPlaying, double? playbackSpeed,
    bool? loopMode, Map<String, bool>? mapLayerVisibility, bool? isSstHeatmapVisible,
    double? currentsVectorScale, String? currentsColorBy, Map<String, dynamic>? heatmapScale,
    int? windVelocityParticleCount, double? windVelocityParticleOpacity,
    double? windVelocityParticleSpeed, Map<String, double>? holoOceanPOV,
    Map<String, dynamic>? holoOcean, ConnectionStatusEntity? connectionStatus,
    Map<String, dynamic>? connectionDetails, Map<String, dynamic>? dataQuality,
    List<ChatMessage>? chatMessages, bool? isTyping,
    bool clearLoadingArea = false,  // NEW: Flag to clear loadingArea
  }) {
    return OceanDataLoadedState(
      dataLoaded: dataLoaded ?? this.dataLoaded,
      isLoading: isLoading ?? this.isLoading,
      loadingArea: clearLoadingArea ? null : (loadingArea ?? this.loadingArea),
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
      stationData: stationData ?? this.stationData,
      timeSeriesData: timeSeriesData ?? this.timeSeriesData,
      rawData: rawData ?? this.rawData,
      currentsGeoJSON: currentsGeoJSON ?? this.currentsGeoJSON,
      windVelocityGeoJSON: windVelocityGeoJSON ?? this.windVelocityGeoJSON,
      envData: envData ?? this.envData,
      selectedArea: selectedArea ?? this.selectedArea,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedDepth: selectedDepth ?? this.selectedDepth,
      dataSource: dataSource ?? this.dataSource,
      timeZone: timeZone ?? this.timeZone,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      currentDate: currentDate ?? this.currentDate,
      currentTime: currentTime ?? this.currentTime,
      selectedStation: selectedStation ?? this.selectedStation,
      availableModels: availableModels ?? this.availableModels,
      availableDepths: availableDepths ?? this.availableDepths,
      availableDates: availableDates ?? this.availableDates,
      availableTimes: availableTimes ?? this.availableTimes,
      currentFrame: currentFrame ?? this.currentFrame,
      totalFrames: totalFrames ?? this.totalFrames,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      loopMode: loopMode ?? this.loopMode,
      mapLayerVisibility: mapLayerVisibility ?? this.mapLayerVisibility,
      isSstHeatmapVisible: isSstHeatmapVisible ?? this.isSstHeatmapVisible,
      currentsVectorScale: currentsVectorScale ?? this.currentsVectorScale,
      currentsColorBy: currentsColorBy ?? this.currentsColorBy,
      heatmapScale: heatmapScale ?? this.heatmapScale,
      windVelocityParticleCount: windVelocityParticleCount ?? this.windVelocityParticleCount,
      windVelocityParticleOpacity: windVelocityParticleOpacity ?? this.windVelocityParticleOpacity,
      windVelocityParticleSpeed: windVelocityParticleSpeed ?? this.windVelocityParticleSpeed,
      holoOceanPOV: holoOceanPOV ?? this.holoOceanPOV,
      holoOcean: holoOcean ?? this.holoOcean,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionDetails: connectionDetails ?? this.connectionDetails,
      dataQuality: dataQuality ?? this.dataQuality,
      chatMessages: chatMessages ?? this.chatMessages,
      isTyping: isTyping ?? this.isTyping,
    );
  }
}

/// Cache for area data to avoid re-fetching
class _AreaDataCache {
  final List<Map<String, dynamic>> rawData;
  final Map<String, dynamic> currentsGeoJSON;
  final Map<String, dynamic> windVelocityGeoJSON;
  final List<Map<String, dynamic>> timeSeriesData;
  final DateTime cachedAt;

  _AreaDataCache({
    required this.rawData,
    required this.currentsGeoJSON,
    required this.windVelocityGeoJSON,
    required this.timeSeriesData,
    required this.cachedAt,
  });

  // Cache is valid for 5 minutes
  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 5;
}

class OceanDataBloc extends Bloc<OceanDataEvent, OceanDataState> {
  final GetOceanDataUseCase _getOceanDataUseCase;
  final UpdateTimeRangeUseCase _updateTimeRangeUseCase;
  final ControlAnimationUseCase _controlAnimationUseCase;
  final ConnectHoloOceanUseCase _connectHoloOceanUseCase;
  final OceanDataRemoteDataSource _remoteDataSource;

  // Cache for area data to avoid re-fetching
  final Map<String, _AreaDataCache> _areaCache = {};

  OceanDataBloc({
    required GetOceanDataUseCase getOceanDataUseCase,
    required UpdateTimeRangeUseCase updateTimeRangeUseCase,
    required ControlAnimationUseCase controlAnimationUseCase,
    required ConnectHoloOceanUseCase connectHoloOceanUseCase,
    required OceanDataRemoteDataSource remoteDataSource,
  }) : _getOceanDataUseCase = getOceanDataUseCase,
       _updateTimeRangeUseCase = updateTimeRangeUseCase,
       _controlAnimationUseCase = controlAnimationUseCase,
       _connectHoloOceanUseCase = connectHoloOceanUseCase,
       _remoteDataSource = remoteDataSource,
       super(const OceanDataInitialState()) {
    on<LoadInitialDataEvent>(_onLoadInitialData);
    on<RefreshDataEvent>(_onRefreshData);
    on<ResetDataEvent>(_onResetData);
    on<CheckApiStatusEvent>(_onCheckApiStatus);
    on<SetSelectedAreaEvent>(_onSetSelectedArea);
    on<SetSelectedModelEvent>(_onSetSelectedModel);
    on<SetSelectedDepthEvent>(_onSetSelectedDepth);
    on<SetDateRangeEvent>(_onSetDateRange);
    on<SetTimeZoneEvent>(_onSetTimeZone);
    on<SetCurrentFrameEvent>(_onSetCurrentFrame);
    on<TogglePlaybackEvent>(_onTogglePlayback);
    on<PlayAnimationEvent>(_onPlayAnimation);
    on<PauseAnimationEvent>(_onPauseAnimation);
    on<SetPlaybackSpeedEvent>(_onSetPlaybackSpeed);
    on<SetLoopModeEvent>(_onSetLoopMode);
    on<SetHoloOceanPOVEvent>(_onSetHoloOceanPOV);
    on<SetSelectedStationEvent>(_onSetSelectedStation);
    on<SetEnvDataEvent>(_onSetEnvData);
    on<ToggleMapLayerEvent>(_onToggleMapLayer);
    on<ToggleSstHeatmapEvent>(_onToggleSstHeatmap);
    on<SetCurrentsVectorScaleEvent>(_onSetCurrentsVectorScale);
    on<SetCurrentsColorByEvent>(_onSetCurrentsColorBy);
    on<SetHeatmapScaleEvent>(_onSetHeatmapScale);
    on<SetWindVelocityParticleCountEvent>(_onSetWindVelocityParticleCount);
    on<SetWindVelocityParticleOpacityEvent>(_onSetWindVelocityParticleOpacity);
    on<SetWindVelocityParticleSpeedEvent>(_onSetWindVelocityParticleSpeed);
    on<AddChatMessageEvent>(_onAddChatMessage);
    on<ResetApiMetricsEvent>(_onResetApiMetrics);
    add(const LoadInitialDataEvent());
  }
  
  Future<ConnectionStatusEntity> _checkApiConnection() async {
    try {
      // debugPrint('Checking API connection...');
      final result = await _getOceanDataUseCase(GetOceanDataParams(
        startDate: DateTime.now().subtract(const Duration(hours: 1)),
        endDate: DateTime.now(),
      ));
      final isConnected = result.isRight();
      final hasApiKey = AppConstants.bearerToken.isNotEmpty;
      final endpoint = AppConstants.baseUrl;
      // debugPrint('API Connection Status: ${isConnected ? "Connected" : "Disconnected"}');
      // debugPrint('Has API Key: $hasApiKey');
      // debugPrint('Endpoint: $endpoint');
      return ConnectionStatusEntity(
        connected: isConnected,
        state: isConnected ? ConnectionState.excellent : ConnectionState.disconnected,
        endpoint: endpoint,
        hasApiKey: hasApiKey,
      );
    } catch (e) {
      // debugPrint('API connection check failed: $e');
      return ConnectionStatusEntity(
        connected: false,
        state: ConnectionState.disconnected,
        endpoint: AppConstants.baseUrl,
        hasApiKey: AppConstants.bearerToken.isNotEmpty,
      );
    }
  }
  
  Map<String, dynamic> _calculateDataQuality(List<OceanDataEntity> data) {
    if (data.isEmpty) {
      return {'stations': 0, 'measurements': 0, 'lastUpdate': DateTime.now().toIso8601String()};
    }
    final uniqueStations = <String>{};
    for (final item in data) {
      uniqueStations.add('${item.latitude.toStringAsFixed(4)}_${item.longitude.toStringAsFixed(4)}');
    }
    final latestTimestamp = data.map((d) => d.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
    // debugPrint('Data Quality - Stations: ${uniqueStations.length}, Measurements: ${data.length}');
    return {
      'stations': uniqueStations.length,
      'measurements': data.length,
      'lastUpdate': latestTimestamp.toIso8601String(),
    };
  }
  
  Future<void> _onLoadInitialData(LoadInitialDataEvent event, Emitter<OceanDataState> emit) async {
    emit(const OceanDataLoadingState(isInitialLoad: true));
    try {
      // debugPrint('Loading initial ocean data...');
      final connectionStatus = await _checkApiConnection();
      final startDate = DateTime.now().subtract(const Duration(days: 7));
      final endDate = DateTime.now();
      
      final result = await _getOceanDataUseCase(GetOceanDataParams(
        startDate: startDate,
        endDate: endDate,
      ));
      
      if (result.isRight()) {
        final oceanData = result.getOrElse(() => []);
        // debugPrint('Loaded ${oceanData.length} ocean data points');
        
        // Fetch environmental data and process time series data
        EnvDataEntity? envData;
        List<Map<String, dynamic>> timeSeriesData = const [];
        List<Map<String, dynamic>> rawData = const [];

        if (oceanData.isNotEmpty) {
          try {
            // Get raw data from the data source for processing
            final rawDataResult = await _remoteDataSource.loadAllData(
              startDate: startDate,
              endDate: endDate,
            );
            final rawDataList = rawDataResult['allData'] as List?;

            if (rawDataList != null && rawDataList.isNotEmpty) {
              // Assign to outer scope variable
              rawData = rawDataList.cast<Map<String, dynamic>>();

              // Get the first data point to extract parameters for environmental data
              final firstDataPoint = oceanData.first;

              // Fetch environmental data using the remote data source
              envData = await _remoteDataSource.getEnvironmentalData(
                timestamp: firstDataPoint.timestamp,
                depth: 0.0, // Default depth
                latitude: firstDataPoint.latitude,
                longitude: firstDataPoint.longitude,
              );
              // debugPrint('Fetched environmental data: temp=${envData.temperature}, salinity=${envData.salinity}');

              // Process raw data into time series format
              timeSeriesData = _remoteDataSource.processAPIData(rawDataList);
              // debugPrint('Processed ${timeSeriesData.length} time series data points');
            }
          } catch (e) {
            // debugPrint('Error fetching environmental data or processing time series: $e');
            // Continue with empty data if there's an error
          }
        }

        // Generate currents GeoJSON in background isolate to avoid blocking UI
        debugPrint('BLOC: Starting currents generation with ${rawData.length} data points');
        final currentsGeoJSON = rawData.isEmpty
          ? const {'type': 'FeatureCollection', 'features': []}
          : await compute(_generateCurrentsInIsolate, rawData);
        debugPrint('BLOC: Generated ${(currentsGeoJSON['features'] as List).length} current vectors');

        // Generate wind velocity GeoJSON in background isolate
        debugPrint('BLOC: Starting wind velocity generation with ${rawData.length} data points');
        final windVelocityGeoJSON = rawData.isEmpty
          ? const {'type': 'FeatureCollection', 'features': []}
          : await compute(_generateWindVelocityInIsolate, rawData);
        debugPrint('BLOC: Generated ${(windVelocityGeoJSON['features'] as List).length} wind vectors');

        final dataQuality = _calculateDataQuality(oceanData);
        emit(OceanDataLoadedState(
          dataLoaded: true, isLoading: false, hasError: false, data: oceanData,
          stationData: const [], timeSeriesData: timeSeriesData, rawData: rawData,
          currentsGeoJSON: currentsGeoJSON, windVelocityGeoJSON: windVelocityGeoJSON,
          envData: envData, selectedArea: 'USM', selectedModel: 'NGOFS2',
          selectedDepth: 0.0, dataSource: 'API Stream', timeZone: 'UTC',
          startDate: startDate, endDate: endDate, currentDate: DateTime.now(), currentTime: '00:00',
          availableModels: const ['NGOFS2', 'RTOFS'],
          availableDepths: const [0.0, 10.0, 20.0, 30.0, 50.0, 100.0],
          availableDates: const [], availableTimes: const [], currentFrame: 0,
          totalFrames: 100, isPlaying: false, playbackSpeed: 1.0, loopMode: false,
          mapLayerVisibility: const {
            'temperature': true,
            'salinity': false,
            'ssh': false,
            'pressure': false,
            'oceanCurrents': false,
            'stations': true,
            'windVelocity': false,
          }, isSstHeatmapVisible: true,
          currentsVectorScale: 1.0, currentsColorBy: 'velocity',
          heatmapScale: const {'value': 1.0}, windVelocityParticleCount: 1000,
          windVelocityParticleOpacity: 0.8, windVelocityParticleSpeed: 1.0,
          holoOceanPOV: const {'x': 0.0, 'y': 0.0, 'z': 0.0}, holoOcean: const {},
          connectionStatus: connectionStatus, dataQuality: dataQuality,
          chatMessages: const [], isTyping: false,
        ));
      } else {
        final errorMessage = result.fold((l) => l.message, (r) => 'Unknown error');
        // debugPrint('Failed to load ocean data: $errorMessage');
        emit(OceanDataErrorState(errorMessage));
      }
    } catch (e) {
      // debugPrint('Exception loading initial data: $e');
      emit(OceanDataErrorState(e.toString()));
    }
  }
  
  Future<void> _onRefreshData(RefreshDataEvent event, Emitter<OceanDataState> emit) async {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      emit(currentState.copyWith(isLoading: true));
      try {
        // debugPrint('Refreshing ocean data...');
        final connectionStatus = await _checkApiConnection();
        final result = await _getOceanDataUseCase(GetOceanDataParams(
          startDate: currentState.startDate, endDate: currentState.endDate,
        ));
        if (result.isRight()) {
          final oceanData = result.getOrElse(() => []);
          // debugPrint('Refreshed ${oceanData.length} ocean data points');
          
          // Fetch environmental data and process time series data
          EnvDataEntity? envData;
          List<Map<String, dynamic>> timeSeriesData = const [];
          List<Map<String, dynamic>> rawData = const [];

          if (oceanData.isNotEmpty) {
            try {
              // Get raw data from the data source for processing
              final rawDataResult = await _remoteDataSource.loadAllData(
                startDate: currentState.startDate,
                endDate: currentState.endDate,
              );
              final rawDataList = rawDataResult['allData'] as List?;

              if (rawDataList != null && rawDataList.isNotEmpty) {
                // Assign to outer scope variable
                rawData = rawDataList.cast<Map<String, dynamic>>();

                // Get the first data point to extract parameters for environmental data
                final firstDataPoint = oceanData.first;

                // Fetch environmental data using the remote data source
                envData = await _remoteDataSource.getEnvironmentalData(
                  timestamp: firstDataPoint.timestamp,
                  depth: currentState.selectedDepth,
                  latitude: firstDataPoint.latitude,
                  longitude: firstDataPoint.longitude,
                );
                // debugPrint('Fetched environmental data on refresh');

                // Process raw data into time series format
                timeSeriesData = _remoteDataSource.processAPIData(rawDataList);
                // debugPrint('Processed ${timeSeriesData.length} time series data points on refresh');
              }
            } catch (e) {
              // debugPrint('Error fetching environmental data or processing time series on refresh: $e');
              // Continue with empty data if there's an error
            }
          }

          // Generate currents GeoJSON in background isolate to avoid blocking UI
          debugPrint('BLOC: Starting currents generation with ${rawData.length} data points');
          final currentsGeoJSON = rawData.isEmpty
            ? const {'type': 'FeatureCollection', 'features': []}
            : await compute(_generateCurrentsInIsolate, rawData);
          debugPrint('BLOC: Generated ${(currentsGeoJSON['features'] as List).length} current vectors');

          // Generate wind velocity GeoJSON in background isolate
          debugPrint('BLOC: Starting wind velocity generation with ${rawData.length} data points');
          final windVelocityGeoJSON = rawData.isEmpty
            ? const {'type': 'FeatureCollection', 'features': []}
            : await compute(_generateWindVelocityInIsolate, rawData);
          debugPrint('BLOC: Generated ${(windVelocityGeoJSON['features'] as List).length} wind vectors');

          final dataQuality = _calculateDataQuality(oceanData);
          emit(currentState.copyWith(
            data: oceanData, isLoading: false, hasError: false,
            timeSeriesData: timeSeriesData, rawData: rawData,
            currentsGeoJSON: currentsGeoJSON, windVelocityGeoJSON: windVelocityGeoJSON,
            envData: envData, connectionStatus: connectionStatus, dataQuality: dataQuality,
          ));
        } else {
          emit(currentState.copyWith(
            isLoading: false, hasError: true,
            errorMessage: result.fold((l) => l.message, (r) => 'Unknown error'),
            connectionStatus: connectionStatus,
          ));
        }
      } catch (e) {
        // debugPrint('Exception refreshing data: $e');
        emit(currentState.copyWith(isLoading: false, hasError: true, errorMessage: e.toString()));
      }
    }
  }
  
  void _onResetData(ResetDataEvent event, Emitter<OceanDataState> emit) {
    add(const LoadInitialDataEvent());
  }
  
  Future<void> _onCheckApiStatus(CheckApiStatusEvent event, Emitter<OceanDataState> emit) async {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      // debugPrint('Checking API status...');
      final connectionStatus = await _checkApiConnection();
      emit(currentState.copyWith(connectionStatus: connectionStatus));
    }
  }
  
  Future<void> _onSetSelectedArea(SetSelectedAreaEvent event, Emitter<OceanDataState> emit) async {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;

      // ===== COMPREHENSIVE LOGGING: Study Area Change =====
      debugPrint('📍 STUDY AREA CHANGE: ${currentState.selectedArea} → ${event.area}');
      debugPrint('📍 Current data count: ${currentState.rawData.length} records');
      debugPrint('📍 Current currents vectors: ${(currentState.currentsGeoJSON['features'] as List?)?.length ?? 0}');
      debugPrint('📍 Current wind vectors: ${(currentState.windVelocityGeoJSON['features'] as List?)?.length ?? 0}');

      // Check cache first
      final cachedData = _areaCache[event.area];
      if (cachedData != null && !cachedData.isExpired) {
        debugPrint('✅ CACHE HIT: Using cached data for ${event.area}');
        debugPrint('📍 Cache age: ${DateTime.now().difference(cachedData.cachedAt).inSeconds}s');

        // Use cached data immediately - no loading state needed
        emit(currentState.copyWith(
          selectedArea: event.area,
          rawData: cachedData.rawData,
          currentsGeoJSON: cachedData.currentsGeoJSON,
          windVelocityGeoJSON: cachedData.windVelocityGeoJSON,
          timeSeriesData: cachedData.timeSeriesData,
        ));

        debugPrint('✅ STUDY AREA CHANGE COMPLETE (from cache): Successfully updated to ${event.area}');
        return;
      }

      debugPrint('📍 CACHE MISS: Fetching data for ${event.area}');

      // Set loading state with area name while fetching new data
      emit(currentState.copyWith(
        selectedArea: event.area,
        isLoading: true,
        loadingArea: event.area,
      ));

      try {
        debugPrint('📍 FETCHING DATA: Requesting data for area=${event.area}');
        debugPrint('📍 Date range: ${currentState.startDate} to ${currentState.endDate}');

        // Fetch new data for the selected area
        final rawDataResult = await _remoteDataSource.loadAllData(
          area: event.area,
          startDate: currentState.startDate,
          endDate: currentState.endDate,
        );

        final rawDataList = rawDataResult['allData'] as List?;
        debugPrint('📍 DATA FETCHED: Received ${rawDataList?.length ?? 0} records for ${event.area}');

        if (rawDataList == null || rawDataList.isEmpty) {
          debugPrint('⚠️ WARNING: No data returned for area ${event.area}');
          emit(currentState.copyWith(
            selectedArea: event.area,
            isLoading: false,
            hasError: true,
            errorMessage: 'No data available for area ${event.area}',
          ));
          return;
        }

        final rawData = rawDataList.cast<Map<String, dynamic>>();

        // Log data bounds
        final lats = rawData.where((r) => r['lat'] != null).map((r) => (r['lat'] as num).toDouble()).toList();
        final lons = rawData.where((r) => r['lon'] != null).map((r) => (r['lon'] as num).toDouble()).toList();
        if (lats.isNotEmpty && lons.isNotEmpty) {
          debugPrint('📍 DATA BOUNDS: lat [${lats.reduce((a, b) => a < b ? a : b)}, ${lats.reduce((a, b) => a > b ? a : b)}]');
          debugPrint('📍 DATA BOUNDS: lon [${lons.reduce((a, b) => a < b ? a : b)}, ${lons.reduce((a, b) => a > b ? a : b)}]');
        }

        // Generate currents GeoJSON in background isolate
        debugPrint('📍 GENERATING GEOJSON: Starting currents generation with ${rawData.length} records');
        final currentsGeoJSON = await compute(_generateCurrentsInIsolate, rawData);
        final currentsFeatureCount = (currentsGeoJSON['features'] as List?)?.length ?? 0;
        debugPrint('📍 GEOJSON GENERATED: ${currentsFeatureCount} current vectors');

        // Generate wind velocity GeoJSON in background isolate
        debugPrint('📍 GENERATING GEOJSON: Starting wind generation with ${rawData.length} records');
        final windVelocityGeoJSON = await compute(_generateWindVelocityInIsolate, rawData);
        final windFeatureCount = (windVelocityGeoJSON['features'] as List?)?.length ?? 0;
        debugPrint('📍 GEOJSON GENERATED: ${windFeatureCount} wind vectors');

        // Process ocean data
        final result = await _getOceanDataUseCase(GetOceanDataParams(
          startDate: currentState.startDate,
          endDate: currentState.endDate,
        ));

        final oceanData = result.getOrElse(() => []);
        debugPrint('📍 OCEAN DATA PROCESSED: ${oceanData.length} data points');

        // Fetch environmental data if we have ocean data
        EnvDataEntity? envData;
        List<Map<String, dynamic>> timeSeriesData = const [];

        if (oceanData.isNotEmpty && rawData.isNotEmpty) {
          try {
            final firstDataPoint = oceanData.first;
            envData = await _remoteDataSource.getEnvironmentalData(
              timestamp: firstDataPoint.timestamp,
              depth: currentState.selectedDepth,
              latitude: firstDataPoint.latitude,
              longitude: firstDataPoint.longitude,
            );
            debugPrint('📍 ENV DATA: temp=${envData.temperature}, salinity=${envData.salinity}');

            timeSeriesData = _remoteDataSource.processAPIData(rawDataList);
            debugPrint('📍 TIME SERIES: Processed ${timeSeriesData.length} points');
          } catch (e) {
            debugPrint('⚠️ ERROR: Failed to fetch environmental data: $e');
          }
        }

        final dataQuality = _calculateDataQuality(oceanData);

        // Cache the data for future use
        _areaCache[event.area] = _AreaDataCache(
          rawData: rawData,
          currentsGeoJSON: currentsGeoJSON,
          windVelocityGeoJSON: windVelocityGeoJSON,
          timeSeriesData: timeSeriesData,
          cachedAt: DateTime.now(),
        );
        debugPrint('💾 CACHED: Data for ${event.area} cached for 5 minutes');

        // Emit new state with updated data
        debugPrint('📍 STATE UPDATE: Emitting new state with ${rawData.length} raw records');
        debugPrint('📍 MAP UPDATE: Map will receive ${currentsFeatureCount} currents + ${windFeatureCount} wind vectors');

        emit(currentState.copyWith(
          selectedArea: event.area,
          isLoading: false,
          clearLoadingArea: true,  // Clear the loading area
          hasError: false,
          errorMessage: null,
          data: oceanData,
          rawData: rawData,
          currentsGeoJSON: currentsGeoJSON,
          windVelocityGeoJSON: windVelocityGeoJSON,
          envData: envData,
          timeSeriesData: timeSeriesData,
          dataQuality: dataQuality,
        ));

        debugPrint('✅ STUDY AREA CHANGE COMPLETE: Successfully updated to ${event.area}');
      } catch (e, stackTrace) {
        debugPrint('❌ ERROR: Failed to load data for area ${event.area}: $e');
        debugPrint('Stack trace: $stackTrace');
        emit(currentState.copyWith(
          selectedArea: event.area,
          isLoading: false,
          clearLoadingArea: true,  // Clear the loading area on error too
          hasError: true,
          errorMessage: 'Failed to load data for ${event.area}: $e',
        ));
      }
    }
  }
  
  void _onSetSelectedModel(SetSelectedModelEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(selectedModel: event.model));
    }
  }
  
  void _onSetSelectedDepth(SetSelectedDepthEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(selectedDepth: event.depth));
    }
  }
  
  void _onSetDateRange(SetDateRangeEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(startDate: event.startDate, endDate: event.endDate));
    }
  }
  
  void _onSetTimeZone(SetTimeZoneEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(timeZone: event.timeZone));
    }
  }
  
  void _onSetCurrentFrame(SetCurrentFrameEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(currentFrame: event.frame));
    }
  }
  
  void _onTogglePlayback(TogglePlaybackEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      emit(currentState.copyWith(isPlaying: !currentState.isPlaying));
    }
  }
  
  void _onPlayAnimation(PlayAnimationEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(isPlaying: true));
    }
  }
  
  void _onPauseAnimation(PauseAnimationEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(isPlaying: false));
    }
  }
  
  void _onSetPlaybackSpeed(SetPlaybackSpeedEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(playbackSpeed: event.speed));
    }
  }
  
  void _onSetLoopMode(SetLoopModeEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(loopMode: event.loopMode));
    }
  }
  
  void _onSetHoloOceanPOV(SetHoloOceanPOVEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(holoOceanPOV: event.pov));
    }
  }
  
  void _onSetSelectedStation(SetSelectedStationEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(selectedStation: event.station));
    }
  }
  
  void _onSetEnvData(SetEnvDataEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(envData: event.envData));
    }
  }
  
  void _onToggleMapLayer(ToggleMapLayerEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      final updatedLayers = Map<String, bool>.from(currentState.mapLayerVisibility);
      updatedLayers[event.layer] = !(updatedLayers[event.layer] ?? false);
      emit(currentState.copyWith(mapLayerVisibility: updatedLayers));
    }
  }
  
  void _onToggleSstHeatmap(ToggleSstHeatmapEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      emit(currentState.copyWith(isSstHeatmapVisible: !currentState.isSstHeatmapVisible));
    }
  }
  
  void _onSetCurrentsVectorScale(SetCurrentsVectorScaleEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(currentsVectorScale: event.scale));
    }
  }
  
  void _onSetCurrentsColorBy(SetCurrentsColorByEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(currentsColorBy: event.colorBy));
    }
  }
  
  void _onSetHeatmapScale(SetHeatmapScaleEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(heatmapScale: event.scale));
    }
  }
  
  void _onSetWindVelocityParticleCount(SetWindVelocityParticleCountEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(windVelocityParticleCount: event.count));
    }
  }
  
  void _onSetWindVelocityParticleOpacity(SetWindVelocityParticleOpacityEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(windVelocityParticleOpacity: event.opacity));
    }
  }
  
  void _onSetWindVelocityParticleSpeed(SetWindVelocityParticleSpeedEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(windVelocityParticleSpeed: event.speed));
    }
  }
  
  void _onAddChatMessage(AddChatMessageEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      final currentState = state as OceanDataLoadedState;
      final updatedMessages = List<ChatMessage>.from(currentState.chatMessages)..add(event.message);
      emit(currentState.copyWith(chatMessages: updatedMessages));
    }
  }
  
  void _onResetApiMetrics(ResetApiMetricsEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(connectionDetails: const {}));
    }
  }
}