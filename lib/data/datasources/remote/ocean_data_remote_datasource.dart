import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:usm_tap/core/constants/app_constants.dart';
import 'package:usm_tap/core/errors/exceptions.dart';
import 'package:usm_tap/domain/entities/station_data_entity.dart';
import 'package:usm_tap/domain/entities/ocean_data_entity.dart';
import 'package:usm_tap/domain/entities/env_data_entity.dart';

abstract class OceanDataRemoteDataSource {
  String getTableNameForArea(String areaName);

  Future<Map<String, dynamic>> loadAllData({
    String? area,
    DateTime? startDate,
    DateTime? endDate,
  });

  List<Map<String, dynamic>> processAPIData(
    List<dynamic> rawData, {
    double selectedDepth = 0,
    int? maxDataPoints,
  });

  List<Map<String, dynamic>> processVectorData(
    List<dynamic> rawData, {
    int? maxDataPoints,
    bool latestOnly = false,
    double gridResolution = 0.01,
    double? depthFilter,
    String magnitudeKey = 'nspeed',
    String directionKey = 'direction',
  });

  List<Map<String, dynamic>> processCurrentsData(
    List<dynamic> rawData, {
    int? maxDataPoints,
    bool latestOnly = false,
    double gridResolution = 0.01,
    double? depthFilter,
  });

  Map<String, dynamic> generateCurrentsVectorData(
    List<dynamic> rawData, {
    double vectorScale = 0.009,
    double minMagnitude = 0,
    String colorBy = 'speed',
    int maxVectors = 1000,
    double? depthFilter,
    String displayParameter = 'Current Speed',
    String? magnitudeKey,
    String? directionKey,
  });

  Map<String, dynamic> getCurrentsColorScale(
    List<Map<String, dynamic>> currentsData, {
    String colorBy = 'speed',
  });

  List<List<double>> generateTemperatureHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  });

  List<List<double>> generateSalinityHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  });

    List<List<double>> generateSshHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  });

  List<List<double>> generatePressureHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  });

  Map<String, dynamic> getTemperatureColorScale(
    List<Map<String, dynamic>> temperatureData,
  );

  List<Map<String, dynamic>> getLatestTemperatureReadings(
    List<dynamic> rawData, {
    int maxPoints = 1000,
  });

  String formatTimeForDisplay(dynamic time);

  bool isLikelyOnWater(double lat, double lon);

  List<Map<String, dynamic>> generateOptimizedStationDataFromAPI(List<dynamic> rawData);

  List<Map<String, dynamic>> validateOceanStations(
    List<Map<String, dynamic>> stations,
  );

  List<Map<String, dynamic>> generateStationDataFromAPI(List<dynamic> rawData);

  List<Map<String, dynamic>> generateStationDataFromAPINoGrouping(
    List<dynamic> rawData,
  );

  Map<String, dynamic> validateCoordinateData(List<dynamic> rawData);

  Future<List<OceanDataEntity>> getOceanData({DateTime? startDate, required String endDate});
  Future<List<dynamic>> getStations();
  Future<EnvDataEntity> getEnvironmentalData({DateTime? timestamp, double? depth, double? latitude, double? longitude});
  Future<List<dynamic>> getAvailableModels({required String stationId});
  Future<List<double>> getAvailableDepths(String stationId);
}


/// Ocean Data Service
/// Handles loading, processing, and validation of oceanographic data from the isdata.ai API.
class OceanDataRemoteDataSourceImpl implements OceanDataRemoteDataSource {
  final Dio _dio;
  late final ApiConfig _apiConfig;
  List<dynamic>? _cachedData;
  
  OceanDataRemoteDataSourceImpl(this._dio) {
    _initializeConfig();
  }
  
  void _initializeConfig() {
    // Security warning for production
    if (kReleaseMode && 
        AppConstants.baseUrl.isNotEmpty && 
        !AppConstants.baseUrl.startsWith('https://')) {
      // debugPrint('Insecure API endpoint configured for production environment. Please use https.');
    }
    
    _apiConfig = ApiConfig(
      baseUrl: AppConstants.baseUrl,
      endpoint: '/data/query',
      timeout: const Duration(minutes: 10), // 10 minutes
      retries: 2,
      token: AppConstants.bearerToken,
      database: AppConstants.blueDB,
    );
  }
  
  /// Maps ocean area names to database table names
  /// @param areaName - The selected ocean area
  /// @returns The corresponding database table name
  @override
  String getTableNameForArea(String areaName) {
    const areaTableMap = {
      'MBL': 'mbl_ngofs2',
      'MSR': 'msr_ngofs2',
      'USM': 'usm_ngofs2',
    };
    
    return areaTableMap[areaName] ?? areaTableMap['USM']!;
  }
  
  /// Loads data from the oceanographic API based on specified query parameters.
  /// @param queryParams - The query parameters for filtering data.
  /// @returns A promise that resolves to an object containing all the data rows from the API.
  @override
Future<Map<String, dynamic>> loadAllData({
  String? area,
  DateTime? startDate,
  DateTime? endDate,
}) async {
  final selectedArea = area ?? 'USM';
  final defaultStartDate = DateTime.parse('2025-07-31T00:00:00Z');
  final defaultEndDate = DateTime.parse('2025-08-01T00:00:00Z');
  final start = startDate ?? defaultStartDate;
  final end = endDate ?? defaultEndDate;

  final tableName = getTableNameForArea(selectedArea);

  // ===== COMPREHENSIVE LOGGING: Query Construction =====
  debugPrint('🌊 DATA SOURCE: loadAllData called');
  debugPrint('🌊 AREA: $selectedArea → TABLE: $tableName');
  debugPrint('🌊 DATE RANGE: ${start.toIso8601String()} to ${end.toIso8601String()}');

  final baseQuery = 'SELECT lat, lon, depth, direction, ndirection, salinity, temp, nspeed, time, ssh, pressure_dbars, sound_speed_ms FROM `${_apiConfig.database}.$tableName`';
  final whereClauses = <String>[];

  final startISO = start.toIso8601String();
  final endISO = end.toIso8601String();
  //whereClauses.add("time BETWEEN TIMESTAMP('$startISO') AND TIMESTAMP('$endISO')");

  String query = baseQuery;
  if (whereClauses.isNotEmpty) {
    query += ' WHERE ${whereClauses.join(' AND ')}';
  }
  query += ' ORDER BY time DESC LIMIT 10000';

  debugPrint('🌊 SQL QUERY: $query');
  debugPrint('🌊 API URL: ${_apiConfig.baseUrl}${_apiConfig.endpoint}');

  try {
    
    final response = await _dio.get(
      '${_apiConfig.baseUrl}${_apiConfig.endpoint}',
      queryParameters: {'query': query},
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_apiConfig.token}',
        },
        receiveTimeout: _apiConfig.timeout,
        validateStatus: (status) => true, // Accept all status codes to see response
      ),
    );
    
    // Log response details
    // debugPrint('=== API Response ===');
    // debugPrint('Status Code: ${response.statusCode}');
    // // debugPrint('Status Message: ${response.statusMessage}');
    // // debugPrint('Response Headers: ${response.headers}');
    // // debugPrint('Response Data Type: ${response.data.runtimeType}');
    //// debugPrint('Response Data: ${response.data}');
    
    if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
      final apiData = response.data as List;

      debugPrint('🌊 API RESPONSE: Status ${response.statusCode} - Received ${apiData.length} records');

      final allData = apiData.map((row) {
        final dataMap = row as Map<String, dynamic>;
        return {
          ...dataMap,
          'model': 'NGOFS2',
          'area': selectedArea,
          '_source_file': 'API_$selectedArea',
          '_loaded_at': DateTime.now().toIso8601String(),
        };
      }).toList();

      // Log sample data for verification
      if (allData.isNotEmpty) {
        final firstRecord = allData.first;
        debugPrint('🌊 SAMPLE RECORD: lat=${firstRecord['lat']}, lon=${firstRecord['lon']}, temp=${firstRecord['temp']}, area=${firstRecord['area']}');
      }

      // Log coordinate bounds
      final lats = allData.where((r) => r['lat'] != null).map((r) => (r['lat'] as num).toDouble()).toList();
      final lons = allData.where((r) => r['lon'] != null).map((r) => (r['lon'] as num).toDouble()).toList();
      if (lats.isNotEmpty && lons.isNotEmpty) {
        debugPrint('🌊 DATA BOUNDS: lat [${lats.reduce((a, b) => a < b ? a : b)}, ${lats.reduce((a, b) => a > b ? a : b)}]');
        debugPrint('🌊 DATA BOUNDS: lon [${lons.reduce((a, b) => a < b ? a : b)}, ${lons.reduce((a, b) => a > b ? a : b)}]');
      }

      _cachedData = allData;

      debugPrint('✅ DATA SOURCE: Successfully loaded ${allData.length} records for $selectedArea');

      return {'allData': allData};
    } else {
      debugPrint('❌ API ERROR: HTTP ${response.statusCode}: ${response.statusMessage}');
      throw ServerException('HTTP ${response.statusCode}: ${response.statusMessage}\nResponse: ${response.data}');
    }
  } catch (error) {
    debugPrint('❌ DATA SOURCE ERROR: ${error.runtimeType} - $error');
    if (error is DioException) {
      debugPrint('❌ DioException: ${error.message}');
      debugPrint('❌ Response: ${error.response?.data}');
    }
    return {'allData': []};
  }
}
  
  /// Processes raw data into a format suitable for time series charts.
  /// @param rawData - The raw data from the API.
  /// @param selectedDepth - The depth to filter the data by.
  /// @param maxDataPoints - Maximum number of data points to return (null = no limit).
  /// @returns An array of processed data points for visualization.
  @override
  List<Map<String, dynamic>> processAPIData(
    List<dynamic> rawData, {
    double selectedDepth = 0,
    int? maxDataPoints,
  }) {
    if (rawData.isEmpty) {
      // debugPrint('No data to process');
      return [];
    }
    
    var filteredData = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      if (data['nspeed'] == null || data['nspeed'] == '') {
        return false;
      }
      if (data['depth'] != null && selectedDepth != null) {
        final depthDiff = ((data['depth'] as num) - selectedDepth).abs();
        return depthDiff <= 5;
      }
      return true;
    }).toList();
    
    filteredData.sort((a, b) {
      final aData = a as Map<String, dynamic>;
      final bData = b as Map<String, dynamic>;
      if (aData['time'] == null || bData['time'] == null) return 0;
      return DateTime.parse(aData['time']).compareTo(DateTime.parse(bData['time']));
    });
    
    final recentData = maxDataPoints != null
        ? filteredData.skip(math.max(0, filteredData.length - maxDataPoints)).toList()
        : filteredData;
    
    final processedData = recentData.asMap().entries.map((entry) {
      final row = entry.value as Map<String, dynamic>;
      return {
        'depth': row['depth'] ?? 0,
        'time': formatTimeForDisplay(row['time']),
        'timestamp': row['time'] != null ? DateTime.parse(row['time']) : DateTime.now(),
        'heading': row['direction'] ?? 0,
        'currentSpeed': row['nspeed'] ?? 0,
        'soundSpeed': row['sound_speed_ms'] ?? 0,
        'waveHeight': row['ssh'] ?? 0,
        'temperature': row['temp'],
        'latitude': row['lat'],
        'longitude': row['lon'],
        'salinity': row['salinity'],
        'pressure': row['pressure_dbars'],
        'sourceFile': row['_source_file'],
        'model': row['model'],
        'area': row['area'],
      };
    }).toList();
    
    return processedData;
  }
  
  /// Generic processor for scalar data (like temperature, salinity) for heatmap generation.
  /// @param rawData - The raw data from the API.
  /// @param parameterKey - The key of the parameter to process (e.g., 'temp', 'salinity').
  /// @param options - Processing options.
  /// @returns Array of processed scalar data points.
  List<Map<String, dynamic>> _processScalarData(
    List<dynamic> rawData,
    String parameterKey, {
    int? maxDataPoints,
    bool latestOnly = false,
    double? depthFilter,
  }) {
    if (rawData.isEmpty) return [];
    
    var filteredData = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      return data['lat'] != null &&
             data['lon'] != null &&
             data[parameterKey] != null &&
             !double.parse(data['lat'].toString()).isNaN &&
             !double.parse(data['lon'].toString()).isNaN &&
             !double.parse(data[parameterKey].toString()).isNaN &&
             double.parse(data['lat'].toString()).abs() <= 90 &&
             double.parse(data['lon'].toString()).abs() <= 180;
    }).toList();
    
    if (depthFilter != null) {
      filteredData = filteredData.where((row) {
        final data = row as Map<String, dynamic>;
        return data['depth'] != null &&
               ((data['depth'] as num) - depthFilter).abs() <= 5;
      }).toList();
    }
    
    filteredData.sort((a, b) {
      final aData = a as Map<String, dynamic>;
      final bData = b as Map<String, dynamic>;
      return DateTime.parse(aData['time']).compareTo(DateTime.parse(bData['time']));
    });
    
    if (latestOnly) {
      final latestData = <String, Map<String, dynamic>>{};
      for (final row in filteredData) {
        final data = row as Map<String, dynamic>;
        final key = '${double.parse(data['lat'].toString()).toStringAsFixed(4)},${double.parse(data['lon'].toString()).toStringAsFixed(4)}';
        if (!latestData.containsKey(key) ||
            DateTime.parse(data['time']).isAfter(DateTime.parse(latestData[key]!['time']))) {
          latestData[key] = data;
        }
      }
      filteredData = latestData.values.toList();
    }
    
    if (maxDataPoints != null) {
      filteredData = filteredData.skip(math.max(0, filteredData.length - maxDataPoints)).toList();
    }
    
    return filteredData.map((row) {
      final data = row as Map<String, dynamic>;
      return {
        'latitude': data['lat'],
        'longitude': data['lon'],
        'value': data[parameterKey],
        'time': data['time'],
        'depth': data['depth'] ?? 0,
      };
    }).toList();
  }
  
  /// Processes vector data for map visualization with configurable field mapping
  /// @param rawData - The raw data from the API
  /// @param options - Processing options
  /// @returns Array of vector data points
  @override
  List<Map<String, dynamic>> processVectorData(
    List<dynamic> rawData, {
    int? maxDataPoints,
    bool latestOnly = false,
    double gridResolution = 0.01,
    double? depthFilter,
    String magnitudeKey = 'nspeed',
    String directionKey = 'direction',
  }) {
    if (rawData.isEmpty) return [];

    var vectorData = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      final magnitude = data[magnitudeKey];
      final direction = data[directionKey];

      // Require BOTH magnitude and direction to be non-null (like React)
      if (magnitude == null || direction == null) {
        return false;
      }

      final magValue = double.tryParse(magnitude.toString());
      final dirValue = double.tryParse(direction.toString());

      // Validate lat/lon and parsed values
      return data['lat'] != null &&
             data['lon'] != null &&
             magValue != null &&
             dirValue != null &&
             !magValue.isNaN &&
             !dirValue.isNaN &&
             double.parse(data['lat'].toString()).abs() <= 90 &&
             double.parse(data['lon'].toString()).abs() <= 180;
    }).toList();
    
    if (depthFilter != null) {
      vectorData = vectorData.where((row) {
        final data = row as Map<String, dynamic>;
        return data['depth'] != null &&
               ((data['depth'] as num) - depthFilter).abs() <= 5;
      }).toList();
    }
    
    vectorData.sort((a, b) {
      final aData = a as Map<String, dynamic>;
      final bData = b as Map<String, dynamic>;
      return DateTime.parse(aData['time']).compareTo(DateTime.parse(bData['time']));
    });
    
    if (gridResolution > 0) {
      final gridData = <String, Map<String, dynamic>>{};
      for (final row in vectorData) {
        final data = row as Map<String, dynamic>;
        final gridLat = (double.parse(data['lat'].toString()) / gridResolution).round() * gridResolution;
        final gridLon = (double.parse(data['lon'].toString()) / gridResolution).round() * gridResolution;
        final key = '$gridLat,$gridLon';
        if (!gridData.containsKey(key)) {
          gridData[key] = {
            'lat': gridLat,
            'lon': gridLon,
            'directions': <double>[],
            'magnitudes': <double>[],
            'times': <String>[],
            'depths': <double>[],
          };
        }
        final cell = gridData[key]!;
        // Use null coalescing for partial data
        final dirValue = data[directionKey] != null
            ? double.tryParse(data[directionKey].toString()) ?? 0.0
            : 0.0;
        final magValue = data[magnitudeKey] != null
            ? double.tryParse(data[magnitudeKey].toString()) ?? 0.0
            : 0.0;
        (cell['directions'] as List).add(dirValue);
        (cell['magnitudes'] as List).add(magValue);
        (cell['times'] as List).add(data['time']);
        (cell['depths'] as List).add(data['depth'] ?? 0);
      }
      
      vectorData = gridData.values.map((cell) {
        final directions = cell['directions'] as List<double>;
        final magnitudes = cell['magnitudes'] as List<double>;
        final times = cell['times'] as List<String>;
        final depths = cell['depths'] as List<double>;
        
        final newRow = {
          'lat': cell['lat'],
          'lon': cell['lon'],
          'time': (times..sort((a, b) => DateTime.parse(b).compareTo(DateTime.parse(a)))).first,
          'depth': depths.reduce((a, b) => a + b) / depths.length,
        };
        newRow[directionKey] = _calculateCircularMean(directions);
        newRow[magnitudeKey] = magnitudes.reduce((a, b) => a + b) / magnitudes.length;
        return newRow;
      }).toList();
    }
    
    if (latestOnly) {
      final latestData = <String, Map<String, dynamic>>{};
      for (final row in vectorData) {
        final data = row as Map<String, dynamic>;
        final key = '${double.parse(data['lat'].toString()).toStringAsFixed(4)},${double.parse(data['lon'].toString()).toStringAsFixed(4)}';
        if (!latestData.containsKey(key) ||
            DateTime.parse(data['time']).isAfter(DateTime.parse(latestData[key]!['time']))) {
          latestData[key] = data;
        }
      }
      vectorData = latestData.values.toList();
    }
    
    if (maxDataPoints != null) {
      vectorData = vectorData.skip(math.max(0, vectorData.length - maxDataPoints)).toList();
    }
    
    return vectorData.asMap().entries.map((entry) {
      final row = entry.value as Map<String, dynamic>;
      // Use null coalescing for partial data
      final direction = row[directionKey] != null
          ? double.tryParse(row[directionKey].toString()) ?? 0.0
          : 0.0;
      final magnitude = row[magnitudeKey] != null
          ? double.tryParse(row[magnitudeKey].toString()) ?? 0.0
          : 0.0;
      return {
        'id': 'vector_${entry.key}',
        'latitude': row['lat'],
        'longitude': row['lon'],
        'direction': direction,
        'speed': magnitude,
        'magnitude': magnitude,
        'time': row['time'],
        'depth': row['depth'] ?? 0,
        'coordinates': [row['lon'], row['lat']],
        'vectorX': math.sin((direction * math.pi) / 180),
        'vectorY': math.cos((direction * math.pi) / 180),
      };
    }).toList();
  }
  
  /// Legacy function for backwards compatibility
  @override
  List<Map<String, dynamic>> processCurrentsData(
    List<dynamic> rawData, {
    int? maxDataPoints,
    bool latestOnly = false,
    double gridResolution = 0.01,
    double? depthFilter,
  }) {
    return processVectorData(
      rawData,
      maxDataPoints: maxDataPoints,
      latestOnly: latestOnly,
      gridResolution: gridResolution,
      depthFilter: depthFilter,
      magnitudeKey: 'nspeed',
      directionKey: 'direction',
    );
  }
  
  /// Calculates circular mean for directional data (angles in degrees)
  /// @param angles - Array of angles in degrees
  /// @returns Circular mean in degrees
  double _calculateCircularMean(List<double> angles) {
    if (angles.isEmpty) return 0;
    double sumSin = 0;
    double sumCos = 0;
    
    for (final angle in angles) {
      final radians = (angle * math.pi) / 180;
      sumSin += math.sin(radians);
      sumCos += math.cos(radians);
    }
    
    final meanRadians = math.atan2(sumSin / angles.length, sumCos / angles.length);
    double meanDegrees = (meanRadians * 180) / math.pi;
    if (meanDegrees < 0) meanDegrees += 360;
    return meanDegrees;
  }
  
  /// Generates vector data optimized for Mapbox visualization with configurable field mapping
  /// @param rawData - The raw data from the API
  /// @param options - Generation options
  /// @returns GeoJSON-like object for Mapbox vector layers
  @override
  Map<String, dynamic> generateCurrentsVectorData(
    List<dynamic> rawData, {
    double vectorScale = 0.009,
    double minMagnitude = 0,
    String colorBy = 'speed',
    int maxVectors = 1000,
    double? depthFilter,
    String displayParameter = 'Current Speed',
    String? magnitudeKey,
    String? directionKey,
  }) {
    // Get field mappings based on display parameter
    final fieldMapping = _getFieldMapping(displayParameter);
    final finalMagnitudeKey = magnitudeKey ?? fieldMapping['magnitudeKey'] as String;
    final finalDirectionKey = directionKey ?? fieldMapping['directionKey'] as String;
    
    final vectorData = processVectorData(
      rawData,
      latestOnly: true,
      maxDataPoints: maxVectors,
      gridResolution: 0.01,
      depthFilter: depthFilter,
      magnitudeKey: finalMagnitudeKey,
      directionKey: finalDirectionKey,
    );
    
    if (vectorData.isEmpty) {
      return {'type': 'FeatureCollection', 'features': []};
    }
    
    final filteredVectors = vectorData.where((vector) => 
      (vector['magnitude'] as num) >= minMagnitude
    ).toList();
    
    final speeds = filteredVectors.map((c) => c['speed'] as num).toList();
    final depths = filteredVectors.map((c) => c['depth'] as num).toList();
    final maxSpeed = speeds.isEmpty ? 0 : speeds.reduce(math.max);
    final minSpeed = speeds.isEmpty ? 0 : speeds.reduce(math.min);
    final maxDepth = depths.isEmpty ? 0 : depths.reduce(math.max);
    final minDepth = depths.isEmpty ? 0 : depths.reduce(math.min);
    
    final features = filteredVectors.map((vector) {
      final vectorLength = (vector['magnitude'] as num) * vectorScale;
      final endLat = (vector['latitude'] as num) + ((vector['vectorY'] as num) * vectorLength);
      final endLon = (vector['longitude'] as num) + ((vector['vectorX'] as num) * vectorLength);
      
      double colorValue = 0.5;
      if (colorBy == 'speed' && maxSpeed > minSpeed) {
        colorValue = ((vector['speed'] as num) - minSpeed) / (maxSpeed - minSpeed);
      } else if (colorBy == 'depth' && maxDepth > minDepth) {
        colorValue = ((vector['depth'] as num) - minDepth) / (maxDepth - minDepth);
      }
      
      return {
        'type': 'Feature',
        'properties': {
          'id': vector['id'],
          'direction': vector['direction'],
          'speed': vector['speed'],
          'magnitude': vector['magnitude'],
          'depth': vector['depth'],
          'time': vector['time'],
          'colorValue': colorValue,
          'dataPointCount': vector['dataPointCount'] ?? 1,
        },
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [vector['longitude'], vector['latitude']],
            [endLon, endLat],
          ],
        },
      };
    }).toList();
    
    return {
      'type': 'FeatureCollection',
      'features': features,
      'metadata': {
        'vectorCount': features.length,
        'speedRange': {'min': minSpeed, 'max': maxSpeed},
        'depthRange': {'min': minDepth, 'max': maxDepth},
        'colorBy': colorBy,
        'displayParameter': displayParameter,
        'fieldMapping': {
          'magnitudeKey': finalMagnitudeKey,
          'directionKey': finalDirectionKey,
        },
      },
    };
  }
  
  /// Gets field mapping for different layer types
  /// @param displayParameter - The display parameter name
  /// @returns Field mapping configuration
  Map<String, String> _getFieldMapping(String displayParameter) {
    const mappings = {
      'Current Speed': {'magnitudeKey': 'nspeed', 'directionKey': 'direction'},
      'Current Direction': {'magnitudeKey': 'nspeed', 'directionKey': 'direction'},
      'Wind Speed': {'magnitudeKey': 'nspeed', 'directionKey': 'ndirection'},
      'Wind Direction': {'magnitudeKey': 'nspeed', 'directionKey': 'ndirection'},
      'Wave Direction': {'magnitudeKey': 'nspeed', 'directionKey': 'direction'},
      'Ocean Currents': {'magnitudeKey': 'nspeed', 'directionKey': 'direction'},
    };
    
    return (mappings[displayParameter] ?? mappings['Ocean Currents']!) as Map<String, String>;
  }
  
  /// Gets currents color scale configuration for visualization
  /// @param currentsData - Currents data for scale calculation
  /// @param colorBy - Property to base colors on ('speed', 'depth')
  /// @returns Color scale configuration
  @override
  Map<String, dynamic> getCurrentsColorScale(
    List<Map<String, dynamic>> currentsData, {
    String colorBy = 'speed',
  }) {
    if (currentsData.isEmpty) {
      return {
        'min': 0,
        'max': 10,
        'property': colorBy,
        'colors': [],
      };
    }
    
    final values = currentsData
        .map((d) => colorBy == 'speed' ? d['speed'] : d['depth'])
        .where((v) => v != null && !double.parse(v.toString()).isNaN)
        .map((v) => double.parse(v.toString()))
        .toList();
    
    final minValue = values.isEmpty ? 0 : values.reduce(math.min);
    final maxValue = values.isEmpty ? 10 : values.reduce(math.max);
    final midValue = (minValue + maxValue) / 2;
    
    return {
      'min': minValue,
      'max': maxValue,
      'mid': midValue,
      'property': colorBy,
      'gradient': colorBy == 'speed'
          ? ['rgb(0, 0, 255)', 'rgb(0, 255, 0)', 'rgb(255, 0, 0)']
          : ['rgb(255, 255, 0)', 'rgb(0, 255, 255)', 'rgb(0, 0, 255)'],
    };
  }
  
  /// Generic generator for heatmap data from any scalar parameter.
  /// @param rawData - The raw data from the API.
  /// @param parameterKey - The key of the data to visualize (e.g., 'temp', 'salinity').
  /// @param options - Heatmap generation options.
  /// @returns Array of [lat, lng, intensity] points for heatmap.
  List<List<double>> _generateScalarHeatmapData(
    List<dynamic> rawData,
    String parameterKey, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  }) {
    final processedData = _processScalarData(
      rawData,
      parameterKey,
      latestOnly: false,
      depthFilter: depthFilter,
    );
    
    if (processedData.isEmpty) return [];
    
    final values = processedData.map((d) => double.parse(d['value'].toString())).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    
    final gridData = <String, Map<String, dynamic>>{};
    for (final point in processedData) {
      final gridLat = (double.parse(point['latitude'].toString()) / gridResolution).round() * gridResolution;
      final gridLng = (double.parse(point['longitude'].toString()) / gridResolution).round() * gridResolution;
      final key = '$gridLat,$gridLng';
      if (!gridData.containsKey(key)) {
        gridData[key] = {
          'lat': gridLat,
          'lng': gridLng,
          'values': <double>[],
        };
      }
      (gridData[key]!['values'] as List).add(double.parse(point['value'].toString()));
    }
    
    return gridData.values.map((cell) {
      final values = cell['values'] as List<double>;
      final avgValue = values.reduce((a, b) => a + b) / values.length;
      double intensity = normalize && range > 0
          ? (avgValue - minVal) / range
          : avgValue * intensityScale;
      intensity = math.max(0, math.min(1, intensity));
      return [cell['lat'] as double, cell['lng'] as double, intensity];
    }).toList();
  }
  
  @override
  List<List<double>> generateTemperatureHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  }) =>
      _generateScalarHeatmapData(
        rawData,
        'temp',
        intensityScale: intensityScale,
        normalize: normalize,
        gridResolution: gridResolution,
        depthFilter: depthFilter,
      );
  
  @override
  List<List<double>> generateSalinityHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  }) =>
      _generateScalarHeatmapData(
        rawData,
        'salinity',
        intensityScale: intensityScale,
        normalize: normalize,
        gridResolution: gridResolution,
        depthFilter: depthFilter,
      );
  
  @override
  List<List<double>> generateSshHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  }) =>
      _generateScalarHeatmapData(
        rawData,
        'ssh',
        intensityScale: intensityScale,
        normalize: normalize,
        gridResolution: gridResolution,
        depthFilter: depthFilter,
      );
  
  @override
  List<List<double>> generatePressureHeatmapData(
    List<dynamic> rawData, {
    double intensityScale = 1.0,
    bool normalize = true,
    double gridResolution = 0.01,
    double? depthFilter,
  }) =>
      _generateScalarHeatmapData(
        rawData,
        'pressure_dbars',
        intensityScale: intensityScale,
        normalize: normalize,
        gridResolution: gridResolution,
        depthFilter: depthFilter,
      );
  
  /// Gets temperature color scale configuration for visualization
  /// @param temperatureData - Temperature data for scale calculation
  /// @returns Color scale configuration
  @override
  Map<String, dynamic> getTemperatureColorScale(
    List<Map<String, dynamic>> temperatureData,
  ) {
    final temperatures = temperatureData
        .map((d) => d['temperature'])
        .where((t) => t != null && !double.parse(t.toString()).isNaN)
        .map((t) => double.parse(t.toString()))
        .toList();
    
    if (temperatures.isEmpty) {
      return {
        'min': 0,
        'max': 30,
        'colors': [
          {'value': 0, 'color': '#0000FF'},
          {'value': 0.25, 'color': '#00FFFF'},
          {'value': 0.5, 'color': '#00FF00'},
          {'value': 0.75, 'color': '#FFFF00'},
          {'value': 1.0, 'color': '#FF0000'},
        ],
      };
    }
    
    final minTemp = temperatures.reduce(math.min);
    final maxTemp = temperatures.reduce(math.max);
    final midTemp = (minTemp + maxTemp) / 2;
    final quarterTemp = minTemp + (maxTemp - minTemp) * 0.25;
    final threeQuarterTemp = minTemp + (maxTemp - minTemp) * 0.75;
    
    return {
      'min': minTemp,
      'max': maxTemp,
      'mid': midTemp,
      'colors': [
        {'value': minTemp, 'color': '#0000FF'},
        {'value': quarterTemp, 'color': '#00FFFF'},
        {'value': midTemp, 'color': '#00FF00'},
        {'value': threeQuarterTemp, 'color': '#FFFF00'},
        {'value': maxTemp, 'color': '#FF0000'},
      ],
      'gradient': [
        'rgb(0, 0, 255)',
        'rgb(0, 255, 255)',
        'rgb(0, 255, 0)',
        'rgb(255, 255, 0)',
        'rgb(255, 0, 0)',
      ],
    };
  }
  
  /// Gets latest temperature readings grouped by location
  /// @param rawData - The raw data from the API
  /// @param maxPoints - Maximum points to return
  /// @returns Latest temperature readings per location
  @override
  List<Map<String, dynamic>> getLatestTemperatureReadings(
    List<dynamic> rawData, {
    int maxPoints = 1000,
  }) {
    final tempData = _processScalarData(
      rawData,
      'temp',
      latestOnly: true,
      maxDataPoints: maxPoints,
    );
    
    return tempData.asMap().entries.map((entry) {
      final point = entry.value;
      final value = double.parse(point['value'].toString());
      return {
        ...point,
        'temperature': value,
        'id': 'temp_${point['latitude']}_${point['longitude']}',
        'displayTemp': '${value.toStringAsFixed(1)}Â°C',
        'coordinates': [point['longitude'], point['latitude']],
      };
    }).toList();
  }
  
  /// Formats a timestamp for display in charts.
  /// @param time - The time value to format.
  /// @returns The formatted time string (HH:MM).
  @override
  String formatTimeForDisplay(dynamic time) {
    if (time == null) return '00:00';
    try {
      final dateTime = time is DateTime ? time : DateTime.parse(time.toString());
      return DateFormat('HH:mm').format(dateTime);
    } catch (error) {
      return '00:00';
    }
  }
  
  /// Simple land/water detection using basic geographic rules
  @override
  bool isLikelyOnWater(double lat, double lon) {
    // More permissive bounding box to ensure all relevant data is included.
    const gulfBounds = {'north': 31, 'south': 28, 'east': -86, 'west': -91};
    if (lat >= gulfBounds['south']! &&
        lat <= gulfBounds['north']! &&
        lon >= gulfBounds['west']! &&
        lon <= gulfBounds['east']!) {
      // A more precise cutout for the Mississippi River Delta landmass
      if (lat > 29 && lat < 29.8 && lon > -90 && lon < -89) {
        return false;
      }
      return true; // It's within the general Gulf area and not on the delta.
    }
    return false; // It's outside our primary area of interest.
  }
  
  /// Color stations based on data characteristics
  List<int> _getStationColor(int dataPointsLength) {
    if (dataPointsLength == 0) return [128, 128, 128];
    if (dataPointsLength > 1000) return [255, 69, 0];
    if (dataPointsLength > 500) return [255, 140, 0];
    if (dataPointsLength > 100) return [255, 215, 0];
    if (dataPointsLength > 10) return [0, 191, 255];
    return [0, 255, 127];
  }
  
  /// Rough water depth estimation
  double _estimateWaterDepth(double lat, double lon) {
    final distanceFromCoast = math.min((lat - 29.5).abs(), (lon - (-90)).abs());
    return math.min(distanceFromCoast * 100, 3000);
  }
  
  /// Enhanced station generation with water filtering and deployment filtering
  @override
  List<Map<String, dynamic>> generateOptimizedStationDataFromAPI(List<dynamic> rawData) {
    if (rawData.isEmpty) return [];
    
    final waterData = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      if (data['lat'] == null ||
          data['lon'] == null ||
          double.parse(data['lat'].toString()).isNaN ||
          double.parse(data['lon'].toString()).isNaN) return false;
      if (double.parse(data['lat'].toString()).abs() > 90 ||
          double.parse(data['lon'].toString()).abs() > 180) return false;
      if (!isLikelyOnWater(
        double.parse(data['lat'].toString()),
        double.parse(data['lon'].toString()),
      )) return false;
      if (data['status'] != null &&
          (data['status'] == 'pre-deployment' || data['status'] == 'post-recovery')) {
        return false;
      }
      return true;
    }).toList();
    
    final stations = <String, Map<String, dynamic>>{};
    int getOptimalPrecision(int dataCount) {
      if (dataCount > 50000) return 1;
      if (dataCount > 10000) return 2;
      if (dataCount > 1000) return 3;
      return 4;
    }
    
    final precision = getOptimalPrecision(waterData.length);
    final area = waterData.isNotEmpty ? waterData[0]['area'] : null;
    
    for (var i = 0; i < waterData.length; i++) {
      final row = waterData[i] as Map<String, dynamic>;
      final lat = double.parse(row['lat'].toString());
      final lon = double.parse(row['lon'].toString());
      final key = '${lat.toStringAsFixed(precision)},${lon.toStringAsFixed(precision)}';
      
      if (!stations.containsKey(key)) {
        final groupData = waterData.where((r) {
          final rData = r as Map<String, dynamic>;
          return (double.parse(rData['lat'].toString()) - lat).abs() < math.pow(10, -precision) &&
                 (double.parse(rData['lon'].toString()) - lon).abs() < math.pow(10, -precision);
        }).toList();
        
        final centroidLat = groupData.fold<double>(
              0,
              (sum, r) => sum + double.parse((r as Map<String, dynamic>)['lat'].toString()),
            ) /
            groupData.length;
        final centroidLon = groupData.fold<double>(
              0,
              (sum, r) => sum + double.parse((r as Map<String, dynamic>)['lon'].toString()),
            ) /
            groupData.length;
        
        stations[key] = {
          'name': 'Ocean Station ${stations.length + 1}',
          'coordinates': [centroidLon, centroidLat],
          'exactLat': centroidLat,
          'exactLon': centroidLon,
          'type': 'ocean_station',
          'color': _getStationColor(groupData.length),
          'dataPoints': 0,
          'sourceFiles': <String>{},
          'allDataPoints': <Map<String, dynamic>>[],
          'deploymentStatus': 'active',
          'waterDepth': _estimateWaterDepth(centroidLat, centroidLon),
          'model': 'NGOFS2',
          'area': area,
        };
      }
      
      final station = stations[key]!;
      station['dataPoints'] = (station['dataPoints'] as int) + 1;
      if (row['_source_file'] != null) {
        (station['sourceFiles'] as Set).add(row['_source_file']);
      }
      (station['allDataPoints'] as List).add({...row, 'rowIndex': i});
    }
    
    return stations.values.map((station) {
      return {
        ...station,
        'sourceFiles': (station['sourceFiles'] as Set).toList(),
      };
    }).toList();
  }
  
  /// Validate if coordinates represent real ocean monitoring locations
  @override
  List<Map<String, dynamic>> validateOceanStations(
    List<Map<String, dynamic>> stations,
  ) {
    return stations.map((station) {
      return {
        ...station,
        'validation': {
          'isOnWater': isLikelyOnWater(
            station['exactLat'] as double,
            station['exactLon'] as double,
          ),
          'hasData': (station['dataPoints'] as int) > 0,
          'isActive': station['deploymentStatus'] == 'active',
          'dataQuality': (station['dataPoints'] as int) > 10 ? 'good' : 'limited',
        },
      };
    }).toList();
  }
  
  /// Generates station locations from data by grouping nearby coordinates
  @override
  List<Map<String, dynamic>> generateStationDataFromAPI(List<dynamic> rawData) {
    if (rawData.isEmpty) return [];
    
    final stations = <String, Map<String, dynamic>>{};
    final area = rawData.isNotEmpty ? (rawData[0] as Map<String, dynamic>)['area'] : null;
    
    for (var i = 0; i < rawData.length; i++) {
      final row = rawData[i] as Map<String, dynamic>;
      if (row['lat'] != null &&
          row['lon'] != null &&
          !double.parse(row['lat'].toString()).isNaN &&
          !double.parse(row['lon'].toString()).isNaN) {
        const precision = 4;
        final lat = double.parse(row['lat'].toString());
        final lon = double.parse(row['lon'].toString());
        final key = '${lat.toStringAsFixed(precision)},${lon.toStringAsFixed(precision)}';
        
        if (!stations.containsKey(key)) {
          stations[key] = {
            'name': 'Station at ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}',
            'coordinates': [lon, lat],
            'exactLat': lat,
            'exactLon': lon,
            'type': 'api_station',
            'color': [
              math.Random().nextDouble() * 255,
              math.Random().nextDouble() * 255,
              math.Random().nextDouble() * 255,
            ],
            'dataPoints': 0,
            'sourceFiles': <String>{},
            'allDataPoints': <Map<String, dynamic>>[],
            'model': 'NGOFS2',
            'area': area,
          };
        }
        
        final station = stations[key]!;
        station['dataPoints'] = (station['dataPoints'] as int) + 1;
        if (row['_source_file'] != null) {
          (station['sourceFiles'] as Set).add(row['_source_file']);
        }
        (station['allDataPoints'] as List).add({...row, 'rowIndex': i});
      }
    }
    
    return stations.values.map((station) {
      return {
        ...station,
        'sourceFiles': (station['sourceFiles'] as Set).toList(),
      };
    }).toList();
  }
  
  /// Alternative version that creates individual stations for each unique coordinate
  @override
  List<Map<String, dynamic>> generateStationDataFromAPINoGrouping(
    List<dynamic> rawData,
  ) {
    if (rawData.isEmpty) return [];
    
    final stations = <Map<String, dynamic>>[];
    final seenCoordinates = <String>{};
    final area = rawData.isNotEmpty ? (rawData[0] as Map<String, dynamic>)['area'] : null;
    
    for (final row in rawData) {
      final data = row as Map<String, dynamic>;
      if (data['lat'] != null &&
          data['lon'] != null &&
          !double.parse(data['lat'].toString()).isNaN &&
          !double.parse(data['lon'].toString()).isNaN) {
        final lat = double.parse(data['lat'].toString());
        final lon = double.parse(data['lon'].toString());
        final coordKey = '${lat}_$lon';
        
        if (!seenCoordinates.contains(coordKey)) {
          seenCoordinates.add(coordKey);
          
          final matchingData = rawData.where((r) {
            final rData = r as Map<String, dynamic>;
            return rData['lat'] == data['lat'] && rData['lon'] == data['lon'];
          }).toList();
          
          stations.add({
            'name': 'Station ${stations.length + 1} (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
            'coordinates': [lon, lat],
            'exactLat': lat,
            'exactLon': lon,
            'type': 'api_station',
            'color': [
              math.Random().nextDouble() * 255,
              math.Random().nextDouble() * 255,
              math.Random().nextDouble() * 255,
            ],
            'dataPoints': matchingData.length,
            'sourceFiles': matchingData
                .map((r) => (r as Map<String, dynamic>)['_source_file'])
                .where((f) => f != null)
                .toSet()
                .toList(),
            'allDataPoints': matchingData,
            'model': 'NGOFS2',
            'area': area,
          });
        }
      }
    }
    
    return stations;
  }
  
  /// Debug function to validate coordinate data
  @override
  Map<String, dynamic> validateCoordinateData(List<dynamic> rawData) {
    final validCoords = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      return data['lat'] != null &&
             data['lon'] != null &&
             !double.parse(data['lat'].toString()).isNaN &&
             !double.parse(data['lon'].toString()).isNaN &&
             double.parse(data['lat'].toString()).abs() <= 90 &&
             double.parse(data['lon'].toString()).abs() <= 180;
    }).toList();
    
    final invalidCoords = rawData.where((row) {
      final data = row as Map<String, dynamic>;
      return data['lat'] == null ||
             data['lon'] == null ||
             double.parse(data['lat'].toString()).isNaN ||
             double.parse(data['lon'].toString()).isNaN ||
             double.parse(data['lat'].toString()).abs() > 90 ||
             double.parse(data['lon'].toString()).abs() > 180;
    }).toList();
    
    final validLatitudes = validCoords
        .map((r) => double.parse((r as Map<String, dynamic>)['lat'].toString()))
        .toList();
    final validLongitudes = validCoords
        .map((r) => double.parse((r as Map<String, dynamic>)['lon'].toString()))
        .toList();
    
    return {
      'total': rawData.length,
      'valid': validCoords.length,
      'invalid': invalidCoords.length,
      'validPercentage':
          (validCoords.length / rawData.length * 100).toStringAsFixed(1),
      'coordinateRanges': validCoords.isNotEmpty
          ? {
              'latitude': {
                'min': validLatitudes.reduce(math.min),
                'max': validLatitudes.reduce(math.max),
                'range': validLatitudes.reduce(math.max) -
                    validLatitudes.reduce(math.min),
              },
              'longitude': {
                'min': validLongitudes.reduce(math.min),
                'max': validLongitudes.reduce(math.max),
                'range': validLongitudes.reduce(math.max) -
                    validLongitudes.reduce(math.min),
              },
            }
          : null,
      'sampleValidCoords': validCoords.take(10).map((r) {
        final data = r as Map<String, dynamic>;
        return {'lat': data['lat'], 'lon': data['lon']};
      }).toList(),
      'sampleInvalidCoords': invalidCoords.take(5).map((r) {
        final data = r as Map<String, dynamic>;
        return {'lat': data['lat'], 'lon': data['lon']};
      }).toList(),
    };
  }

  @override
  Future<List<OceanDataEntity>> getOceanData({DateTime? startDate, required String endDate}) async {
    try {
      // debugPrint('Fetching ocean data from API...');
      final endDateTime = DateTime.parse(endDate);
      final result = await loadAllData(
        startDate: startDate,
        endDate: endDateTime,
      );
      
      final rawData = result['allData'] as List? ?? [];
      // debugPrint('Loaded ${rawData.length} data points from API');
      
      // Convert raw data to entities
      return rawData.map((item) {
        final data = item as Map<String, dynamic>;
        final timestamp = data['time'] != null 
            ? DateTime.parse(data['time']) 
            : DateTime.now();
        final lat = (data['lat'] as num?)?.toDouble() ?? 0.0;
        final lon = (data['lon'] as num?)?.toDouble() ?? 0.0;
        
        return OceanDataEntity(
          id: '${lat}_${lon}_${timestamp.millisecondsSinceEpoch}',
          timestamp: timestamp,
          latitude: lat,
          longitude: lon,
          depth: (data['depth'] as num?)?.toDouble() ?? 0.0,
          temperature: (data['temp'] as num?)?.toDouble(),
          salinity: (data['salinity'] as num?)?.toDouble(),
          pressure: (data['pressure_dbars'] as num?)?.toDouble(),
          additionalData: {
            'currentSpeed': data['nspeed'],
            'currentDirection': data['direction'],
            'windDirection': data['ndirection'],
            'ssh': data['ssh'],
            'soundSpeed': data['sound_speed_ms'],
            'model': data['model'],
            'area': data['area'],
            'sourceFile': data['_source_file'],
          },
        );
      }).toList();
    } catch (e) {
      // debugPrint('Error fetching ocean data: $e');
      throw ServerException('Failed to fetch ocean data: $e');
    }
  }

  @override
  Future<List<dynamic>> getStations() async {
    try {
      // debugPrint('Fetching stations from API...');
      final result = await loadAllData();
      final rawData = result['allData'] as List? ?? [];
      final stations = generateOptimizedStationDataFromAPI(rawData);
      // debugPrint('Generated ${stations.length} stations');
      return stations;
    } catch (e) {
      // debugPrint('Error fetching stations: $e');
      return [];
    }
  }

  @override
  Future<EnvDataEntity> getEnvironmentalData({
    DateTime? timestamp,
    double? depth,
    double? latitude,
    double? longitude,
  }) async {
    try {
      // debugPrint('Fetching environmental data...');
      
      if (_cachedData == null || _cachedData!.isEmpty) {
        final result = await loadAllData();
        _cachedData = result['allData'] as List?;
      }
      
      if (_cachedData == null || _cachedData!.isEmpty) {
        // debugPrint('No data available for environmental query');
        return EnvDataEntity(
          timestamp: timestamp ?? DateTime.now(),
          temperature: null,
          salinity: null,
          currentDirection: null,
          currentSpeed: null,
          windSpeed: null,
          windDirection: null,
          pressure: null,
        );
      }
      
      Map<String, dynamic>? selectedData;
      
      if (timestamp != null || latitude != null || longitude != null || depth != null) {
        List<Map<String, dynamic>> filteredData = _cachedData!.cast<Map<String, dynamic>>();
        
        if (depth != null) {
          filteredData = filteredData.where((item) {
            final itemDepth = (item['depth'] as num?)?.toDouble();
            return itemDepth != null && (itemDepth - depth).abs() < 5.0;
          }).toList();
        }
        
        if (latitude != null && longitude != null) {
          filteredData = filteredData.where((item) {
            final itemLat = (item['lat'] as num?)?.toDouble();
            final itemLon = (item['lon'] as num?)?.toDouble();
            if (itemLat == null || itemLon == null) return false;
            return (itemLat - latitude).abs() < 0.1 && (itemLon - longitude).abs() < 0.1;
          }).toList();
        }
        
        if (timestamp != null && filteredData.isNotEmpty) {
          filteredData.sort((a, b) {
            final aTime = a['time'] != null ? DateTime.parse(a['time']) : DateTime.now();
            final bTime = b['time'] != null ? DateTime.parse(b['time']) : DateTime.now();
            final aDiff = (aTime.difference(timestamp).inSeconds).abs();
            final bDiff = (bTime.difference(timestamp).inSeconds).abs();
            return aDiff.compareTo(bDiff);
          });
        }
        
        selectedData = filteredData.isNotEmpty ? filteredData.first : _cachedData!.first as Map<String, dynamic>;
      } else {
        selectedData = _cachedData!.first as Map<String, dynamic>;
      }
      
      final dataTimestamp = selectedData['time'] != null 
          ? DateTime.parse(selectedData['time']) 
          : timestamp ?? DateTime.now();
      
      // debugPrint('Environmental data point selected: temp=${selectedData['temp']}, salinity=${selectedData['salinity']}, depth=${selectedData['depth']}');
      
      return EnvDataEntity(
        timestamp: dataTimestamp,
        temperature: (selectedData['temp'] as num?)?.toDouble(),
        salinity: (selectedData['salinity'] as num?)?.toDouble(),
        currentDirection: (selectedData['direction'] as num?)?.toDouble(),
        currentSpeed: (selectedData['nspeed'] as num?)?.toDouble(),
        windSpeed: (selectedData['nspeed'] as num?)?.toDouble(),
        windDirection: (selectedData['ndirection'] as num?)?.toDouble(),
        pressure: (selectedData['pressure_dbars'] as num?)?.toDouble(),
        additionalData: {
          'ssh': selectedData['ssh'],
          'soundSpeed': selectedData['sound_speed_ms'],
          'depth': selectedData['depth'],
          'latitude': selectedData['lat'],
          'longitude': selectedData['lon'],
          'model': selectedData['model'],
          'area': selectedData['area'],
        },
      );
    } catch (e) {
      // debugPrint('Error fetching environmental data: $e');
      return EnvDataEntity(
        timestamp: timestamp ?? DateTime.now(),
        temperature: null,
        salinity: null,
        currentDirection: null,
        currentSpeed: null,
        windSpeed: null,
        windDirection: null,
        pressure: null,
      );
    }
  }

  @override
  Future<List<dynamic>> getAvailableModels({required String stationId}) async {
    return Future.value(['NGOFS2', 'RTOFS']);
  }

  @override
  Future<List<double>> getAvailableDepths(String stationId) async {
    return Future.value([0.0, 10.0, 20.0, 30.0, 50.0, 100.0]);
  }
}

/// API Configuration class
class ApiConfig {
  final String baseUrl;
  final String endpoint;
  final Duration timeout;
  final int retries;
  final String token;
  final String database;
  
  const ApiConfig({
    required this.baseUrl,
    required this.endpoint,
    required this.timeout,
    required this.retries,
    required this.token,
    required this.database,
  });
}