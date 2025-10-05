// lib/presentation/blocs/map/map_bloc.dart
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../data/models/map_bounds.dart';
import '../../domain/entities/station_data_entity.dart';
import '../../domain/repositories/map_repository.dart';
import '../../domain/usecases/map/get_stations_usecase.dart';
import '../../domain/usecases/map/select_station_usecase.dart';

// Events
abstract class MapEvent extends Equatable {
  const MapEvent();

  @override
  List<Object?> get props => [];
}

class LoadStationsEvent extends MapEvent {
  const LoadStationsEvent();
}

class SelectStationEvent extends MapEvent {
  final String stationId;

  const SelectStationEvent(this.stationId);

  @override
  List<Object?> get props => [stationId];
}

class ClearStationSelectionEvent extends MapEvent {
  const ClearStationSelectionEvent();
}

class FilterStationsByBoundsEvent extends MapEvent {
  final MapBounds bounds;

  const FilterStationsByBoundsEvent(this.bounds);

  @override
  List<Object?> get props => [bounds];
}

class SearchStationsEvent extends MapEvent {
  final String query;

  const SearchStationsEvent(this.query);

  @override
  List<Object?> get props => [query];
}

class UpdateMapCenterEvent extends MapEvent {
  final double latitude;
  final double longitude;
  final double? zoom;

  const UpdateMapCenterEvent({
    required this.latitude,
    required this.longitude,
    this.zoom,
  });

  @override
  List<Object?> get props => [latitude, longitude, zoom];
}

// States
abstract class MapState extends Equatable {
  const MapState();

  @override
  List<Object?> get props => [];
}

class MapInitial extends MapState {
  const MapInitial();
}

class MapLoading extends MapState {
  const MapLoading();
}

class MapLoaded extends MapState {
  final List<StationDataEntity> stations;
  final List<StationDataEntity> visibleStations;
  final StationDataEntity? selectedStation;
  final double centerLatitude;
  final double centerLongitude;
  final double zoom;
  final MapBounds? currentBounds;

  const MapLoaded({
    required this.stations,
    required this.visibleStations,
    this.selectedStation,
    required this.centerLatitude,
    required this.centerLongitude,
    this.zoom = 6.0,
    this.currentBounds,
  });

  @override
  List<Object?> get props => [
        stations,
        visibleStations,
        selectedStation,
        centerLatitude,
        centerLongitude,
        zoom,
        currentBounds,
      ];

  MapLoaded copyWith({
    List<StationDataEntity>? stations,
    List<StationDataEntity>? visibleStations,
    StationDataEntity? selectedStation,
    bool clearSelection = false,
    double? centerLatitude,
    double? centerLongitude,
    double? zoom,
    MapBounds? currentBounds,
  }) {
    return MapLoaded(
      stations: stations ?? this.stations,
      visibleStations: visibleStations ?? this.visibleStations,
      selectedStation: clearSelection ? null : (selectedStation ?? this.selectedStation),
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      zoom: zoom ?? this.zoom,
      currentBounds: currentBounds ?? this.currentBounds,
    );
  }
}

class MapError extends MapState {
  final String message;

  const MapError(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class MapBloc extends Bloc<MapEvent, MapState> {
  final GetStationsUseCase _getStationsUseCase;
  final SelectStationUseCase _selectStationUseCase;
  final MapRepository _mapRepository;

  MapBloc({
    required GetStationsUseCase getStationsUseCase,
    required SelectStationUseCase selectStationUseCase,
    required MapRepository mapRepository,
  })  : _getStationsUseCase = getStationsUseCase,
        _selectStationUseCase = selectStationUseCase,
        _mapRepository = mapRepository,
        super(const MapInitial()) {
    on<LoadStationsEvent>(_onLoadStations);
    on<SelectStationEvent>(_onSelectStation);
    on<ClearStationSelectionEvent>(_onClearSelection);
    on<FilterStationsByBoundsEvent>(_onFilterByBounds);
    on<SearchStationsEvent>(_onSearchStations);
    on<UpdateMapCenterEvent>(_onUpdateMapCenter);
  }

  Future<void> _onLoadStations(
    LoadStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    emit(const MapLoading());

    final result = await _getStationsUseCase();

    result.fold(
      (failure) {
        emit(MapError(failure.message));
      },
      (stations) {
        // Calculate initial center based on all stations
        if (stations.isNotEmpty) {
          double avgLat = 0;
          double avgLng = 0;
          for (final station in stations) {
            avgLat += station.latitude;
            avgLng += station.longitude;
          }
          avgLat /= stations.length;
          avgLng /= stations.length;

          emit(MapLoaded(
            stations: stations,
            visibleStations: stations,
            centerLatitude: avgLat,
            centerLongitude: avgLng,
          ));
        } else {
          emit(const MapLoaded(
            stations: [],
            visibleStations: [],
            centerLatitude: 0.0,
            centerLongitude: 0.0,
          ));
        }
      },
    );
  }

  Future<void> _onSelectStation(
    SelectStationEvent event,
    Emitter<MapState> emit,
  ) async {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    final result = await _selectStationUseCase(event.stationId);

    result.fold(
      (failure) {
        emit(MapError(failure.message));
      },
      (station) {
        emit(currentState.copyWith(
          selectedStation: station,
          centerLatitude: station.latitude,
          centerLongitude: station.longitude,
          zoom: 10.0,
        ));
      },
    );
  }

  void _onClearSelection(
    ClearStationSelectionEvent event,
    Emitter<MapState> emit,
  ) {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    emit(currentState.copyWith(clearSelection: true));
  }

  Future<void> _onFilterByBounds(
    FilterStationsByBoundsEvent event,
    Emitter<MapState> emit,
  ) async {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    final result = await _mapRepository.getStationsInBounds(event.bounds);

    result.fold(
      (failure) {
        emit(MapError(failure.message));
      },
      (visibleStations) {
        emit(currentState.copyWith(
          visibleStations: visibleStations,
          currentBounds: event.bounds,
        ));
      },
    );
  }

  Future<void> _onSearchStations(
    SearchStationsEvent event,
    Emitter<MapState> emit,
  ) async {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    
    if (event.query.isEmpty) {
      emit(currentState.copyWith(visibleStations: currentState.stations));
      return;
    }

    final result = await _mapRepository.searchStations(
      query: event.query,
      activeOnly: true,
    );

    result.fold(
      (failure) {
        emit(MapError(failure.message));
      },
      (searchResults) {
        emit(currentState.copyWith(visibleStations: searchResults));
      },
    );
  }

  void _onUpdateMapCenter(
    UpdateMapCenterEvent event,
    Emitter<MapState> emit,
  ) {
    if (state is! MapLoaded) return;

    final currentState = state as MapLoaded;
    emit(currentState.copyWith(
      centerLatitude: event.latitude,
      centerLongitude: event.longitude,
      zoom: event.zoom,
    ));
  }
}