import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

// EVENTS
abstract class UIControlsEvent extends Equatable {
  const UIControlsEvent();
  
  @override
  List<Object?> get props => [];
}

class SetSelectedAreaEvent extends UIControlsEvent {
  final String area;
  const SetSelectedAreaEvent(this.area);
  
  @override
  List<Object?> get props => [area];
}

class SetSelectedModelEvent extends UIControlsEvent {
  final String model;
  const SetSelectedModelEvent(this.model);
  
  @override
  List<Object?> get props => [model];
}

class SetSelectedDepthEvent extends UIControlsEvent {
  final double depth;
  const SetSelectedDepthEvent(this.depth);
  
  @override
  List<Object?> get props => [depth];
}

class SetSelectedParameterEvent extends UIControlsEvent {
  final String parameter;
  const SetSelectedParameterEvent(this.parameter);
  
  @override
  List<Object?> get props => [parameter];
}

class SetSelectedDateEvent extends UIControlsEvent {
  final String date;
  const SetSelectedDateEvent(this.date);
  
  @override
  List<Object?> get props => [date];
}

class SetSelectedTimeEvent extends UIControlsEvent {
  final String time;
  const SetSelectedTimeEvent(this.time);
  
  @override
  List<Object?> get props => [time];
}

class SetSelectedStationEvent extends UIControlsEvent {
  final Map<String, dynamic>? station;
  const SetSelectedStationEvent(this.station);
  
  @override
  List<Object?> get props => [station];
}

class ToggleMapLayerEvent extends UIControlsEvent {
  final String layerName;
  const ToggleMapLayerEvent(this.layerName);
  
  @override
  List<Object?> get props => [layerName];
}

class ToggleSstHeatmapEvent extends UIControlsEvent {
  const ToggleSstHeatmapEvent();
}

class SetHeatmapScaleEvent extends UIControlsEvent {
  final double scale;
  const SetHeatmapScaleEvent(this.scale);
  
  @override
  List<Object?> get props => [scale];
}

class SetWindVelocityParticleCountEvent extends UIControlsEvent {
  final int count;
  const SetWindVelocityParticleCountEvent(this.count);
  
  @override
  List<Object?> get props => [count];
}

class SetWindVelocityParticleOpacityEvent extends UIControlsEvent {
  final double opacity;
  const SetWindVelocityParticleOpacityEvent(this.opacity);
  
  @override
  List<Object?> get props => [opacity];
}

class SetWindVelocityParticleSpeedEvent extends UIControlsEvent {
  final double speed;
  const SetWindVelocityParticleSpeedEvent(this.speed);
  
  @override
  List<Object?> get props => [speed];
}

class UpdateSelectionsEvent extends UIControlsEvent {
  final Map<String, dynamic> selections;
  const UpdateSelectionsEvent(this.selections);
  
  @override
  List<Object?> get props => [selections];
}

class ResetToDefaultsEvent extends UIControlsEvent {
  const ResetToDefaultsEvent();
}

class UpdateUiConfigEvent extends UIControlsEvent {
  final Map<String, dynamic> config;
  const UpdateUiConfigEvent(this.config);
  
  @override
  List<Object?> get props => [config];
}

class SelectNextDepthEvent extends UIControlsEvent {
  const SelectNextDepthEvent();
}

class SelectPreviousDepthEvent extends UIControlsEvent {
  const SelectPreviousDepthEvent();
}

class SelectNextModelEvent extends UIControlsEvent {
  const SelectNextModelEvent();
}

class UpdateAvailableOptionsEvent extends UIControlsEvent {
  final List<String>? models;
  final List<double>? depths;
  final List<String>? dates;
  final List<String>? times;
  
  const UpdateAvailableOptionsEvent({
    this.models,
    this.depths,
    this.dates,
    this.times,
  });
  
  @override
  List<Object?> get props => [models, depths, dates, times];
}

// STATES
abstract class UIControlsState extends Equatable {
  const UIControlsState();
  
  @override
  List<Object?> get props => [];
}

class UIControlsLoadedState extends UIControlsState {
  // Core selections
  final String selectedArea;
  final String selectedModel;
  final double selectedDepth;
  final String activeParameter;
  final String currentDate;
  final String currentTime;
  final Map<String, dynamic>? selectedStation;
  
  // Map layer visibility
  final Map<String, bool> mapLayerVisibility;
  
  // Heatmap scale
  final double heatmapScale;
  
  // Wind velocity particle configuration
  final int windVelocityParticleCount;
  final double windVelocityParticleOpacity;
  final double windVelocityParticleSpeed;
  
  // UI configuration
  final Map<String, bool> uiConfig;
  
  // Available options
  final List<String> availableModels;
  final List<double> availableDepths;
  final List<String> availableDates;
  final List<String> availableTimes;
  
  const UIControlsLoadedState({
    required this.selectedArea,
    required this.selectedModel,
    required this.selectedDepth,
    required this.activeParameter,
    required this.currentDate,
    required this.currentTime,
    this.selectedStation,
    required this.mapLayerVisibility,
    required this.heatmapScale,
    required this.windVelocityParticleCount,
    required this.windVelocityParticleOpacity,
    required this.windVelocityParticleSpeed,
    required this.uiConfig,
    required this.availableModels,
    required this.availableDepths,
    required this.availableDates,
    required this.availableTimes,
  });
  
  // Computed properties
  bool get isSstHeatmapVisible => mapLayerVisibility['temperature'] ?? false;
  
  List<Map<String, String>> get availableAreas => const [
    {'value': 'MBL', 'label': 'MBL', 'region': 'Gulf Coast'},
    {'value': 'MSR', 'label': 'MSR', 'region': 'Gulf Coast'},
    {'value': 'USM', 'label': 'USM', 'region': 'Gulf Coast'},
  ];
  
  List<String> get defaultOceanModels => const ['NGOFS2'];
  
  Map<String, dynamic> get selectionValidation {
    final errors = <String>[];
    final warnings = <String>[];
    final modelsToCheck = availableModels.isNotEmpty ? availableModels : defaultOceanModels;
    
    if (!availableAreas.any((a) => a['value'] == selectedArea)) {
      warnings.add('Selected area "$selectedArea" may not be available');
    }
    
    if (modelsToCheck.isNotEmpty && !modelsToCheck.contains(selectedModel)) {
      errors.add('Selected model "$selectedModel" is not available');
    }
    
    if (availableDepths.isNotEmpty && !availableDepths.contains(selectedDepth)) {
      errors.add('Selected depth "${selectedDepth}ft" is not available');
    }
    
    if (availableDates.isNotEmpty && currentDate.isNotEmpty && !availableDates.contains(currentDate)) {
      errors.add('Selected date "$currentDate" is not available');
    }
    
    if (availableTimes.isNotEmpty && currentTime.isNotEmpty && !availableTimes.contains(currentTime)) {
      errors.add('Selected time "$currentTime" is not available');
    }
    
    return {
      'isValid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
    };
  }
  
  Map<String, dynamic> get currentSelections {
    final areaInfo = availableAreas.firstWhere(
      (a) => a['value'] == selectedArea,
      orElse: () => {'value': selectedArea, 'label': selectedArea, 'region': 'Unknown'},
    );
    final modelsToCheck = availableModels.isNotEmpty ? availableModels : defaultOceanModels;
    
    return {
      'area': {
        'value': selectedArea,
        'label': areaInfo['label'],
        'region': areaInfo['region'],
      },
      'model': {
        'value': selectedModel,
        'available': modelsToCheck.contains(selectedModel),
      },
      'depth': {
        'value': selectedDepth,
        'available': availableDepths.contains(selectedDepth),
        'unit': 'ft',
      },
      'parameter': {
        'value': activeParameter,
        'label': activeParameter,
        'category': 'Unknown',
      },
      'date': {
        'value': currentDate,
        'available': currentDate.isEmpty || availableDates.contains(currentDate),
      },
      'time': {
        'value': currentTime,
        'available': currentTime.isEmpty || availableTimes.contains(currentTime),
      },
      'station': selectedStation,
    };
  }
  
  Map<String, dynamic> get exportConfiguration {
    final modelsToExport = availableModels.isNotEmpty ? availableModels : defaultOceanModels;
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'selections': {
        'area': selectedArea,
        'model': selectedModel,
        'depth': selectedDepth,
        'activeParameter': activeParameter,
        'date': currentDate,
        'time': currentTime,
        'station': selectedStation?['name'],
      },
      'validation': selectionValidation,
      'availableOptions': {
        'models': modelsToExport,
        'depths': availableDepths,
        'areas': availableAreas.map((a) => a['value']).toList(),
        'dates': availableDates,
        'times': availableTimes,
      },
    };
  }
  
  bool get hasValidSelections => selectionValidation['isValid'] as bool;
  
  Map<String, dynamic> get selectedAreaInfo {
    final selections = currentSelections;
    return selections['area'] as Map<String, dynamic>;
  }
  
  Map<String, dynamic> get selectedParameterInfo {
    final selections = currentSelections;
    return selections['parameter'] as Map<String, dynamic>;
  }
  
  bool get isStationSelected => selectedStation != null;
  
  @override
  List<Object?> get props => [
    selectedArea,
    selectedModel,
    selectedDepth,
    activeParameter,
    currentDate,
    currentTime,
    selectedStation,
    mapLayerVisibility,
    heatmapScale,
    windVelocityParticleCount,
    windVelocityParticleOpacity,
    windVelocityParticleSpeed,
    uiConfig,
    availableModels,
    availableDepths,
    availableDates,
    availableTimes,
  ];
  
  UIControlsLoadedState copyWith({
    String? selectedArea,
    String? selectedModel,
    double? selectedDepth,
    String? activeParameter,
    String? currentDate,
    String? currentTime,
    Map<String, dynamic>? selectedStation,
    Map<String, bool>? mapLayerVisibility,
    double? heatmapScale,
    int? windVelocityParticleCount,
    double? windVelocityParticleOpacity,
    double? windVelocityParticleSpeed,
    Map<String, bool>? uiConfig,
    List<String>? availableModels,
    List<double>? availableDepths,
    List<String>? availableDates,
    List<String>? availableTimes,
  }) {
    return UIControlsLoadedState(
      selectedArea: selectedArea ?? this.selectedArea,
      selectedModel: selectedModel ?? this.selectedModel,
      selectedDepth: selectedDepth ?? this.selectedDepth,
      activeParameter: activeParameter ?? this.activeParameter,
      currentDate: currentDate ?? this.currentDate,
      currentTime: currentTime ?? this.currentTime,
      selectedStation: selectedStation ?? this.selectedStation,
      mapLayerVisibility: mapLayerVisibility ?? this.mapLayerVisibility,
      heatmapScale: heatmapScale ?? this.heatmapScale,
      windVelocityParticleCount: windVelocityParticleCount ?? this.windVelocityParticleCount,
      windVelocityParticleOpacity: windVelocityParticleOpacity ?? this.windVelocityParticleOpacity,
      windVelocityParticleSpeed: windVelocityParticleSpeed ?? this.windVelocityParticleSpeed,
      uiConfig: uiConfig ?? this.uiConfig,
      availableModels: availableModels ?? this.availableModels,
      availableDepths: availableDepths ?? this.availableDepths,
      availableDates: availableDates ?? this.availableDates,
      availableTimes: availableTimes ?? this.availableTimes,
    );
  }
}

// BLOC
class UIControlsBloc extends Bloc<UIControlsEvent, UIControlsState> {
  UIControlsBloc() : super(
    const UIControlsLoadedState(
      selectedArea: 'USM',
      selectedModel: 'NGOFS2',
      selectedDepth: 0,
      activeParameter: 'oceanCurrents',
      currentDate: '',
      currentTime: '',
      selectedStation: null,
      mapLayerVisibility: {
        'oceanCurrents': true,
        'temperature': false,
        'stations': true,
        'currentSpeed': false,
        'currentDirection': false,
        'ssh': false,
        'waveDirection': false,
        'salinity': false,
        'pressure': false,
        'windSpeed': false,
        'windDirection': false,
        'windVelocity': false,
      },
      heatmapScale: 1.0,
      windVelocityParticleCount: 2000,
      windVelocityParticleOpacity: 0.9,
      windVelocityParticleSpeed: 1.2,
      uiConfig: {
        'autoSelectDefaults': true,
        'validateSelections': true,
        'persistSelections': false,
      },
      availableModels: [],
      availableDepths: [],
      availableDates: [],
      availableTimes: [],
    ),
  ) {
    on<SetSelectedAreaEvent>(_onSetSelectedArea);
    on<SetSelectedModelEvent>(_onSetSelectedModel);
    on<SetSelectedDepthEvent>(_onSetSelectedDepth);
    on<SetSelectedParameterEvent>(_onSetSelectedParameter);
    on<SetSelectedDateEvent>(_onSetSelectedDate);
    on<SetSelectedTimeEvent>(_onSetSelectedTime);
    on<SetSelectedStationEvent>(_onSetSelectedStation);
    on<ToggleMapLayerEvent>(_onToggleMapLayer);
    on<ToggleSstHeatmapEvent>(_onToggleSstHeatmap);
    on<SetHeatmapScaleEvent>(_onSetHeatmapScale);
    on<SetWindVelocityParticleCountEvent>(_onSetWindVelocityParticleCount);
    on<SetWindVelocityParticleOpacityEvent>(_onSetWindVelocityParticleOpacity);
    on<SetWindVelocityParticleSpeedEvent>(_onSetWindVelocityParticleSpeed);
    on<UpdateSelectionsEvent>(_onUpdateSelections);
    on<ResetToDefaultsEvent>(_onResetToDefaults);
    on<UpdateUiConfigEvent>(_onUpdateUiConfig);
    on<SelectNextDepthEvent>(_onSelectNextDepth);
    on<SelectPreviousDepthEvent>(_onSelectPreviousDepth);
    on<SelectNextModelEvent>(_onSelectNextModel);
    on<UpdateAvailableOptionsEvent>(_onUpdateAvailableOptions);
  }
  
  void _onSetSelectedArea(SetSelectedAreaEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final validArea = currentState.availableAreas.any((a) => a['value'] == event.area);
      if (validArea || !(currentState.uiConfig['validateSelections'] ?? true)) {
        emit(currentState.copyWith(selectedArea: event.area));
      }
    }
  }
  
  void _onSetSelectedModel(SetSelectedModelEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final modelsToCheck = currentState.availableModels.isNotEmpty
          ? currentState.availableModels
          : currentState.defaultOceanModels;
      if (modelsToCheck.contains(event.model) || !(currentState.uiConfig['validateSelections'] ?? true)) {
        emit(currentState.copyWith(selectedModel: event.model));
      }
    }
  }
  
  void _onSetSelectedDepth(SetSelectedDepthEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      if (currentState.availableDepths.contains(event.depth) || 
          !(currentState.uiConfig['validateSelections'] ?? true)) {
        emit(currentState.copyWith(selectedDepth: event.depth));
      }
    }
  }
  
  void _onSetSelectedParameter(SetSelectedParameterEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(activeParameter: event.parameter));
    }
  }
  
  void _onSetSelectedDate(SetSelectedDateEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      if (event.date.isEmpty || currentState.availableDates.contains(event.date) ||
          !(currentState.uiConfig['validateSelections'] ?? true)) {
        emit(currentState.copyWith(currentDate: event.date));
      }
    }
  }
  
  void _onSetSelectedTime(SetSelectedTimeEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      if (event.time.isEmpty || currentState.availableTimes.contains(event.time) ||
          !(currentState.uiConfig['validateSelections'] ?? true)) {
        emit(currentState.copyWith(currentTime: event.time));
      }
    }
  }
  
  void _onSetSelectedStation(SetSelectedStationEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(selectedStation: event.station));
    }
  }
  
  void _onToggleMapLayer(ToggleMapLayerEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final updatedVisibility = Map<String, bool>.from(currentState.mapLayerVisibility);
      final isTurningOn = !(updatedVisibility[event.layerName] ?? false);
      updatedVisibility[event.layerName] = !updatedVisibility[event.layerName]!;
      
      emit(currentState.copyWith(
        mapLayerVisibility: updatedVisibility,
        activeParameter: isTurningOn ? event.layerName : currentState.activeParameter,
      ));
    }
  }
  
  void _onToggleSstHeatmap(ToggleSstHeatmapEvent event, Emitter<UIControlsState> emit) {
    // No-op: heatmap is now automatically controlled by temperature layer
  }
  
  void _onSetHeatmapScale(SetHeatmapScaleEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(heatmapScale: event.scale));
    }
  }
  
  void _onSetWindVelocityParticleCount(SetWindVelocityParticleCountEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(windVelocityParticleCount: event.count));
    }
  }
  
  void _onSetWindVelocityParticleOpacity(SetWindVelocityParticleOpacityEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(windVelocityParticleOpacity: event.opacity));
    }
  }
  
  void _onSetWindVelocityParticleSpeed(SetWindVelocityParticleSpeedEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(windVelocityParticleSpeed: event.speed));
    }
  }
  
  void _onUpdateSelections(UpdateSelectionsEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final selections = event.selections;
      
      emit(currentState.copyWith(
        selectedArea: selections['area'] as String?,
        selectedModel: selections['model'] as String?,
        selectedDepth: selections['depth'] as double?,
        activeParameter: selections['parameter'] as String?,
        currentDate: selections['date'] as String?,
        currentTime: selections['time'] as String?,
        selectedStation: selections['station'] as Map<String, dynamic>?,
      ));
    }
  }
  
  void _onResetToDefaults(ResetToDefaultsEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final modelsToUse = currentState.availableModels.isNotEmpty
          ? currentState.availableModels
          : currentState.defaultOceanModels;
      
      emit(currentState.copyWith(
        selectedArea: 'USM',
        selectedModel: modelsToUse.isNotEmpty ? modelsToUse[0] : 'NGOFS2',
        selectedDepth: currentState.availableDepths.isNotEmpty ? currentState.availableDepths[0] : 0,
        activeParameter: 'oceanCurrents',
        currentDate: currentState.availableDates.isNotEmpty ? currentState.availableDates[0] : '',
        currentTime: currentState.availableTimes.isNotEmpty ? currentState.availableTimes[0] : '',
        selectedStation: null,
      ));
    }
  }
  
  void _onUpdateUiConfig(UpdateUiConfigEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final updatedConfig = Map<String, bool>.from(currentState.uiConfig);
      event.config.forEach((key, value) {
        if (value is bool) {
          updatedConfig[key] = value;
        }
      });
      emit(currentState.copyWith(uiConfig: updatedConfig));
    }
  }
  
  void _onSelectNextDepth(SelectNextDepthEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      if (currentState.availableDepths.isEmpty) return;
      
      final currentIndex = currentState.availableDepths.indexOf(currentState.selectedDepth);
      final nextIndex = (currentIndex + 1) % currentState.availableDepths.length;
      emit(currentState.copyWith(selectedDepth: currentState.availableDepths[nextIndex]));
    }
  }
  
  void _onSelectPreviousDepth(SelectPreviousDepthEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      if (currentState.availableDepths.isEmpty) return;
      
      final currentIndex = currentState.availableDepths.indexOf(currentState.selectedDepth);
      final prevIndex = currentIndex <= 0 ? currentState.availableDepths.length - 1 : currentIndex - 1;
      emit(currentState.copyWith(selectedDepth: currentState.availableDepths[prevIndex]));
    }
  }
  
  void _onSelectNextModel(SelectNextModelEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      final modelsToUse = currentState.availableModels.isNotEmpty
          ? currentState.availableModels
          : currentState.defaultOceanModels;
      if (modelsToUse.isEmpty) return;
      
      final currentIndex = modelsToUse.indexOf(currentState.selectedModel);
      final nextIndex = (currentIndex + 1) % modelsToUse.length;
      emit(currentState.copyWith(selectedModel: modelsToUse[nextIndex]));
    }
  }
  
  void _onUpdateAvailableOptions(UpdateAvailableOptionsEvent event, Emitter<UIControlsState> emit) {
    if (state is UIControlsLoadedState) {
      final currentState = state as UIControlsLoadedState;
      emit(currentState.copyWith(
        availableModels: event.models,
        availableDepths: event.depths,
        availableDates: event.dates,
        availableTimes: event.times,
      ));
    }
  }
}