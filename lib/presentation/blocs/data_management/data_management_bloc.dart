import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../data/datasources/remote/ocean_data_remote_datasource.dart';
import '../../../domain/usecases/ocean_data/load_all_data_usecase.dart';
import '../auth/auth_bloc.dart';

// EVENTS
abstract class DataManagementEvent extends Equatable {
  const DataManagementEvent();
  
  @override
  List<Object?> get props => [];
}

class RefreshDataEvent extends DataManagementEvent {
  final String selectedArea;
  final String? selectedModel;
  final String? currentDate;
  final String? currentTime;
  final DateTime? startDate;
  final DateTime? endDate;
  
  const RefreshDataEvent({
    required this.selectedArea,
    this.selectedModel,
    this.currentDate,
    this.currentTime,
    this.startDate,
    this.endDate,
  });
  
  @override
  List<Object?> get props => [selectedArea, selectedModel, currentDate, currentTime, startDate, endDate];
}

class UpdateDataProcessingOptionsEvent extends DataManagementEvent {
  final Map<String, bool> options;
  const UpdateDataProcessingOptionsEvent(this.options);
  
  @override
  List<Object?> get props => [options];
}

class SetMaxDataPointsLimitEvent extends DataManagementEvent {
  final int? limit;
  const SetMaxDataPointsLimitEvent(this.limit);
  
  @override
  List<Object?> get props => [limit];
}

// STATES
abstract class DataManagementState extends Equatable {
  const DataManagementState();
  
  @override
  List<Object?> get props => [];
}

class DataManagementInitialState extends DataManagementState {
  const DataManagementInitialState();
}

class DataManagementLoadingState extends DataManagementState {
  const DataManagementLoadingState();
}

class DataManagementLoadedState extends DataManagementState {
  final List<Map<String, dynamic>> apiData;
  final bool dataLoaded;
  final String dataSource;
  final List<Map<String, dynamic>> generatedStationData;
  final bool isLoading;
  final String? errorMessage;
  final List<String> availableModels;
  final List<double> availableDepths;
  final List<String> availableDates;
  final List<String> availableTimes;
  final int? maxDataPoints;
  final Map<String, bool> dataProcessingOptions;
  final double? selectedDepth;
  final Map<String, dynamic>? selectedStation;
  
  const DataManagementLoadedState({
    required this.apiData,
    required this.dataLoaded,
    required this.dataSource,
    required this.generatedStationData,
    required this.isLoading,
    this.errorMessage,
    required this.availableModels,
    required this.availableDepths,
    required this.availableDates,
    required this.availableTimes,
    this.maxDataPoints,
    required this.dataProcessingOptions,
    this.selectedDepth,
    this.selectedStation,
  });
  
  // Formatted raw data
  List<Map<String, dynamic>> get rawData {
    return apiData.map((row) {
      return {
        ...row,
        'lat': _parseDouble(row['lat']),
        'lon': _parseDouble(row['lon']),
        'direction': _parseDouble(row['direction']),
        'speed': _parseDouble(row['speed']),
        'nspeed': _parseDouble(row['nspeed']),
        'ndirection': _parseDouble(row['ndirection']),
        'temp': _parseDouble(row['temp']),
        'salinity': _parseDouble(row['salinity']),
        'depth': _parseDouble(row['depth']),
        'ssh': _parseDouble(row['ssh']),
        'pressure_dbars': _parseDouble(row['pressure_dbars']),
        'sound_speed_ms': _parseDouble(row['sound_speed_ms']),
        'time': row['time'],
      };
    }).where((row) {
      final lat = row['lat'];
      final lon = row['lon'];
      return lat != null && !lat.isNaN && lon != null && !lon.isNaN;
    }).toList();
  }
  
  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed;
    }
    return null;
  }
  
  // Station-specific data filtering
  List<Map<String, dynamic>> get selectedStationEnvironmentalData {
    if (selectedStation == null || selectedStation!['coordinates'] == null || rawData.isEmpty) {
      return [];
    }
    
    final coordinates = selectedStation!['coordinates'] as List;
    final lon = coordinates[0] as double;
    final lat = coordinates[1] as double;
    
    return rawData.where((row) {
      final rowLon = row['lon'] as double?;
      final rowLat = row['lat'] as double?;
      if (rowLon == null || rowLat == null) return false;
      return (rowLon - lon).abs() < 1e-5 && (rowLat - lat).abs() < 1e-5;
    }).toList();
  }
  
  // Processed time series data
  List<Map<String, dynamic>> get processedTimeSeriesData {
    final sourceData = selectedStation != null
        ? selectedStationEnvironmentalData
        : rawData;
    
    if (sourceData.isEmpty || selectedDepth == null) {
      return [];
    }
    
    return _processAPIData(sourceData, selectedDepth!, maxDataPoints);
  }
  
  List<Map<String, dynamic>> _processAPIData(
    List<Map<String, dynamic>> data,
    double depth,
    int? maxPoints,
  ) {
    if (data.isEmpty) return [];
    
    var filtered = data.where((row) {
      final nspeed = row['nspeed'];
      if (nspeed == null || (nspeed is double && nspeed.isNaN)) return false;
      
      final rowDepth = row['depth'];
      if (rowDepth != null && depth != null) {
        final depthDiff = ((rowDepth as double) - depth).abs();
        return depthDiff <= 5;
      }
      return true;
    }).toList();
    
    filtered.sort((a, b) {
      final aTime = a['time'];
      final bTime = b['time'];
      if (aTime == null || bTime == null) return 0;
      return DateTime.parse(aTime).compareTo(DateTime.parse(bTime));
    });
    
    final recentData = maxPoints != null && filtered.length > maxPoints
        ? filtered.sublist(filtered.length - maxPoints)
        : filtered;
    
    return recentData.map((row) {
      return {
        'depth': row['depth'] ?? 0,
        'time': _formatTimeForDisplay(row['time']),
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
  }
  
  String _formatTimeForDisplay(dynamic time) {
    if (time == null) return '00:00';
    try {
      final dateTime = DateTime.parse(time.toString());
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '00:00';
    }
  }
  
  // Processed station data
  List<Map<String, dynamic>> get processedStationData {
    if (generatedStationData.isNotEmpty) {
      return generatedStationData;
    }
    return [
      {
        'name': 'USM-1 (Fallback)',
        'coordinates': [-89.1, 30.3],
        'color': [244, 63, 94],
        'type': 'usm',
      },
      {
        'name': 'NDBC-42012 (Fallback)',
        'coordinates': [-88.8, 30.1],
        'color': [251, 191, 36],
        'type': 'ndbc',
      },
    ];
  }
  
  // Currents data statistics
  Map<String, dynamic> get currentsDataStats {
    if (apiData.isEmpty) {
      return {
        'available': false,
        'count': 0,
        'coverage': 0,
      };
    }
    
    final recordsWithDirection = apiData.where((row) {
      final direction = row['direction'];
      return direction != null && (direction is! double || !direction.isNaN);
    }).length;
    
    final recordsWithSpeed = apiData.where((row) {
      final nspeed = row['nspeed'];
      return nspeed != null && (nspeed is! double || !nspeed.isNaN);
    }).length;
    
    final recordsWithBothCurrents = apiData.where((row) {
      final direction = row['direction'];
      final nspeed = row['nspeed'];
      return direction != null && (direction is! double || !direction.isNaN) &&
             nspeed != null && (nspeed is! double || !nspeed.isNaN);
    }).length;
    
    final coverage = apiData.isNotEmpty ? (recordsWithBothCurrents / apiData.length * 100) : 0.0;
    
    return {
      'available': recordsWithBothCurrents > 0,
      'count': recordsWithBothCurrents,
      'coverage': coverage.round(),
      'directionRecords': recordsWithDirection,
      'speedRecords': recordsWithSpeed,
      'totalRecords': apiData.length,
    };
  }
  
  // Data quality assessment
  Map<String, dynamic> get dataQuality {
    if (!dataLoaded) {
      return {
        'status': 'loading',
        'score': 0,
        'stations': 0,
        'measurements': 0,
        'lastUpdate': null,
        'coverage': {
          'temporal': 0,
          'spatial': 0,
          'depth': 0,
          'currents': 0,
        },
        'completeness': 0,
      };
    }
    
    final recordCount = apiData.length;
    final stationCount = generatedStationData.length;
    final lastUpdate = apiData.isNotEmpty && apiData.last['time'] != null
        ? DateTime.parse(apiData.last['time'])
        : null;
    
    final temporalCoverage = availableDates.length;
    final spatialCoverage = generatedStationData.length;
    final depthCoverage = availableDepths.length;
    final currentsCoverage = currentsDataStats['coverage'] as int;
    
    final completeRecords = apiData.where((row) =>
        row['lat'] != null && row['lon'] != null && row['nspeed'] != null && row['time'] != null
    ).length;
    final completeness = recordCount > 0 ? (completeRecords / recordCount * 100) : 0.0;
    
    String status;
    int score;
    if (recordCount == 0) {
      status = 'no-data';
      score = 0;
    } else if (recordCount < 100 || completeness < 50) {
      status = 'limited';
      score = 25;
    } else if (recordCount < 1000 || completeness < 80) {
      status = 'good';
      score = 75;
    } else {
      status = 'excellent';
      score = 95;
    }
    
    return {
      'status': status,
      'score': score,
      'stations': stationCount,
      'measurements': recordCount,
      'lastUpdate': lastUpdate,
      'coverage': {
        'temporal': temporalCoverage,
        'spatial': spatialCoverage,
        'depth': depthCoverage,
        'currents': currentsCoverage,
      },
      'completeness': completeness.round(),
    };
  }
  
  // Data statistics
  Map<String, dynamic>? get dataStatistics {
    if (apiData.isEmpty) return null;
    
    final measurements = apiData.where((row) => row['nspeed'] != null).length;
    final temperatures = apiData.where((row) => row['temp'] != null).length;
    final salinities = apiData.where((row) => row['salinity'] != null).length;
    final currentsData = apiData.where((row) =>
        row['direction'] != null && row['nspeed'] != null
    ).length;
    
    return {
      'totalRecords': apiData.length,
      'validMeasurements': measurements,
      'temperatureReadings': temperatures,
      'salinityReadings': salinities,
      'currentsReadings': currentsData,
      'dateRange': {
        'start': availableDates.isNotEmpty ? availableDates.first : null,
        'end': availableDates.isNotEmpty ? availableDates.last : null,
      },
      'depthRange': {
        'min': availableDepths.isNotEmpty ? availableDepths.reduce(math.min) : null,
        'max': availableDepths.isNotEmpty ? availableDepths.reduce(math.max) : null,
      },
      'models': availableModels,
      'sources': apiData.map((row) => row['_source_file']).where((f) => f != null).toSet().toList(),
      'currentsStats': currentsDataStats,
    };
  }
  
  // Data validation
  Map<String, dynamic> validateData() {
    if (apiData.isEmpty) {
      return {
        'valid': false,
        'errors': ['No data loaded'],
        'warnings': [],
      };
    }
    
    final errors = <String>[];
    final warnings = <String>[];
    
    final recordsWithCoords = apiData.where((row) => row['lat'] != null && row['lon'] != null).length;
    final recordsWithSpeed = apiData.where((row) => row['nspeed'] != null).length;
    final recordsWithTime = apiData.where((row) => row['time'] != null).length;
    final recordsWithDirection = apiData.where((row) => row['direction'] != null).length;
    
    if (recordsWithCoords == 0) errors.add('No valid coordinates found');
    if (recordsWithSpeed == 0) errors.add('No speed measurements found');
    if (recordsWithTime == 0) warnings.add('No timestamp data found');
    if (recordsWithDirection == 0) warnings.add('No current direction data found');
    
    if (recordsWithCoords < apiData.length * 0.8) {
      warnings.add('More than 20% of records missing coordinates');
    }
    if (recordsWithSpeed < apiData.length * 0.5) {
      warnings.add('More than 50% of records missing speed data');
    }
    if (recordsWithDirection < apiData.length * 0.5) {
      warnings.add('More than 50% of records missing direction data');
    }
    
    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'coverage': {
        'coordinates': (recordsWithCoords / apiData.length * 100).toStringAsFixed(1),
        'speed': (recordsWithSpeed / apiData.length * 100).toStringAsFixed(1),
        'time': (recordsWithTime / apiData.length * 100).toStringAsFixed(1),
        'direction': (recordsWithDirection / apiData.length * 100).toStringAsFixed(1),
      },
    };
  }
  
  // Computed values
  bool get hasError => errorMessage != null;
  int get totalFrames => apiData.length;
  List<Map<String, dynamic>> get data => rawData;
  List<Map<String, dynamic>> get timeSeriesData => processedTimeSeriesData;
  List<Map<String, dynamic>> get stationData => processedStationData;
  List<Map<String, dynamic>> get rawApiData => apiData;
  
  @override
  List<Object?> get props => [
    apiData,
    dataLoaded,
    dataSource,
    generatedStationData,
    isLoading,
    errorMessage,
    availableModels,
    availableDepths,
    availableDates,
    availableTimes,
    maxDataPoints,
    dataProcessingOptions,
    selectedDepth,
    selectedStation,
  ];
  
  DataManagementLoadedState copyWith({
    List<Map<String, dynamic>>? apiData,
    bool? dataLoaded,
    String? dataSource,
    List<Map<String, dynamic>>? generatedStationData,
    bool? isLoading,
    String? errorMessage,
    List<String>? availableModels,
    List<double>? availableDepths,
    List<String>? availableDates,
    List<String>? availableTimes,
    int? maxDataPoints,
    Map<String, bool>? dataProcessingOptions,
    double? selectedDepth,
    Map<String, dynamic>? selectedStation,
  }) {
    return DataManagementLoadedState(
      apiData: apiData ?? this.apiData,
      dataLoaded: dataLoaded ?? this.dataLoaded,
      dataSource: dataSource ?? this.dataSource,
      generatedStationData: generatedStationData ?? this.generatedStationData,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      availableModels: availableModels ?? this.availableModels,
      availableDepths: availableDepths ?? this.availableDepths,
      availableDates: availableDates ?? this.availableDates,
      availableTimes: availableTimes ?? this.availableTimes,
      maxDataPoints: maxDataPoints ?? this.maxDataPoints,
      dataProcessingOptions: dataProcessingOptions ?? this.dataProcessingOptions,
      selectedDepth: selectedDepth ?? this.selectedDepth,
      selectedStation: selectedStation ?? this.selectedStation,
    );
  }
}

// BLOC
class DataManagementBloc extends Bloc<DataManagementEvent, DataManagementState> {
  final OceanDataRemoteDataSource _dataSource;
  final AuthBloc _authBloc;
  
  DataManagementBloc({
    required OceanDataRemoteDataSource dataSource,
    required AuthBloc authBloc,
  }) : _dataSource = dataSource,
       _authBloc = authBloc,
       super(const DataManagementInitialState()) {
    
    on<RefreshDataEvent>(_onRefreshData);
    on<UpdateDataProcessingOptionsEvent>(_onUpdateDataProcessingOptions);
    on<SetMaxDataPointsLimitEvent>(_onSetMaxDataPointsLimit);
  }
  
  Future<void> _onRefreshData(RefreshDataEvent event, Emitter<DataManagementState> emit) async {
    emit(const DataManagementLoadingState());
    
    try {
      // Get token from AuthBloc
      String? token;
      if (_authBloc.state is AuthenticatedState) {
        final authState = _authBloc.state as AuthenticatedState;
        token = authState.accessToken;
      }
      
      final result = await _dataSource.loadAllData(
        area: event.selectedArea,
        startDate: event.startDate,
        endDate: event.endDate,
      );
      
      final allData = result['allData'] as List<Map<String, dynamic>>;
      
      if (allData.isNotEmpty) {
        // Extract available models
        final models = allData
            .map((row) => row['model'] as String?)
            .where((m) => m != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
        
        // Extract available depths
        final depths = allData
            .map((row) => row['depth'] as double?)
            .whereType<double>()
            .toSet()
            .toList()
          ..sort();
        
        // Extract available dates and times
        final dates = allData
            .map((row) {
              final time = row['time'] as String?;
              if (time == null) return null;
              return DateTime.parse(time).toIso8601String().split('T')[0];
            })
            .where((d) => d != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
        
        final times = allData
            .map((row) {
              final time = row['time'] as String?;
              if (time == null) return null;
              final dateTime = DateTime.parse(time);
              return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
            })
            .where((t) => t != null)
            .cast<String>()
            .toSet()
            .toList()
          ..sort();
        
        // Generate station data
        final stationData = _generateStationDataFromAPI(allData);
        
        emit(DataManagementLoadedState(
          apiData: allData,
          dataLoaded: true,
          dataSource: 'api',
          generatedStationData: stationData,
          isLoading: false,
          availableModels: models,
          availableDepths: depths,
          availableDates: dates,
          availableTimes: times,
          dataProcessingOptions: const {
            'filterByDepth': true,
            'sortByTime': true,
            'skipNullValues': true,
          },
        ));
      } else {
        emit(const DataManagementLoadedState(
          apiData: [],
          dataLoaded: true,
          dataSource: 'none',
          generatedStationData: [],
          isLoading: false,
          errorMessage: 'No data returned from the source.',
          availableModels: [],
          availableDepths: [],
          availableDates: [],
          availableTimes: [],
          dataProcessingOptions: {
            'filterByDepth': true,
            'sortByTime': true,
            'skipNullValues': true,
          },
        ));
      }
    } catch (error) {
      emit(DataManagementLoadedState(
        apiData: const [],
        dataLoaded: true,
        dataSource: 'none',
        generatedStationData: const [],
        isLoading: false,
        errorMessage: error.toString(),
        availableModels: const [],
        availableDepths: const [],
        availableDates: const [],
        availableTimes: const [],
        dataProcessingOptions: const {
          'filterByDepth': true,
          'sortByTime': true,
          'skipNullValues': true,
        },
      ));
    }
  }
  
  List<Map<String, dynamic>> _generateStationDataFromAPI(List<Map<String, dynamic>> rawData) {
    if (rawData.isEmpty) return [];
    
    final stations = <String, Map<String, dynamic>>{};
    final area = rawData.isNotEmpty ? rawData[0]['area'] : null;
    
    for (var i = 0; i < rawData.length; i++) {
      final row = rawData[i];
      final lat = row['lat'] as double?;
      final lon = row['lon'] as double?;
      
      if (lat != null && lon != null && !lat.isNaN && !lon.isNaN) {
        const precision = 4;
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
  
  void _onUpdateDataProcessingOptions(
    UpdateDataProcessingOptionsEvent event,
    Emitter<DataManagementState> emit,
  ) {
    if (state is DataManagementLoadedState) {
      final currentState = state as DataManagementLoadedState;
      final updatedOptions = Map<String, bool>.from(currentState.dataProcessingOptions);
      updatedOptions.addAll(event.options);
      emit(currentState.copyWith(dataProcessingOptions: updatedOptions));
    }
  }
  
  void _onSetMaxDataPointsLimit(
    SetMaxDataPointsLimitEvent event,
    Emitter<DataManagementState> emit,
  ) {
    if (state is DataManagementLoadedState) {
      final currentState = state as DataManagementLoadedState;
      emit(currentState.copyWith(maxDataPoints: event.limit));
    }
  }
}