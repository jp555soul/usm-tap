import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

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
  final bool hasError;
  final String? errorMessage;
  final List<OceanDataEntity> data;
  final List<StationDataEntity> stationData;
  final List<Map<String, dynamic>> timeSeriesData;
  final List<Map<String, dynamic>> rawData;
  final Map<String, dynamic> currentsGeoJSON;
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
    this.hasError = false,
    this.errorMessage,
    required this.data,
    required this.stationData,
    required this.timeSeriesData,
    required this.rawData,
    required this.currentsGeoJSON,
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
    dataLoaded, isLoading, hasError, errorMessage, data, stationData, timeSeriesData,
    rawData, currentsGeoJSON, envData, selectedArea, selectedModel, selectedDepth,
    dataSource, timeZone, startDate, endDate, currentDate, currentTime, selectedStation,
    availableModels, availableDepths, availableDates, availableTimes, currentFrame,
    totalFrames, isPlaying, playbackSpeed, loopMode, mapLayerVisibility, isSstHeatmapVisible,
    currentsVectorScale, currentsColorBy, heatmapScale, windVelocityParticleCount,
    windVelocityParticleOpacity, windVelocityParticleSpeed, holoOceanPOV, holoOcean,
    connectionStatus, connectionDetails, dataQuality, chatMessages, isTyping,
  ];
  
  OceanDataLoadedState copyWith({
    bool? dataLoaded, bool? isLoading, bool? hasError, String? errorMessage,
    List<OceanDataEntity>? data, List<StationDataEntity>? stationData,
    List<Map<String, dynamic>>? timeSeriesData, List<Map<String, dynamic>>? rawData,
    Map<String, dynamic>? currentsGeoJSON, EnvDataEntity? envData, String? selectedArea,
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
  }) {
    return OceanDataLoadedState(
      dataLoaded: dataLoaded ?? this.dataLoaded,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
      data: data ?? this.data,
      stationData: stationData ?? this.stationData,
      timeSeriesData: timeSeriesData ?? this.timeSeriesData,
      rawData: rawData ?? this.rawData,
      currentsGeoJSON: currentsGeoJSON ?? this.currentsGeoJSON,
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

class OceanDataBloc extends Bloc<OceanDataEvent, OceanDataState> {
  final GetOceanDataUseCase _getOceanDataUseCase;
  final UpdateTimeRangeUseCase _updateTimeRangeUseCase;
  final ControlAnimationUseCase _controlAnimationUseCase;
  final ConnectHoloOceanUseCase _connectHoloOceanUseCase;
  final OceanDataRemoteDataSource _remoteDataSource;
  
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
        
        if (oceanData.isNotEmpty) {
          try {
            // Get raw data from the data source for processing
            final rawDataResult = await _remoteDataSource.loadAllData(
              startDate: startDate,
              endDate: endDate,
            );
            final rawData = rawDataResult['allData'] as List?;
            
            if (rawData != null && rawData.isNotEmpty) {
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
              timeSeriesData = _remoteDataSource.processAPIData(rawData);
              // debugPrint('Processed ${timeSeriesData.length} time series data points');
            }
          } catch (e) {
            // debugPrint('Error fetching environmental data or processing time series: $e');
            // Continue with empty data if there's an error
          }
        }
        
        final dataQuality = _calculateDataQuality(oceanData);
        emit(OceanDataLoadedState(
          dataLoaded: true, isLoading: false, hasError: false, data: oceanData,
          stationData: const [], timeSeriesData: timeSeriesData, rawData: const [],
          currentsGeoJSON: const {}, envData: envData, selectedArea: 'USM', selectedModel: 'NGOFS2',
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
          
          if (oceanData.isNotEmpty) {
            try {
              // Get raw data from the data source for processing
              final rawDataResult = await _remoteDataSource.loadAllData(
                startDate: currentState.startDate,
                endDate: currentState.endDate,
              );
              final rawData = rawDataResult['allData'] as List?;
              
              if (rawData != null && rawData.isNotEmpty) {
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
                timeSeriesData = _remoteDataSource.processAPIData(rawData);
                // debugPrint('Processed ${timeSeriesData.length} time series data points on refresh');
              }
            } catch (e) {
              // debugPrint('Error fetching environmental data or processing time series on refresh: $e');
              // Continue with empty data if there's an error
            }
          }
          
          final dataQuality = _calculateDataQuality(oceanData);
          emit(currentState.copyWith(
            data: oceanData, isLoading: false, hasError: false,
            timeSeriesData: timeSeriesData, envData: envData,
            connectionStatus: connectionStatus, dataQuality: dataQuality,
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
  
  void _onSetSelectedArea(SetSelectedAreaEvent event, Emitter<OceanDataState> emit) {
    if (state is OceanDataLoadedState) {
      emit((state as OceanDataLoadedState).copyWith(selectedArea: event.area));
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