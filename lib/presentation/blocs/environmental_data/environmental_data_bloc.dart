import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// EVENTS
abstract class EnvironmentalDataEvent extends Equatable {
  const EnvironmentalDataEvent();
  
  @override
  List<Object?> get props => [];
}

class UpdateFromCurrentFrameEvent extends EnvironmentalDataEvent {
  final List<Map<String, dynamic>> rawData;
  final int currentFrame;
  final double selectedDepth;
  
  const UpdateFromCurrentFrameEvent({
    required this.rawData,
    required this.currentFrame,
    required this.selectedDepth,
  });
  
  @override
  List<Object?> get props => [rawData, currentFrame, selectedDepth];
}

class UpdateEnvDataEvent extends EnvironmentalDataEvent {
  final Map<String, dynamic> newData;
  const UpdateEnvDataEvent(this.newData);
  
  @override
  List<Object?> get props => [newData];
}

class UpdateHoloOceanPOVEvent extends EnvironmentalDataEvent {
  final Map<String, double> newPOV;
  const UpdateHoloOceanPOVEvent(this.newPOV);
  
  @override
  List<Object?> get props => [newPOV];
}

class SyncDepthEvent extends EnvironmentalDataEvent {
  final double depth;
  const SyncDepthEvent(this.depth);
  
  @override
  List<Object?> get props => [depth];
}

// STATES
abstract class EnvironmentalDataState extends Equatable {
  const EnvironmentalDataState();
  
  @override
  List<Object?> get props => [];
}

class EnvironmentalDataLoadedState extends EnvironmentalDataState {
  final Map<String, dynamic> envData;
  final Map<String, double> holoOceanPOV;
  
  const EnvironmentalDataLoadedState({
    required this.envData,
    required this.holoOceanPOV,
  });
  
  // Environmental data getters
  double? get temperature => envData['temperature'] as double?;
  double? get salinity => envData['salinity'] as double?;
  double? get pressure => envData['pressure'] as double?;
  double? get depth => envData['depth'] as double?;
  double? get soundSpeed => envData['soundSpeed'] as double?;
  double? get density => envData['density'] as double?;
  double? get currentSpeed => envData['currentSpeed'] as double?;
  double? get currentDirection => envData['currentDirection'] as double?;
  double? get windSpeed => envData['windSpeed'] as double?;
  double? get windDirection => envData['windDirection'] as double?;
  double? get seaSurfaceHeight => envData['seaSurfaceHeight'] as double?;
  
  // Computed values
  bool get hasEnvironmentalData =>
      envData.values.any((v) => v != null);
  
  double? get currentTemperature => temperature;
  double? get currentSalinity => salinity;
  double? get currentPressure => pressure;
  double? get currentDepth => depth;
  double? get waterDensity => density;
  
  Map<String, dynamic> get currentVector => _getCurrentVector();
  Map<String, dynamic> get windVector => _getWindVector();
  
  Map<String, dynamic> _getCurrentVector() {
    if (currentSpeed == null || currentDirection == null) {
      return {
        'u': null,
        'v': null,
        'magnitude': null,
        'direction': null,
      };
    }
    
    final speed = currentSpeed!;
    final direction = currentDirection!;
    final directionRad = (direction * math.pi) / 180;
    
    return {
      'u': speed * math.sin(directionRad), // East component
      'v': speed * math.cos(directionRad), // North component
      'magnitude': speed,
      'direction': direction,
    };
  }
  
  Map<String, dynamic> _getWindVector() {
    if (windSpeed == null || windDirection == null) {
      return {
        'u': null,
        'v': null,
        'magnitude': null,
        'direction': null,
      };
    }
    
    final speed = windSpeed!;
    final direction = windDirection!;
    final directionRad = (direction * math.pi) / 180;
    
    return {
      'u': speed * math.sin(directionRad), // East component
      'v': speed * math.cos(directionRad), // North component
      'magnitude': speed,
      'direction': direction,
    };
  }
  
  /// Calculate seawater density using UNESCO formula
  double? calculateSeawaterDensity(double? temp, double? salinity, double? pressure) {
    if (temp == null || salinity == null) return null;
    
    // Simplified UNESCO seawater density formula
    final T = temp;
    final S = salinity;
    final P = pressure ?? 0;
    
    // Pure water density at atmospheric pressure
    final rho0 = 999.842594 + (6.793952e-2 * T) - (9.095290e-3 * T * T) +
                 (1.001685e-4 * T * T * T) - (1.120083e-6 * T * T * T * T) +
                 (6.536336e-9 * T * T * T * T * T);
    
    // Salinity contribution
    final A = 8.24493e-1 - 4.0899e-3 * T + 7.6438e-5 * T * T - 
              8.2467e-7 * T * T * T + 5.3875e-9 * T * T * T * T;
    final B = -5.72466e-3 + 1.0227e-4 * T - 1.6546e-6 * T * T;
    final C = 4.8314e-4;
    
    final rho = rho0 + A * S + B * S * math.sqrt(S) + C * S * S;
    
    return (rho * 100).round() / 100; // Round to 2 decimal places
  }
  
  /// Get water column profile for a parameter
  List<Map<String, dynamic>> getWaterColumnProfile(
    List<Map<String, dynamic>> rawData,
    String parameter,
  ) {
    if (rawData.isEmpty) return [];
    
    // Group data by depth for the current location/time
    final depthData = <double, List<double>>{};
    
    for (final row in rawData) {
      final rowDepth = row['depth'] as double?;
      final paramValue = row[parameter] as double?;
      
      if (rowDepth != null && paramValue != null) {
        if (!depthData.containsKey(rowDepth)) {
          depthData[rowDepth] = [];
        }
        depthData[rowDepth]!.add(paramValue);
      }
    }
    
    // Average values at each depth
    final profile = depthData.entries.map((entry) {
      final depth = entry.key;
      final values = entry.value;
      final avgValue = values.reduce((a, b) => a + b) / values.length;
      
      return {
        'depth': depth,
        'value': avgValue,
        'count': values.length,
      };
    }).toList();
    
    profile.sort((a, b) => (a['depth'] as double).compareTo(b['depth'] as double));
    
    return profile;
  }
  
  /// Get environmental trends over time window
  List<Map<String, dynamic>> getEnvironmentalTrends(
    List<Map<String, dynamic>> rawData,
    int currentFrame,
    String parameter, {
    int timeWindow = 24,
  }) {
    if (rawData.isEmpty) return [];
    
    final startFrame = math.max(0, currentFrame - timeWindow);
    final endFrame = math.min(rawData.length - 1, currentFrame);
    
    final trendData = <Map<String, dynamic>>[];
    for (var i = startFrame; i <= endFrame; i++) {
      final dataPoint = rawData[i];
      final paramValue = dataPoint[parameter];
      
      if (paramValue != null) {
        trendData.add({
          'frame': i,
          'timestamp': dataPoint['time'],
          'value': paramValue,
          'depth': dataPoint['depth'],
        });
      }
    }
    
    return trendData;
  }
  
  @override
  List<Object?> get props => [envData, holoOceanPOV];
  
  EnvironmentalDataLoadedState copyWith({
    Map<String, dynamic>? envData,
    Map<String, double>? holoOceanPOV,
  }) {
    return EnvironmentalDataLoadedState(
      envData: envData ?? this.envData,
      holoOceanPOV: holoOceanPOV ?? this.holoOceanPOV,
    );
  }
}

// BLOC
class EnvironmentalDataBloc extends Bloc<EnvironmentalDataEvent, EnvironmentalDataState> {
  EnvironmentalDataBloc() : super(
    const EnvironmentalDataLoadedState(
      envData: {
        'temperature': null,
        'salinity': null,
        'pressure': null,
        'depth': 0.0,
        'soundSpeed': null,
        'density': null,
        'currentSpeed': null,
        'currentDirection': null,
        'windSpeed': null,
        'windDirection': null,
        'seaSurfaceHeight': null,
      },
      holoOceanPOV: {
        'x': 0.0,
        'y': 0.0,
        'depth': 0.0,
        'heading': 0.0,
        'pitch': 0.0,
        'roll': 0.0,
      },
    ),
  ) {
    on<UpdateFromCurrentFrameEvent>(_onUpdateFromCurrentFrame);
    on<UpdateEnvDataEvent>(_onUpdateEnvData);
    on<UpdateHoloOceanPOVEvent>(_onUpdateHoloOceanPOV);
    on<SyncDepthEvent>(_onSyncDepth);
  }
  
  void _onUpdateFromCurrentFrame(
    UpdateFromCurrentFrameEvent event,
    Emitter<EnvironmentalDataState> emit,
  ) {
    if (state is EnvironmentalDataLoadedState) {
      final currentState = state as EnvironmentalDataLoadedState;
      
      if (event.rawData.isEmpty || event.currentFrame >= event.rawData.length) {
        return;
      }
      
      final currentDataPoint = event.rawData[event.currentFrame];
      
      final temp = currentDataPoint['temp'] ?? currentDataPoint['temperature'];
      final salinity = currentDataPoint['salinity'];
      final pressure = currentDataPoint['pressure_dbars'] ?? currentDataPoint['pressure'];
      
      final updatedEnvData = {
        'temperature': temp,
        'salinity': salinity,
        'pressure': pressure,
        'depth': currentDataPoint['depth'] ?? event.selectedDepth,
        'soundSpeed': currentDataPoint['sound_speed_ms'],
        'currentSpeed': currentDataPoint['speed'],
        'currentDirection': currentDataPoint['direction'],
        'windSpeed': currentDataPoint['nspeed'],
        'windDirection': currentDataPoint['ndirection'],
        'seaSurfaceHeight': currentDataPoint['ssh'],
        'density': currentState.calculateSeawaterDensity(temp, salinity, pressure),
      };
      
      emit(currentState.copyWith(envData: updatedEnvData));
    }
  }
  
  void _onUpdateEnvData(
    UpdateEnvDataEvent event,
    Emitter<EnvironmentalDataState> emit,
  ) {
    if (state is EnvironmentalDataLoadedState) {
      final currentState = state as EnvironmentalDataLoadedState;
      final updatedEnvData = Map<String, dynamic>.from(currentState.envData);
      updatedEnvData.addAll(event.newData);
      
      emit(currentState.copyWith(envData: updatedEnvData));
    }
  }
  
  void _onUpdateHoloOceanPOV(
    UpdateHoloOceanPOVEvent event,
    Emitter<EnvironmentalDataState> emit,
  ) {
    if (state is EnvironmentalDataLoadedState) {
      final currentState = state as EnvironmentalDataLoadedState;
      final updatedPOV = Map<String, double>.from(currentState.holoOceanPOV);
      updatedPOV.addAll(event.newPOV);
      
      emit(currentState.copyWith(holoOceanPOV: updatedPOV));
    }
  }
  
  void _onSyncDepth(
    SyncDepthEvent event,
    Emitter<EnvironmentalDataState> emit,
  ) {
    if (state is EnvironmentalDataLoadedState) {
      final currentState = state as EnvironmentalDataLoadedState;
      final updatedPOV = Map<String, double>.from(currentState.holoOceanPOV);
      updatedPOV['depth'] = event.depth;
      
      emit(currentState.copyWith(holoOceanPOV: updatedPOV));
    }
  }
}