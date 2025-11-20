import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

// EVENTS
abstract class TimeManagementEvent extends Equatable {
  const TimeManagementEvent();
  
  @override
  List<Object?> get props => [];
}

class ProcessRawDataEvent extends TimeManagementEvent {
  final List<Map<String, dynamic>> data;
  const ProcessRawDataEvent(this.data);
  
  @override
  List<Object?> get props => [data];
}

class SetCurrentDateEvent extends TimeManagementEvent {
  final DateTime date;
  const SetCurrentDateEvent(this.date);
  
  @override
  List<Object?> get props => [date];
}

class SetCurrentEndDateEvent extends TimeManagementEvent {
  final DateTime date;
  const SetCurrentEndDateEvent(this.date);
  
  @override
  List<Object?> get props => [date];
}

class SetTimeZoneEvent extends TimeManagementEvent {
  final String timeZone;
  const SetTimeZoneEvent(this.timeZone);
  
  @override
  List<Object?> get props => [timeZone];
}

class SetCurrentTimeEvent extends TimeManagementEvent {
  final String timeString;
  const SetCurrentTimeEvent(this.timeString);
  
  @override
  List<Object?> get props => [timeString];
}

class HandleDateRangeChangeEvent extends TimeManagementEvent {
  final DateTime startDate;
  final DateTime endDate;
  const HandleDateRangeChangeEvent(this.startDate, this.endDate);
  
  @override
  List<Object?> get props => [startDate, endDate];
}

class UpdateTimeConfigEvent extends TimeManagementEvent {
  final Map<String, dynamic> config;
  const UpdateTimeConfigEvent(this.config);
  
  @override
  List<Object?> get props => [config];
}

// STATES
abstract class TimeManagementState extends Equatable {
  const TimeManagementState();
  
  @override
  List<Object?> get props => [];
}

class TimeManagementLoadedState extends TimeManagementState {
  final List<Map<String, dynamic>> rawData;
  final List<List<Map<String, dynamic>>> processedFrames;
  final List<String> uniqueTimestamps;
  final DateTime currentDate;
  final DateTime currentEndDate;
  final String timeZone;
  final Map<String, dynamic> timeConfig;

  const TimeManagementLoadedState({
    required this.rawData,
    this.processedFrames = const [],
    this.uniqueTimestamps = const [],
    required this.currentDate,
    required this.currentEndDate,
    required this.timeZone,
    required this.timeConfig,
  });
  
  // Time range analysis
  Map<String, dynamic>? get timeRange {
    if (rawData.isEmpty) return null;
    
    final times = rawData
        .where((row) => row['time'] != null)
        .map((row) => DateTime.parse(row['time'] as String))
        .toList()
      ..sort();
    
    if (times.isEmpty) return null;
    
    final start = times.first;
    final end = times.last;
    final duration = end.difference(start);
    
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'duration': duration.inMilliseconds,
      'durationDays': (duration.inMilliseconds / 86400000).round(),
      'durationHours': (duration.inMilliseconds / 3600000).round(),
      'totalDataPoints': times.length,
    };
  }
  
  // Find closest data point by time
  Map<String, dynamic> findClosestDataPoint(DateTime targetDateTime) {
    if (rawData.isEmpty) {
      return {
        'index': 0,
        'dataPoint': null,
        'timeDiff': 0,
      };
    }
    
    int closestIndex = 0;
    int minDifference = double.maxFinite.toInt();
    Map<String, dynamic>? closestDataPoint;
    
    for (var i = 0; i < rawData.length; i++) {
      final row = rawData[i];
      if (row['time'] != null) {
        final rowDateTime = DateTime.parse(row['time'] as String);
        final difference = (rowDateTime.difference(targetDateTime).inMilliseconds).abs();
        if (difference < minDifference) {
          minDifference = difference;
          closestIndex = i;
          closestDataPoint = row;
        }
      }
    }
    
    return {
      'index': closestIndex,
      'dataPoint': closestDataPoint,
      'timeDiff': minDifference,
    };
  }
  
  // Format DateTime
  String formatDateTime(DateTime? date, {String? timezone}) {
    if (date == null) return '';
    
    final tz = timezone ?? timeZone;
    final format24Hour = timeConfig['format24Hour'] as bool? ?? true;
    final showSeconds = timeConfig['showSeconds'] as bool? ?? false;
    
    final pattern = format24Hour
        ? (showSeconds ? 'MMM d, y HH:mm:ss' : 'MMM d, y HH:mm')
        : (showSeconds ? 'MMM d, y h:mm:ss a' : 'MMM d, y h:mm a');
    
    return DateFormat(pattern).format(date);
  }
  
  // Format time only
  String formatTimeOnly(DateTime? date, {String? timezone}) {
    if (date == null) return '';
    
    final tz = timezone ?? timeZone;
    final format24Hour = timeConfig['format24Hour'] as bool? ?? true;
    final showSeconds = timeConfig['showSeconds'] as bool? ?? false;
    
    final pattern = format24Hour
        ? (showSeconds ? 'HH:mm:ss' : 'HH:mm')
        : (showSeconds ? 'h:mm:ss a' : 'h:mm a');
    
    return DateFormat(pattern).format(date);
  }
  
  // Time statistics
  Map<String, dynamic>? get timeStatistics {
    final range = timeRange;
    if (range == null || rawData.isEmpty) return null;
    
    final gaps = <Map<String, dynamic>>[];
    final intervals = <int>[];
    
    // Create a sorted copy
    final sortedData = List<Map<String, dynamic>>.from(rawData)
      ..sort((a, b) {
        if (a['time'] == null || b['time'] == null) return 0;
        return DateTime.parse(a['time'] as String)
            .compareTo(DateTime.parse(b['time'] as String));
      });
    
    for (var i = 1; i < sortedData.length; i++) {
      final prev = sortedData[i - 1]['time'];
      final curr = sortedData[i]['time'];
      
      if (prev != null && curr != null) {
        final interval = DateTime.parse(curr as String)
            .difference(DateTime.parse(prev as String))
            .inMilliseconds;
        intervals.add(interval);
        
        final timeStep = timeConfig['timeStep'] as int? ?? 3600000;
        if (interval > timeStep * 2) {
          gaps.add({
            'start': prev,
            'end': curr,
            'duration': interval,
          });
        }
      }
    }
    
    final avgInterval = intervals.isNotEmpty
        ? intervals.reduce((a, b) => a + b) / intervals.length
        : 0.0;
    
    return {
      'averageInterval': avgInterval,
      'averageIntervalHours': (avgInterval / 3600000 * 100).round() / 100,
      'dataGaps': gaps.length,
      'largestGap': gaps.isNotEmpty
          ? gaps.map((g) => g['duration'] as int).reduce(math.max)
          : 0,
      'dataFrequency': avgInterval > 0
          ? (3600000 / avgInterval * 100).round() / 100
          : 0.0,
    };
  }
  
  // Computed values
  bool get hasTimeData => rawData.isNotEmpty;
  bool get isValidDateRange => currentDate.isBefore(currentEndDate);
  
  // Aliases for backward compatibility
  DateTime get startDate => currentDate;
  DateTime get endDate => currentEndDate;
  Map<String, dynamic>? get getTimeRange => timeRange;
  
  @override
  List<Object?> get props => [
    rawData,
    processedFrames,
    uniqueTimestamps,
    currentDate,
    currentEndDate,
    timeZone,
    timeConfig,
  ];

  TimeManagementLoadedState copyWith({
    List<Map<String, dynamic>>? rawData,
    List<List<Map<String, dynamic>>>? processedFrames,
    List<String>? uniqueTimestamps,
    DateTime? currentDate,
    DateTime? currentEndDate,
    String? timeZone,
    Map<String, dynamic>? timeConfig,
  }) {
    return TimeManagementLoadedState(
      rawData: rawData ?? this.rawData,
      processedFrames: processedFrames ?? this.processedFrames,
      uniqueTimestamps: uniqueTimestamps ?? this.uniqueTimestamps,
      currentDate: currentDate ?? this.currentDate,
      currentEndDate: currentEndDate ?? this.currentEndDate,
      timeZone: timeZone ?? this.timeZone,
      timeConfig: timeConfig ?? this.timeConfig,
    );
  }
}

// BLOC
class TimeManagementBloc extends Bloc<TimeManagementEvent, TimeManagementState> {
  // Default date range set to 08/01/2025 - 08/08/2025 as these are currently the only dates with available data.
  static final DateTime initialStartDate = DateTime.parse('2025-08-01T00:00:00Z');

  // Define a default end date (7 days after the start)
  static final DateTime initialEndDate = DateTime.parse('2025-08-08T00:00:00Z');
  
  TimeManagementBloc() : super(
    TimeManagementLoadedState(
      rawData: const [],
      currentDate: initialStartDate,
      currentEndDate: initialEndDate,
      timeZone: 'UTC',
      timeConfig: const {
        'format24Hour': true,
        'showSeconds': false,
        'autoSync': true,
        'timeStep': 3600000, // 1 hour in milliseconds
      },
    ),
  ) {
    on<ProcessRawDataEvent>(_onProcessRawData);
    on<SetCurrentDateEvent>(_onSetCurrentDate);
    on<SetCurrentEndDateEvent>(_onSetCurrentEndDate);
    on<SetTimeZoneEvent>(_onSetTimeZone);
    on<SetCurrentTimeEvent>(_onSetCurrentTime);
    on<HandleDateRangeChangeEvent>(_onHandleDateRangeChange);
    on<UpdateTimeConfigEvent>(_onUpdateTimeConfig);
  }
  
  Future<void> _onProcessRawData(ProcessRawDataEvent event, Emitter<TimeManagementState> emit) async {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;

      // Process frames in isolate using compute
      debugPrint('🔄 TIME_MANAGEMENT: Processing ${event.data.length} data points into frames');
      final processedData = await compute(_groupDataByTime, event.data);

      final newState = currentState.copyWith(
        rawData: event.data,
        processedFrames: processedData['frames'] as List<List<Map<String, dynamic>>>,
        uniqueTimestamps: processedData['timestamps'] as List<String>,
      );

      debugPrint('🔄 TIME_MANAGEMENT: Extracted ${newState.processedFrames.length} unique time steps');

      // Set default date range when data is loaded if not set
      final timeRange = newState.timeRange;
      if (timeRange != null) {
        emit(newState.copyWith(
          currentDate: DateTime.parse(timeRange['start'] as String),
          currentEndDate: DateTime.parse(timeRange['end'] as String),
        ));
      } else {
        emit(newState);
      }
    }
  }
  
  void _onSetCurrentDate(SetCurrentDateEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      emit(currentState.copyWith(currentDate: event.date));
    }
  }
  
  void _onSetCurrentEndDate(SetCurrentEndDateEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      emit(currentState.copyWith(currentEndDate: event.date));
    }
  }
  
  void _onSetTimeZone(SetTimeZoneEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      emit(currentState.copyWith(timeZone: event.timeZone));
    }
  }
  
  void _onSetCurrentTime(SetCurrentTimeEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      
      final parts = event.timeString.split(':');
      if (parts.length >= 2) {
        final hours = int.tryParse(parts[0]);
        final minutes = int.tryParse(parts[1]);
        
        if (hours != null && minutes != null) {
          final newDate = DateTime(
            currentState.currentDate.year,
            currentState.currentDate.month,
            currentState.currentDate.day,
            hours,
            minutes,
            0,
            0,
          );
          emit(currentState.copyWith(currentDate: newDate));
        }
      }
    }
  }
  
  void _onHandleDateRangeChange(HandleDateRangeChangeEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      emit(currentState.copyWith(
        currentDate: event.startDate,
        currentEndDate: event.endDate,
      ));
    }
  }
  
  void _onUpdateTimeConfig(UpdateTimeConfigEvent event, Emitter<TimeManagementState> emit) {
    if (state is TimeManagementLoadedState) {
      final currentState = state as TimeManagementLoadedState;
      final updatedConfig = Map<String, dynamic>.from(currentState.timeConfig);
      updatedConfig.addAll(event.config);
      emit(currentState.copyWith(timeConfig: updatedConfig));
    }
  }
}

/// Top-level function for Isolate processing
/// Groups rawData by unique timestamp into frame-based lists
/// This runs in a background isolate to prevent UI blocking
Map<String, dynamic> _groupDataByTime(List<Map<String, dynamic>> rawData) {
  debugPrint('🔄 ISOLATE: Processing ${rawData.length} data points into frames');

  // Map to group data points by timestamp (time field)
  final Map<String, List<Map<String, dynamic>>> frameMap = {};

  for (final dataPoint in rawData) {
    if (dataPoint == null) continue;

    // Extract timestamp - try 'time', 'timestamp', or use a default
    final timeValue = dataPoint['time']?.toString() ??
                     dataPoint['timestamp']?.toString() ??
                     'default';

    // Group by timestamp
    if (!frameMap.containsKey(timeValue)) {
      frameMap[timeValue] = [];
    }
    frameMap[timeValue]!.add(dataPoint);
  }

  // Convert map to sorted list of frames
  final sortedKeys = frameMap.keys.toList()..sort();
  final List<List<Map<String, dynamic>>> frames = [];

  for (final key in sortedKeys) {
    frames.add(frameMap[key]!);
  }

  debugPrint('🔄 ISOLATE: Extracted ${frames.length} unique frames from ${sortedKeys.length} timestamps');

  return {
    'frames': frames,
    'timestamps': sortedKeys,
  };
}