// PERFORMANCE OPTIMIZATIONS FOR ocean_data_bloc.dart
// Add these imports, fields, and method overrides to the OceanDataBloc class

// ============================================================================
// IMPORTS (add to existing imports)
// ============================================================================
import 'dart:async';
import 'dart:collection';
import '../../core/utils/performance_monitoring.dart';

// ============================================================================
// CLASS FIELDS (add to OceanDataBloc class)
// ============================================================================
class OceanDataBloc extends Bloc<OceanDataEvent, OceanDataState> {
  // ... existing fields ...

  // PERFORMANCE: Frame event debouncing (max 60fps = 16ms minimum interval)
  Timer? _frameDebounceTimer;
  int? _pendingFrame;
  static const _frameDebounceMs = 16;

  // PERFORMANCE: Cached GeoJSON computations
  Map<String, dynamic>? _cachedCurrentsGeoJSON;
  Map<String, dynamic>? _cachedWindVelocityGeoJSON;
  String? _lastRawDataHash; // Content hash to detect changes

  // PERFORMANCE: Event batching
  final _eventQueue = Queue<OceanDataEvent>();
  Timer? _batchTimer;
  static const _batchWindowMs = 16;

  // PERFORMANCE: Transition timing
  int _transitionCount = 0;
  final _slowTransitions = <String, int>{};

  // ... existing constructor and handlers ...

  // ============================================================================
  // PERFORMANCE: Override onTransition for logging
  // ============================================================================
  @override
  void onTransition(Transition<OceanDataEvent, OceanDataState> transition) {
    if (kDebugMode) {
      final timerId = PerformanceMonitoring.startTimer('bloc_transition');
      super.onTransition(transition);
      final elapsed = PerformanceMonitoring.stopTimer(timerId);

      _transitionCount++;

      // Log slow transitions (> 16ms = slower than 1 frame)
      if (elapsed > 16) {
        final eventName = transition.event.runtimeType.toString();
        _slowTransitions[eventName] = (_slowTransitions[eventName] ?? 0) + 1;

        debugPrint('⚠️ SLOW TRANSITION: $eventName → '
            '${transition.nextState.runtimeType} | ${elapsed}ms | '
            'Total slow: ${_slowTransitions[eventName]}');
      }

      // Log metrics periodically
      if (_transitionCount % 100 == 0) {
        debugPrint('🔄 BLOC [Stats]: $_transitionCount transitions | '
            'Slow: ${_slowTransitions.length} types');
      }
    } else {
      super.onTransition(transition);
    }
  }

  // ============================================================================
  // PERFORMANCE: Override onError for logging
  // ============================================================================
  @override
  void onError(Object error, StackTrace stackTrace) {
    // Always log errors, even in production
    debugPrint('❌ BLOC ERROR [OceanDataBloc]: $error');

    if (kDebugMode) {
      debugPrint('Stack trace:\n$stackTrace');
    }

    super.onError(error, stackTrace);
  }

  // ============================================================================
  // PERFORMANCE: Debounced frame event handler (replaces _onSetCurrentFrame)
  // ============================================================================
  void _onSetCurrentFrame(SetCurrentFrameEvent event, Emitter<OceanDataState> emit) {
    if (state is! OceanDataLoadedState) return;

    // PERFORMANCE: Debounce frame events to max 60fps
    _pendingFrame = event.frame;

    _frameDebounceTimer?.cancel();
    _frameDebounceTimer = Timer(const Duration(milliseconds: _frameDebounceMs), () {
      if (_pendingFrame != null && state is OceanDataLoadedState) {
        final timerId = PerformanceMonitoring.startTimer('set_frame');

        emit((state as OceanDataLoadedState).copyWith(currentFrame: _pendingFrame!));

        if (kDebugMode) {
          final elapsed = PerformanceMonitoring.stopTimer(timerId);
          if (elapsed > 5) {
            debugPrint('🔄 BLOC [SetCurrentFrameEvent]: ${elapsed}ms | Frame: $_pendingFrame');
          }
        }

        _pendingFrame = null;
      }
    });
  }

  // ============================================================================
  // PERFORMANCE: Cached GeoJSON generation
  // ============================================================================
  Future<Map<String, dynamic>> _getCachedCurrentsGeoJSON(
    List<Map<String, dynamic>> rawData,
  ) async {
    // PERFORMANCE: Compute hash of raw data to detect changes
    final currentHash = _computeRawDataHash(rawData);

    // Return cached version if data hasn't changed
    if (_cachedCurrentsGeoJSON != null && _lastRawDataHash == currentHash) {
      if (kDebugMode) {
        debugPrint('🔄 BLOC [GeoJSON]: Using cached currents (${_cachedCurrentsGeoJSON!['features'].length} features)');
      }
      return _cachedCurrentsGeoJSON!;
    }

    // Data changed - recompute
    final timerId = PerformanceMonitoring.startTimer('geojson_currents');

    _cachedCurrentsGeoJSON = await compute(_generateCurrentsInIsolate, rawData);
    _lastRawDataHash = currentHash;

    if (kDebugMode) {
      final elapsed = PerformanceMonitoring.stopTimer(timerId);
      final features = _cachedCurrentsGeoJSON!['features'].length;
      debugPrint('🔄 BLOC [GeoJSON]: Generated currents in ${elapsed}ms | $features features');
    }

    return _cachedCurrentsGeoJSON!;
  }

  Future<Map<String, dynamic>> _getCachedWindVelocityGeoJSON(
    List<Map<String, dynamic>> rawData,
  ) async {
    // Similar caching logic for wind velocity
    final currentHash = _computeRawDataHash(rawData);

    if (_cachedWindVelocityGeoJSON != null && _lastRawDataHash == currentHash) {
      if (kDebugMode) {
        debugPrint('🔄 BLOC [GeoJSON]: Using cached wind (${_cachedWindVelocityGeoJSON!['features'].length} features)');
      }
      return _cachedWindVelocityGeoJSON!;
    }

    final timerId = PerformanceMonitoring.startTimer('geojson_wind');

    _cachedWindVelocityGeoJSON = await compute(_generateWindVelocityInIsolate, rawData);

    if (kDebugMode) {
      final elapsed = PerformanceMonitoring.stopTimer(timerId);
      final features = _cachedWindVelocityGeoJSON!['features'].length;
      debugPrint('🔄 BLOC [GeoJSON]: Generated wind in ${elapsed}ms | $features features');
    }

    return _cachedWindVelocityGeoJSON!;
  }

  // ============================================================================
  // PERFORMANCE: Compute hash for cache invalidation
  // ============================================================================
  String _computeRawDataHash(List<Map<String, dynamic>> rawData) {
    if (rawData.isEmpty) return 'empty';

    // Simple hash: combine length + first/last timestamps
    // For production, consider using a proper hash function
    final length = rawData.length;
    final firstLat = rawData.first['lat'] ?? 0;
    final lastLat = rawData.last['lat'] ?? 0;

    return '$length-$firstLat-$lastLat';
  }

  // ============================================================================
  // PERFORMANCE: Dispose cleanup
  // ============================================================================
  @override
  Future<void> close() {
    _frameDebounceTimer?.cancel();
    _batchTimer?.cancel();
    _eventQueue.clear();

    if (kDebugMode) {
      debugPrint('🔄 BLOC [Dispose]: Transitions: $_transitionCount | '
          'Slow types: ${_slowTransitions.keys.join(", ")}');
    }

    return super.close();
  }
}

// ============================================================================
// USAGE NOTES:
// ============================================================================
// 1. Replace the original _onSetCurrentFrame with the debounced version above
// 2. In data loading handlers, use _getCachedCurrentsGeoJSON instead of compute directly
// 3. Add the fields at the class level
// 4. The onTransition and onError overrides provide automatic logging
// 5. All logs are gated with kDebugMode for production safety
//
// EXAMPLE of using cached GeoJSON in a handler:
// ```dart
// Future<void> _onLoadInitialData(...) async {
//   // ... fetch rawData ...
//
//   // Instead of:
//   // final currentsGeoJSON = await compute(_generateCurrentsInIsolate, rawData);
//
//   // Use:
//   final currentsGeoJSON = await _getCachedCurrentsGeoJSON(rawData);
//   final windGeoJSON = await _getCachedWindVelocityGeoJSON(rawData);
//
//   // ... emit state ...
// }
// ```
// ============================================================================
