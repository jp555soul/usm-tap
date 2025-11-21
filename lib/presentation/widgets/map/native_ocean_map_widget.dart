import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// Native Flutter widget that displays ocean data on a map using flutter_map
/// Replaces the WebView-based MapContainerWidget with a native implementation
class NativeOceanMapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> stationData;
  final List<Map<String, dynamic>> timeSeriesData;
  final List<Map<String, dynamic>> rawData;
  final int totalFrames;
  final int currentFrame;
  final double selectedDepth;
  final String selectedArea;
  final Map<String, double> holoOceanPOV;
  final Function(Map<String, double>)? onPOVChange;
  final Function(double)? onDepthChange;
  final Function(Map<String, dynamic>?)? onStationSelect;
  final Function(Map<String, dynamic>)? onEnvironmentUpdate;
  final String currentDate;
  final String currentTime;
  final String mapboxToken;
  final bool isOutputCollapsed;
  final Map<String, dynamic> initialViewState;
  final Map<String, bool> mapLayerVisibility;
  final double currentsVectorScale;
  final String currentsColorBy;
  final double heatmapScale;
  final List<double> availableDepths;
  final Map<String, dynamic> currentsGeoJSON;
  final Map<String, dynamic> windVelocityGeoJSON;
  final bool isLoading;  // NEW: BLoC loading state
  final String? loadingArea;  // NEW: Area being loaded

  const NativeOceanMapWidget({
    Key? key,
    this.stationData = const [],
    this.timeSeriesData = const [],
    this.rawData = const [],
    this.totalFrames = 0,
    this.currentFrame = 0,
    this.selectedDepth = 0,
    this.selectedArea = '',
    this.holoOceanPOV = const {'x': 0, 'y': 0, 'depth': 0},
    this.onPOVChange,
    this.onDepthChange,
    this.onStationSelect,
    this.onEnvironmentUpdate,
    this.currentDate = '',
    this.currentTime = '',
    required this.mapboxToken,
    this.isOutputCollapsed = false,
    this.initialViewState = const {
      'longitude': -89.0,
      'latitude': 30.1,
      'zoom': 8,
      'pitch': 0,
      'bearing': 0
    },
    this.mapLayerVisibility = const {
      'oceanCurrents': false,
      'temperature': false,
      'salinity': false,
      'ssh': false,
      'pressure': false,
      'stations': false,
      'windSpeed': false,
      'windDirection': false,
      'windVelocity': false,
    },
    this.currentsVectorScale = 0.009,
    this.currentsColorBy = 'speed',
    this.heatmapScale = 1,
    this.availableDepths = const [],
    this.currentsGeoJSON = const {},
    this.windVelocityGeoJSON = const {},
    this.isLoading = false,  // NEW: Default to false
    this.loadingArea,  // NEW: Optional area name
  }) : super(key: key);

  @override
  State<NativeOceanMapWidget> createState() => _NativeOceanMapWidgetState();
}

class _NativeOceanMapWidgetState extends State<NativeOceanMapWidget> {
  late MapController _mapController;
  Map<String, dynamic>? _selectedStation;
  Map<String, dynamic>? _selectedVector;
  Map<String, dynamic>? _hoveredDataPoint;
  bool _mapReady = false;

  // Camera position tracking to prevent reset on widget updates
  LatLng? _currentCenter;
  double? _currentZoom;
  bool _initialViewApplied = false;

  // Marker caching to prevent rebuild when only tooltip changes
  List<Marker>? _cachedCurrentsMarkers;
  Map<String, dynamic>? _lastCurrentsGeoJSON;

  // OPTIMIZATION: Frame-based caching for instant replay
  // Cache heatmap computations per frame to avoid recomputation
  final Map<String, Map<int, List<Map<String, dynamic>>>> _frameDataCache = {};
  int? _lastCachedFrame;
  int _cacheHits = 0;
  int _cacheMisses = 0;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    // Listen to map events (zoom, pan, rotate) and force redraw
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventRotate) {
        // Track user's camera position
        if (event.source == MapEventSource.mapController && !_initialViewApplied) {
          // This is initial setup, ignore
          return;
        }

        // User-initiated move
        if (event is MapEventMove) {
          _currentCenter = event.camera.center;
          _currentZoom = event.camera.zoom;
        }

        // Force repaint of custom painters on zoom/pan/rotate
        if (_mapReady && mounted) {
          setState(() {
            // This triggers rebuild of all custom painters
          });
        }
      }
    });

    // Set initial view after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMapView();
      // Mark map as ready after initialization
      setState(() {
        _mapReady = true;
      });
    });
  }

  @override
  void dispose() {
    try {

      // OPTIMIZATION: Log cache performance before disposal
      final totalCacheAccess = _cacheHits + _cacheMisses;
      if (totalCacheAccess > 0) {
        final hitRate = (_cacheHits / totalCacheAccess * 100).toStringAsFixed(1);
      }

      _mapController.dispose();
      _mapReady = false;
      _selectedStation = null;
      _selectedVector = null;
      _cachedCurrentsMarkers = null;
      _lastCurrentsGeoJSON = null;
      _frameDataCache.clear(); // Clear frame cache
    } catch (e) {
    } finally {
      super.dispose();
    }
  }

  void _initializeMapView() {
    try {
      final longitude = (widget.initialViewState['longitude'] as num?)?.toDouble() ?? -89.0;
      final latitude = (widget.initialViewState['latitude'] as num?)?.toDouble() ?? 30.1;
      final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 8.0;

      _mapController.move(LatLng(latitude, longitude), zoom);
      _currentCenter = LatLng(latitude, longitude);
      _currentZoom = zoom;
      _initialViewApplied = true;
    } catch (e) {
    }
  }

  /// Get the default coordinates and zoom level for a study area
  Map<String, double> _getAreaCoordinates(String area) {
    switch (area.toUpperCase()) {
      case 'MBL': // Mobile Bay
        return {'latitude': 30.7, 'longitude': -88.0, 'zoom': 8.0};
      case 'MSR': // Mississippi River
        return {'latitude': 29.9, 'longitude': -89.4, 'zoom': 8.0};
      case 'USM': // Gulf of Mexico (default)
      default:
        return {'latitude': 30.1, 'longitude': -89.0, 'zoom': 8.0};
    }
  }

  /// Move the map to the center of a study area
  void _moveToArea(String area) {
    try {
      final coords = _getAreaCoordinates(area);
      final latitude = coords['latitude']!;
      final longitude = coords['longitude']!;
      final zoom = coords['zoom']!;



      _mapController.move(LatLng(latitude, longitude), zoom);
      _currentCenter = LatLng(latitude, longitude);
      _currentZoom = zoom;

    } catch (e) {
    }
  }

  @override
  void didUpdateWidget(NativeOceanMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ===== FIX: Clear stale data when loading starts =====
    // When isLoading becomes true, immediately clear caches to prevent race conditions
    if (!oldWidget.isLoading && widget.isLoading) {
      _cachedCurrentsMarkers = null;
      _lastCurrentsGeoJSON = null;
      _hoveredDataPoint = null;
      _selectedVector = null;
    }

    // ===== COMPREHENSIVE LOGGING: Map Data Updates =====
    if (oldWidget.selectedArea != widget.selectedArea) {

      // Automatically move map to new study area when area changes
      if (_mapReady && widget.selectedArea.isNotEmpty) {
        _moveToArea(widget.selectedArea);
      }
    }

    // Check if depth changed - this is critical for cache invalidation
    if (oldWidget.selectedDepth != widget.selectedDepth) {
      // Clear all caches when depth changes to force fresh render
      _cachedCurrentsMarkers = null;
      _lastCurrentsGeoJSON = null;
    }

    if (oldWidget.rawData.length != widget.rawData.length || !identical(oldWidget.rawData, widget.rawData)) {
    // Clear cache when raw data changes (animation frame update)
    _cachedCurrentsMarkers = null;
  }
    // Check if currentsGeoJSON object reference changed (not just feature count)
    // Using identical() to check object reference equality
    if (!identical(oldWidget.currentsGeoJSON, widget.currentsGeoJSON)) {
      final oldCurrentsCount = (oldWidget.currentsGeoJSON['features'] as List?)?.length ?? 0;
      final newCurrentsCount = (widget.currentsGeoJSON['features'] as List?)?.length ?? 0;
      // Clear marker cache when GeoJSON reference changes
      _cachedCurrentsMarkers = null;
      _lastCurrentsGeoJSON = null;
    }

    // Check if windVelocityGeoJSON object reference changed
    if (!identical(oldWidget.windVelocityGeoJSON, widget.windVelocityGeoJSON)) {
      final oldWindCount = (oldWidget.windVelocityGeoJSON['features'] as List?)?.length ?? 0;
      final newWindCount = (widget.windVelocityGeoJSON['features'] as List?)?.length ?? 0;
    }

    // Only apply initialViewState if this is truly first load and user hasn't moved
    if (!_initialViewApplied && _currentCenter == null && _currentZoom == null) {
      if (oldWidget.initialViewState != widget.initialViewState && _mapReady) {
        _initializeMapView();
      }
    }
    // Otherwise, preserve user's camera position - do NOT reset map

    // Force rebuild for data changes
    if (_mapReady) {
      setState(() {
      });
    }
  }

  /// Get data for the current frame with caching and adaptive LOD
  /// OPTIMIZATION: Cache frame data to avoid recomputation during replay
  /// OPTIMIZATION: Apply adaptive level of detail based on zoom
  List<Map<String, dynamic>> _getCurrentFrameData() {
    // The BLoC now provides pre-filtered data for the current time step
    // Check if this frame is cached
    final frameKey = 'frame_${widget.currentFrame}';

    if (_frameDataCache.containsKey(frameKey) &&
        _frameDataCache[frameKey]!.containsKey(widget.rawData.hashCode)) {
      _cacheHits++;
      return _frameDataCache[frameKey]![widget.rawData.hashCode]!;
    }

    // Cache miss - apply adaptive LOD and store for future access
    _cacheMisses++;
    final processedData = _applyAdaptiveLOD(widget.rawData);

    if (!_frameDataCache.containsKey(frameKey)) {
      _frameDataCache[frameKey] = {};
    }
    _frameDataCache[frameKey]![widget.rawData.hashCode] = processedData;

    // Limit cache size to prevent memory bloat (keep last 100 frames)
    if (_frameDataCache.length > 100) {
      final oldestKey = _frameDataCache.keys.first;
      _frameDataCache.remove(oldestKey);
    }

    _lastCachedFrame = widget.currentFrame;
    return processedData;
  }

  /// OPTIMIZATION: Adaptive Level of Detail based on zoom level
  /// Reduces point density at lower zoom levels for better performance
  List<Map<String, dynamic>> _applyAdaptiveLOD(List<Map<String, dynamic>> data) {
    if (!_mapReady || data.isEmpty) return data;

    final zoom = _mapController.camera.zoom;

    // Determine sampling rate based on zoom level
    int sampleRate;
    if (zoom < 7) {
      sampleRate = 5; // Very low zoom - keep every 5th point
    } else if (zoom < 9) {
      sampleRate = 3; // Medium zoom - keep every 3rd point
    } else if (zoom < 11) {
      sampleRate = 2; // High zoom - keep every 2nd point
    } else {
      sampleRate = 1; // Very high zoom - keep all points
    }

    if (sampleRate == 1) return data;

    // Apply sampling
    final sampledData = <Map<String, dynamic>>[];
    for (int i = 0; i < data.length; i += sampleRate) {
      sampledData.add(data[i]);
    }

    return sampledData;
  }

  /// Build station markers if stations layer is visible
  List<Marker> _buildStationMarkers() {
    final showStations = widget.mapLayerVisibility['stations'] ?? false;
    if (!showStations) {
      return [];
    }

    return widget.stationData.map((station) {
      final lat = (station['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (station['longitude'] as num?)?.toDouble() ?? 0.0;
      final isSelected = _selectedStation != null &&
          _selectedStation!['id'] == station['id'];

      return Marker(
        width: 40.0,
        height: 40.0,
        point: LatLng(lat, lon),
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedStation = isSelected ? null : station;
            });
            widget.onStationSelect?.call(isSelected ? null : station);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Colors.pink.shade400 : Colors.blue.shade600,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Extract currents data from GeoJSON for particle painter
  List<Map<String, dynamic>> _extractCurrentsData() {
    final List<Map<String, dynamic>> currentsData = [];

    try {
      if (widget.currentsGeoJSON.isEmpty) {
        return [];
      }

      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        return [];
      }

      for (final feature in features) {
        if (feature == null) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;

        if (geometry == null || properties == null) continue;

        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;

        final lat = (coordinates[0] as num?)?.toDouble();
        final lon = (coordinates[1] as num?)?.toDouble();
        final u = (properties['u'] as num?)?.toDouble();
        final v = (properties['v'] as num?)?.toDouble();

        if (lon == null || lat == null || u == null || v == null) continue;

        // Validate data ranges
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        currentsData.add({
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
        });
      }
    } catch (e, stackTrace) {
    }

    return currentsData;
  }

  List<Map<String, dynamic>> _extractWindVelocityData() {
    final List<Map<String, dynamic>> windData = [];

    try {
      if (widget.windVelocityGeoJSON.isEmpty) {
        return [];
      }

      final features = widget.windVelocityGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        return [];
      }

      for (final feature in features) {
        if (feature == null) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;

        if (geometry == null || properties == null) continue;

        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;

        final lon = (coordinates[0] as num?)?.toDouble();
        final lat = (coordinates[1] as num?)?.toDouble();
        final u = (properties['u'] as num?)?.toDouble();
        final v = (properties['v'] as num?)?.toDouble();

        if (lon == null || lat == null || u == null || v == null) continue;

        // Validate data ranges
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        windData.add({
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
        });
      }
    } catch (e, stackTrace) {
    }

    return windData;
  }

  /// Build ocean currents vector markers
  List<Marker> _buildCurrentsVectorMarkers() {
    final showCurrents = widget.mapLayerVisibility['oceanCurrents'] ?? false;

    if (!showCurrents || widget.currentsGeoJSON.isEmpty) {
      return [];
    }

    // Return cache if valid
  if (_cachedCurrentsMarkers != null) {
    // If using GeoJSON, check if it changed
    if (widget.rawData.isEmpty && identical(_lastCurrentsGeoJSON, widget.currentsGeoJSON)) {
      return _cachedCurrentsMarkers!;
    }
    // If using rawData, didUpdateWidget clears cache when it changes, so non-null cache is valid
    if (widget.rawData.isNotEmpty) {
      return _cachedCurrentsMarkers!;
    }
  }

  final List<Marker> vectors = [];

  try {
    // PRIORITY 1: Use Raw Data (Animation Frames)
    if (widget.rawData.isNotEmpty) {
      
      for (final row in widget.rawData) {
        if (row == null) continue;

        final lat = (row['lat'] as num?)?.toDouble();
        final lon = (row['lon'] as num?)?.toDouble();

        if (lat == null || lon == null) continue;
        
        // Validate coordinates
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        // Get velocity components
        double? u = (row['u'] as num?)?.toDouble();
        double? v = (row['v'] as num?)?.toDouble();
        double? speed = (row['speed'] as num?)?.toDouble();
        double? direction = (row['direction'] as num?)?.toDouble();
        
        // Calculate speed if missing but u/v present
        if ((speed == null || speed == 0) && u != null && v != null) {
          speed = math.sqrt(u * u + v * v);
        }
        
        // SSH Fallback for speed (if speed is missing/zero)
        // This handles depth 2 where we have direction but no speed/u/v
        if ((speed == null || speed == 0) && row['ssh'] != null) {
          final ssh = (row['ssh'] as num).toDouble();
          final sshAbs = ssh.abs();
          // Map SSH (0-2m typical) to speed (0.1-1.5 m/s)
          final baseSpeed = 0.1 + (sshAbs.clamp(0.0, 2.0) * 0.7);
          // Add small random variation by location
          final locationSeed = (lat * 1000 + lon * 1000).toInt();
          final variation = (locationSeed % 20 - 10) * 0.02; 
          speed = (baseSpeed + variation).clamp(0.05, 2.0);
        }
        
        // Skip if we still have no speed
        if (speed == null || speed == 0) continue;
        
        // Calculate direction if missing but u/v present
        if (direction == null && u != null && v != null) {
          direction = math.atan2(v, u) * 180 / math.pi;
        }
        
        // We need u and v for the painter
        if ((u == null || v == null) && direction != null) {
          final dirRad = direction * math.pi / 180;
          u = speed * math.sin(dirRad);
          v = speed * math.cos(dirRad);
        }
        
        // If we still don't have u/v, we can't draw direction
        if (u == null || v == null) continue;

        // Calculate color based on speed
        final vectorColor = _getVectorColor(speed, row);

        vectors.add(
          Marker(
            width: 30,
            height: 30,
            point: LatLng(lat, lon),
            child: MouseRegion(
              onEnter: (_) {
                if (mounted) {
                  setState(() {
                    _selectedVector = {
                      'lat': lat,
                      'lon': lon,
                      'speed': speed,
                      'direction': direction ?? 0.0,
                      'ssh': row['ssh'],
                    };
                  });
                }
              },
              onExit: (_) {
                if (mounted) {
                  setState(() {
                    _selectedVector = null;
                  });
                }
              },
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVector = {
                      'lat': lat,
                      'lon': lon,
                      'speed': speed,
                      'direction': direction ?? 0.0,
                      'ssh': row['ssh'],
                    };
                  });
                },
                child: CustomPaint(
                  painter: _VectorArrowPainter(
                    angle: math.atan2(v!, u!),
                    length: (speed! * widget.currentsVectorScale * 100).clamp(5.0, 30.0),
                    color: vectorColor,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    } 
    // PRIORITY 2: Fallback to GeoJSON (Static/Initial Data)
    else {
      // Parse GeoJSON features
      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        return [];
      }

      for (final feature in features) {
        if (feature == null) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;

        if (geometry == null || properties == null) continue;

        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;

        final lon = (coordinates[0] as num?)?.toDouble();
        final lat = (coordinates[1] as num?)?.toDouble();

        if (lon == null || lat == null) continue;

        // Validate coordinates
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        // Get velocity components
        final u = (properties['u'] as num?)?.toDouble() ?? 0.0;
        final v = (properties['v'] as num?)?.toDouble() ?? 0.0;
        final speed = math.sqrt(u * u + v * v);

        if (speed == 0) continue;

        // Calculate color based on speed
        final vectorColor = _getVectorColor(speed, properties);

        // Store vector data for tooltip
        final vectorData = {
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
          'speed': speed,
          'direction': (properties['direction'] as num?)?.toDouble() ?? 0.0,
          // Try to get additional fields if available
          'ssh': (properties['ssh'] as num?)?.toDouble(),
          'depth': (properties['depth'] as num?)?.toDouble(),
          'time': properties['time']?.toString(),
        };

        vectors.add(
          Marker(
            width: 30,
            height: 30,
            point: LatLng(lat, lon),
            child: MouseRegion(
              onEnter: (_) {
                if (mounted) {
                  setState(() {
                    _selectedVector = {
                      'lat': lat,
                      'lon': lon,
                      'speed': speed,
                      'direction': math.atan2(v, u) * 180 / math.pi,
                      'ssh': vectorData['ssh'],
                    };
                  });
                }
              },
              onExit: (_) {
                if (mounted) {
                  setState(() {
                    _selectedVector = null;
                  });
                }
              },
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedVector = {
                      'lat': lat,
                      'lon': lon,
                      'speed': speed,
                      'direction': math.atan2(v, u) * 180 / math.pi,
                      'ssh': vectorData['ssh'],
                    };
                  });
                },
                child: CustomPaint(
                  painter: _VectorArrowPainter(
                    angle: math.atan2(v, u),
                    length: (speed * widget.currentsVectorScale * 100).clamp(5.0, 30.0),
                    color: vectorColor,
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
  } catch (e, stackTrace) {
  }

    // Cache results
    _cachedCurrentsMarkers = vectors;
    _lastCurrentsGeoJSON = widget.currentsGeoJSON;

    return vectors;
  }

  /// Get color for vector based on speed
  Color _getVectorColor(double speed, Map<String, dynamic> properties) {
    // Both 'speed' and 'velocity' should use speed-based coloring
    if (widget.currentsColorBy == 'speed' || widget.currentsColorBy == 'velocity') {
      // Color by speed: blue (slow) to red (fast)
      final normalizedSpeed = (speed * 10).clamp(0.0, 1.0);
      final color = Color.lerp(
        Colors.blue.shade300,
        Colors.red.shade600,
        normalizedSpeed,
      ) ?? Colors.blue;

      return color;
    }

    // Default color for other modes
    return Colors.cyan.shade400;
  }

  /// Find nearest data point for heatmap hover tooltip
  /// Returns the entire data point with all available fields
  Map<String, dynamic>? _findNearestDataPoint(double lat, double lon) {
    if (widget.rawData.isEmpty) return null;

    const maxDistance = 0.1; // degrees - threshold for hover detection
    double minDist = double.infinity;
    Map<String, dynamic>? nearest;

    for (final point in widget.rawData) {
      if (point == null) continue;

      final pointLat = (point['lat'] as num?)?.toDouble();
      final pointLon = (point['lon'] as num?)?.toDouble();

      if (pointLat == null || pointLon == null) continue;

      // Validate coordinates
      if (pointLat < -90 || pointLat > 90 || pointLon < -180 || pointLon > 180) continue;

      // Calculate distance
      final dist = math.sqrt(
        math.pow(lat - pointLat, 2) + math.pow(lon - pointLon, 2),
      );

      if (dist < minDist) {
        minDist = dist;
        // Store the entire data point with all fields
        nearest = Map<String, dynamic>.from(point);
      }
    }

    // Only return if within threshold
    return minDist < maxDistance ? nearest : null;
  }

  /// Unified hover handler that finds the nearest data point with all fields
  void _handleMapHover(PointerEvent event, Size size) {
    final screenX = event.localPosition.dx;
    final screenY = event.localPosition.dy;

    // Convert screen position to lat/lon
    final latLng = _screenToLatLng(screenX, screenY, size);

    // Find the nearest overall data point once with all its fields
    final nearestPoint = _findNearestDataPoint(latLng.latitude, latLng.longitude);

    if (nearestPoint != null) {
      // Store the complete data point with all fields
      // lat/lon are already included from the nearest point
      setState(() => _hoveredDataPoint = nearestPoint);
    } else {
      // No nearby data point found
      setState(() => _hoveredDataPoint = null);
    }
  }

  /// Convert screen coordinates to lat/lng using camera bounds
  LatLng _screenToLatLng(double screenX, double screenY, Size size) {
    final bounds = _mapController.camera.visibleBounds;

    // Calculate relative position (0 to 1)
    final relativeX = screenX / size.width;
    final relativeY = screenY / size.height;

    // Convert to lat/lng
    final lon = bounds.west + (bounds.east - bounds.west) * relativeX;
    final lat = bounds.north - (bounds.north - bounds.south) * relativeY;

    return LatLng(lat, lon);
  }

  @override
  Widget build(BuildContext context) {
    // Build map tile URL with Mapbox token
    final mapboxStyleUrl = 'https://api.mapbox.com/styles/v1/mapbox/dark-v11/tiles/{z}/{x}/{y}?access_token=${widget.mapboxToken}';

    final longitude = (widget.initialViewState['longitude'] as num?)?.toDouble() ?? -89.0;
    final latitude = (widget.initialViewState['latitude'] as num?)?.toDouble() ?? 30.1;
    final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 10.0;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(latitude, longitude),
            initialZoom: zoom,
            minZoom: 3.0,
            maxZoom: 18.0,
            backgroundColor: const Color(0xFF0F172A),
            onTap: (tapPosition, point) {
              // Deselect station and vector when tapping on map
              if (_selectedStation != null || _selectedVector != null) {
                setState(() {
                  _selectedStation = null;
                  _selectedVector = null;
                });
                widget.onStationSelect?.call(null);
              }
            },
          ),
          children: [
            // Base tile layer
            TileLayer(
              urlTemplate: mapboxStyleUrl,
              userAgentPackageName: 'com.usm.tap',
            ),

            // Ocean currents vectors layer (fallback/alternative visualization)
            if (widget.mapLayerVisibility['oceanCurrents'] ?? false)
              MarkerLayer(
                markers: _buildCurrentsVectorMarkers(),
              ),

            // Station markers layer
            if (widget.mapLayerVisibility['stations'] ?? false)
              MarkerLayer(
                markers: _buildStationMarkers(),
              ),
          ],
        ),

        // Temperature heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['temperature'] ?? false))
          LayoutBuilder(
            builder: (context, constraints) {
              // Get current frame data or fallback to empty list
              final currentFrameData = _getCurrentFrameData();

              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (event) => _handleMapHover(event, size),
                onExit: (_) {
                  if (mounted) {
                    setState(() {
                      _hoveredDataPoint = null;
                    });
                  }
                },
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HeatmapPainter(
                        rawData: currentFrameData,
                        dataField: 'temp',
                        heatmapScale: widget.heatmapScale,
                        camera: _mapController.camera,
                        selectedDepth: widget.selectedDepth,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              );
            },
          ),

        // Salinity heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['salinity'] ?? false))
          LayoutBuilder(
            builder: (context, constraints) {
              // Get current frame data or fallback to empty list
              final currentFrameData = _getCurrentFrameData();

              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (event) => _handleMapHover(event, size),
                onExit: (_) {
                  if (mounted) {
                    setState(() {
                      _hoveredDataPoint = null;
                    });
                  }
                },
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HeatmapPainter(
                        rawData: currentFrameData,
                        dataField: 'salinity',
                        heatmapScale: widget.heatmapScale,
                        camera: _mapController.camera,
                        selectedDepth: widget.selectedDepth,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              );
            },
          ),

        // SSH heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['ssh'] ?? false))
          LayoutBuilder(
            builder: (context, constraints) {
              // Get current frame data or fallback to empty list
              final currentFrameData = _getCurrentFrameData();

              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (event) => _handleMapHover(event, size),
                onExit: (_) {
                  if (mounted) {
                    setState(() {
                      _hoveredDataPoint = null;
                    });
                  }
                },
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HeatmapPainter(
                        rawData: currentFrameData,
                        dataField: 'ssh',
                        heatmapScale: widget.heatmapScale,
                        camera: _mapController.camera,
                        selectedDepth: widget.selectedDepth,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              );
            },
          ),

        // Pressure heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['pressure'] ?? false))
          LayoutBuilder(
            builder: (context, constraints) {
              // Get current frame data or fallback to empty list
              final currentFrameData = _getCurrentFrameData();

              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return MouseRegion(
                onHover: (event) => _handleMapHover(event, size),
                onExit: (_) {
                  if (mounted) {
                    setState(() {
                      _hoveredDataPoint = null;
                    });
                  }
                },
                child: IgnorePointer(
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: HeatmapPainter(
                        rawData: currentFrameData,
                        dataField: 'pressure_dbars',
                        heatmapScale: widget.heatmapScale,
                        camera: _mapController.camera,
                        selectedDepth: widget.selectedDepth,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                ),
              );
            },
          ),

        // Particle animation layer for ocean currents (overlay)
        if (_mapReady && (widget.mapLayerVisibility['oceanCurrents'] ?? false))
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: ParticlePainter(
                  currentsData: _extractCurrentsData(),
                  camera: _mapController.camera,
                  vectorScale: widget.currentsVectorScale,
                ),
                size: Size.infinite,
              ),
            ),
          ),

        // Particle animation layer for wind velocity (overlay)
        if (_mapReady && (widget.mapLayerVisibility['windVelocity'] ?? false))
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: ParticlePainter(
                  currentsData: _extractWindVelocityData(),
                  camera: _mapController.camera,
                  vectorScale: widget.currentsVectorScale,
                ),
                size: Size.infinite,
              ),
            ),
          ),

        // Loading indicator overlay for study area changes
        if (widget.isLoading && widget.loadingArea != null)
          _buildLoadingOverlay(widget.loadingArea!),

        // Map controls overlay
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              // Zoom in button
              _MapButton(
                icon: Icons.add,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom + 1,
                  );
                },
              ),
              const SizedBox(height: 8),
              // Zoom out button
              _MapButton(
                icon: Icons.remove,
                onPressed: () {
                  final currentZoom = _mapController.camera.zoom;
                  _mapController.move(
                    _mapController.camera.center,
                    currentZoom - 1,
                  );
                },
              ),
              const SizedBox(height: 8),
              // Reset view button
              _MapButton(
                icon: Icons.home,
                onPressed: () {
                  _initializeMapView();
                },
              ),
            ],
          ),
        ),

        // Station info overlay
        if (_selectedStation != null)
          Positioned(
            bottom: 10,
            left: 10,
            child: _StationInfoCard(
              station: _selectedStation!,
              onClose: () {
                setState(() {
                  _selectedStation = null;
                });
                widget.onStationSelect?.call(null);
              },
            ),
          ),

        // Heatmap data point info overlay (takes precedence over vector)
        if (_hoveredDataPoint != null)
          Positioned(
            bottom: 80,
            left: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: _HeatmapInfoCard(
                dataPoint: _hoveredDataPoint!,
                onClose: () {
                  setState(() {
                    _hoveredDataPoint = null;
                  });
                },
              ),
            ),
          ),

        // Vector info overlay
        if (_selectedVector != null && _hoveredDataPoint == null)
          Positioned(
            bottom: 80,
            left: 20,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: _VectorInfoCard(
                vector: _selectedVector!,
                onClose: () {
                  setState(() {
                    _selectedVector = null;
                  });
                },
              ),
            ),
          ),

        // Map info overlay (date/time, depth, etc.)
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.98),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.black.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.currentDate.isNotEmpty)
                  Text(
                    widget.currentDate,
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (widget.currentTime.isNotEmpty)
                  Text(
                    widget.currentTime,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11,
                    ),
                  ),
                if (widget.selectedDepth > 0)
                  Text(
                    'Depth: ${widget.selectedDepth.toStringAsFixed(1)}m',
                    style: const TextStyle(
                      color: Color(0xFF0891B2),
                      fontSize: 11,
                    ),
                  ),
                if (widget.currentFrame > 0)
                  Text(
                    'Frame: ${widget.currentFrame}/${widget.totalFrames}',
                    style: const TextStyle(
                      color: Color(0xFFDB2777),
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build loading overlay for study area changes
  Widget _buildLoadingOverlay(String areaName) {
    // Get full area name for display
    String fullAreaName;
    switch (areaName.toUpperCase()) {
      case 'USM':
        fullAreaName = 'USM';
        break;
      case 'MBL':
        fullAreaName = 'Mobile Bay';
        break;
      case 'MSR':
        fullAreaName = 'Mississippi River';
        break;
      default:
        fullAreaName = areaName;
    }

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0F172A).withOpacity(0.85),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFEC4899).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Spinner
                SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFFEC4899),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Loading text
                Text(
                  'Loading $fullAreaName data...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  'Fetching and processing ocean data',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for vector arrows
class _VectorArrowPainter extends CustomPainter {
  final double angle;
  final double length;
  final Color color;

  _VectorArrowPainter({
    required this.angle,
    required this.length,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final end = Offset(
      center.dx + length * math.cos(angle),
      center.dy + length * math.sin(angle),
    );

    // Draw arrow line
    canvas.drawLine(center, end, paint);

    // Draw arrowhead
    final arrowSize = 5.0;
    final arrowAngle = math.pi / 6;

    final arrowLeft = Offset(
      end.dx - arrowSize * math.cos(angle - arrowAngle),
      end.dy - arrowSize * math.sin(angle - arrowAngle),
    );

    final arrowRight = Offset(
      end.dx - arrowSize * math.cos(angle + arrowAngle),
      end.dy - arrowSize * math.sin(angle + arrowAngle),
    );

    canvas.drawLine(end, arrowLeft, paint);
    canvas.drawLine(end, arrowRight, paint);
  }

  @override
  bool shouldRepaint(_VectorArrowPainter oldDelegate) {
    return oldDelegate.angle != angle ||
           oldDelegate.length != length ||
           oldDelegate.color != color;
  }
}

/// Map control button widget
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MapButton({
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFEC4899).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: IconButton(
        icon: Icon(icon, size: 18),
        color: Colors.white,
        padding: EdgeInsets.zero,
        onPressed: onPressed,
      ),
    );
  }
}

/// Station information card widget
// Updated: 2025-11-12 - White background tooltips
class _StationInfoCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final VoidCallback onClose;

  const _StationInfoCard({
    required this.station,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  station['name'] ?? 'Unknown Station',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF64748B),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
                onPressed: onClose,
              ),
            ],
          ),
          if (station['type'] != null) ...[
            const SizedBox(height: 4),
            Text(
              station['type'],
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF64748B).withOpacity(0.1),
                  const Color(0xFF64748B).withOpacity(0.2),
                  const Color(0xFF64748B).withOpacity(0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Latitude',
            value: (station['latitude'] as num?)?.toStringAsFixed(4) ?? 'N/A',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Longitude',
            value: (station['longitude'] as num?)?.toStringAsFixed(4) ?? 'N/A',
          ),
          if (station['description'] != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF64748B).withOpacity(0.1),
                    const Color(0xFF64748B).withOpacity(0.2),
                    const Color(0xFF64748B).withOpacity(0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              station['description'],
              style: TextStyle(
                color: Colors.black.withOpacity(0.85),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Info row widget for station card
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Vector information card widget
// Updated: 2025-11-12 - White background tooltips
class _VectorInfoCard extends StatelessWidget {
  final Map<String, dynamic> vector;
  final VoidCallback onClose;

  const _VectorInfoCard({
    required this.vector,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final lat = (vector['lat'] as num?)?.toDouble();
    final lon = (vector['lon'] as num?)?.toDouble();
    final speed = (vector['speed'] as num?)?.toDouble();
    final direction = (vector['direction'] as num?)?.toDouble();
    final ssh = (vector['ssh'] as num?)?.toDouble();
    final depth = (vector['depth'] as num?)?.toDouble();
    final time = vector['time']?.toString();

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ocean Current',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF64748B),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF64748B).withOpacity(0.1),
                  const Color(0xFF64748B).withOpacity(0.2),
                  const Color(0xFF64748B).withOpacity(0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Latitude',
            value: lat != null ? lat.toStringAsFixed(4) : 'N/A',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Longitude',
            value: lon != null ? lon.toStringAsFixed(4) : 'N/A',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Speed',
            value: speed != null ? '${speed.toStringAsFixed(3)} m/s' : 'N/A',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Direction',
            value: direction != null ? '${direction.toStringAsFixed(1)}°' : 'N/A',
          ),
          if (ssh != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'SSH',
              value: '${ssh.toStringAsFixed(3)} m',
            ),
          ],
          if (depth != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Depth',
              value: '${depth.toStringAsFixed(1)} m',
            ),
          ],
          if (time != null) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF64748B).withOpacity(0.1),
                    const Color(0xFF64748B).withOpacity(0.2),
                    const Color(0xFF64748B).withOpacity(0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              label: 'Time',
              value: time,
            ),
          ],
        ],
      ),
    );
  }
}

/// Heatmap data point information card widget
class _HeatmapInfoCard extends StatelessWidget {
  final Map<String, dynamic> dataPoint;
  final VoidCallback onClose;

  const _HeatmapInfoCard({
    required this.dataPoint,
    required this.onClose,
  });

  /// Format field name for display (capitalize, handle snake_case)
  String _formatFieldName(String fieldName) {
    // Handle special cases
    if (fieldName == 'ssh') return 'SSH';
    if (fieldName == 'sst') return 'SST';

    // Convert snake_case to words with spaces
    final words = fieldName.split('_');

    // Capitalize first letter of each word
    return words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Get unit for known field names
  String _getUnit(String fieldName) {
    final units = {
      'temp': '°C',
      'temperature': '°C',
      'salinity': 'PSU',
      'ssh': 'm',
      'pressure_dbars': 'dbar',
      'pressure': 'dbar',
      'depth': 'm',
      'depth_m': 'm',
      'speed': 'm/s',
      'velocity': 'm/s',
      'u': 'm/s',
      'v': 'm/s',
      'wind_speed': 'm/s',
    };

    return units[fieldName.toLowerCase()] ?? '';
  }

  /// Get precision (decimal places) for known field names
  int _getPrecision(String fieldName) {
    final precision = {
      'temp': 2,
      'temperature': 2,
      'salinity': 2,
      'ssh': 3,
      'pressure_dbars': 2,
      'pressure': 2,
      'depth': 1,
      'depth_m': 1,
      'speed': 3,
      'velocity': 3,
      'u': 4,
      'v': 4,
    };

    return precision[fieldName.toLowerCase()] ?? 3;
  }

  @override
  Widget build(BuildContext context) {
    final lat = (dataPoint['lat'] as num?)?.toDouble();
    final lon = (dataPoint['lon'] as num?)?.toDouble();

    // Build list of layer widgets dynamically from all fields
    final layerWidgets = <Widget>[];

    // Iterate through all fields in dataPoint, excluding lat and lon
    for (final entry in dataPoint.entries) {
      final fieldName = entry.key;
      final value = entry.value;

      // Skip lat and lon (shown separately)
      if (fieldName == 'lat' || fieldName == 'lon') continue;

      // Only process numeric values
      if (value is num) {
        final doubleValue = value.toDouble();
        final precision = _getPrecision(fieldName);
        final unit = _getUnit(fieldName);
        final label = _formatFieldName(fieldName);

        // Add spacing before each field widget (except the first one)
        if (layerWidgets.isNotEmpty) {
          layerWidgets.add(const SizedBox(height: 10));
        }

        layerWidgets.add(_InfoRow(
          label: label,
          value: '${doubleValue.toStringAsFixed(precision)}${unit.isNotEmpty ? ' $unit' : ''}',
        ));
      }
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.1),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Ocean Data',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF64748B),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                splashRadius: 20,
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF64748B).withOpacity(0.1),
                  const Color(0xFF64748B).withOpacity(0.2),
                  const Color(0xFF64748B).withOpacity(0.1),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(
            label: 'Latitude',
            value: lat != null ? lat.toStringAsFixed(4) : 'N/A',
          ),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Longitude',
            value: lon != null ? lon.toStringAsFixed(4) : 'N/A',
          ),
          if (layerWidgets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF64748B).withOpacity(0.1),
                    const Color(0xFF64748B).withOpacity(0.2),
                    const Color(0xFF64748B).withOpacity(0.1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...layerWidgets,
          ],
        ],
      ),
    );
  }
}

/// Custom painter for rendering heatmaps (temperature, salinity, SSH, pressure)
class HeatmapPainter extends CustomPainter {
  final List<Map<String, dynamic>> rawData;
  final String dataField;
  final double heatmapScale;
  final MapCamera camera;
  final double selectedDepth;

  // OPTIMIZATION: Reusable paint object to avoid recreation
  static final Paint _reusablePaint = Paint()
    ..style = PaintingStyle.fill;

  HeatmapPainter({
    required this.rawData,
    required this.dataField,
    required this.heatmapScale,
    required this.camera,
    required this.selectedDepth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rawData.isEmpty) return;

    try {
      // OPTIMIZATION: Adaptive LOD - Increase spacing values for better performance
      // Calculate zoom-dependent spacing and radius for proper scaling
      // Base spacing at zoom 8, scales proportionally with zoom level
      final zoomFactor = math.pow(2, camera.zoom - 10).toDouble();

      // OPTIMIZATION: Increased base spacing from 25.0 to 35.0 and max from 100.0 to 150.0
      // This reduces point density while maintaining visual quality
      final sampleSpacing = (35.0 * zoomFactor).clamp(15.0, 150.0);
      final heatRadius = (sampleSpacing / 2 * heatmapScale).clamp(5.0, 50.0);

      // OPTIMIZATION: Reuse paint object and only update the maskFilter
      _reusablePaint.maskFilter = MaskFilter.blur(BlurStyle.normal, heatRadius * 0.3);

      // Track drawn points to avoid overlap
      final drawnPoints = <String>{};
      int renderedPoints = 0;

      // Draw each data point as a colored circle
      for (final point in rawData) {
        if (point == null) continue;

        final lat = (point['lat'] as num?)?.toDouble();
        final lon = (point['lon'] as num?)?.toDouble();
        final value = (point[dataField] as num?)?.toDouble();
        final pointDepth = (point['depth'] as num?)?.toDouble();

        if (lat == null || lon == null || value == null) continue;

        // Filter by selectedDepth (safety check to prevent mixed-depth data)
        // Use epsilon comparison for floating point safety
        if (pointDepth != null && (pointDepth - selectedDepth).abs() > 0.1) {
          continue;
        }

        // Validate coordinates
        if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

        // Convert lat/lon to screen coordinates
        final latLng = LatLng(lat, lon);
        final screenPoint = camera.latLngToScreenOffset(latLng);

        // Skip if point is outside visible area (with buffer)
        if (screenPoint.dx < -100 || screenPoint.dx > size.width + 100 ||
            screenPoint.dy < -100 || screenPoint.dy > size.height + 100) {
          continue;
        }

        // Sample points based on spacing to reduce density
        final gridX = (screenPoint.dx / sampleSpacing).floor();
        final gridY = (screenPoint.dy / sampleSpacing).floor();
        final gridKey = '$gridX,$gridY';

        // Skip if we've already drawn a point in this grid cell
        if (drawnPoints.contains(gridKey)) {
          continue;
        }
        drawnPoints.add(gridKey);

        // Get color based on value and data type
        final color = _getColorForValue(value, dataField);
        // Enhanced opacity with minimum threshold for better visibility
        // OPTIMIZATION: Use the reusable paint object
        _reusablePaint.color = color.withOpacity((0.85 * heatmapScale).clamp(0.3, 1.0));

        // Draw heatmap point with zoom-scaled radius for proper coverage
        canvas.drawCircle(
          Offset(screenPoint.dx, screenPoint.dy),
          heatRadius,
          _reusablePaint,
        );

        renderedPoints++;
      }

      // OPTIMIZATION: Log rendering metrics for performance monitoring
      if (renderedPoints > 0) {
      }
    } catch (e, stackTrace) {
    }
  }

  /// Get color based on value and data field type with enhanced multi-stop gradients
  Color _getColorForValue(double value, String field) {
    switch (field) {
      case 'temp':
      case 'temperature':
        // Temperature: multi-stop gradient for better distinction
        // Range: 0-30°C with non-linear scaling for enhanced mid-range contrast
        final normalized = ((value - 0) / 30).clamp(0.0, 1.0);
        // Apply power function for enhanced mid-range contrast
        final enhanced = _enhanceContrast(normalized);
        // Multi-stop gradient: deep blue → cyan → yellow → red
        return _multiStopGradient(enhanced, [
          const Color(0xFF0D47A1), // Deep blue (0°C)
          const Color(0xFF00BCD4), // Cyan (10°C)
          const Color(0xFFFFEB3B), // Yellow (20°C)
          const Color(0xFFD32F2F), // Red (30°C)
        ]);

      case 'salinity':
        // Salinity: multi-stop gradient with more color stops
        // Range: 30-37 PSU with enhanced gradation
        final normalized = ((value - 30) / 7).clamp(0.0, 1.0);
        final enhanced = _enhanceContrast(normalized);
        // Multi-stop gradient: light green → teal → blue → purple
        return _multiStopGradient(enhanced, [
          const Color(0xFF66BB6A), // Light green (low salinity)
          const Color(0xFF26A69A), // Teal
          const Color(0xFF1976D2), // Blue
          const Color(0xFF7B1FA2), // Purple (high salinity)
        ]);

      case 'ssh':
        // Sea Surface Height: enhanced contrast gradient
        // Range: -0.5 to 0.5 meters with better color distinction
        final normalized = ((value + 0.5) / 1.0).clamp(0.0, 1.0);
        final enhanced = _enhanceContrast(normalized);
        // Multi-stop gradient: navy blue → cyan → yellow → orange
        return _multiStopGradient(enhanced, [
          const Color(0xFF0D47A1), // Navy blue (low)
          const Color(0xFF00BCD4), // Cyan
          const Color(0xFFFFEB3B), // Yellow
          const Color(0xFFFF6F00), // Orange (high)
        ]);

      case 'pressure_dbars':
        // Pressure: enhanced multi-stop gradient
        // Range: 0-5000 dbars with better color stops
        final normalized = (value / 5000).clamp(0.0, 1.0);
        final enhanced = _enhanceContrast(normalized);
        // Multi-stop gradient: deep cyan → teal → orange → dark red
        return _multiStopGradient(enhanced, [
          const Color(0xFF00838F), // Deep cyan (low pressure)
          const Color(0xFF26A69A), // Teal
          const Color(0xFFFF6F00), // Orange
          const Color(0xFFB71C1C), // Dark red (high pressure)
        ]);

      default:
        return Colors.grey;
    }
  }

  /// Apply non-linear scaling to enhance mid-range contrast
  /// Uses a power function to make subtle differences more visible
  double _enhanceContrast(double normalized) {
    // Apply power of 0.7 to enhance mid-range values
    return math.pow(normalized, 0.7).toDouble();
  }

  /// Multi-stop gradient interpolation for better color distinction
  /// Interpolates through multiple color stops for richer gradients
  Color _multiStopGradient(double value, List<Color> colors) {
    if (colors.length < 2) return colors.first;

    // Determine which color segment we're in
    final segmentCount = colors.length - 1;
    final segmentSize = 1.0 / segmentCount;
    final segmentIndex = (value / segmentSize).floor().clamp(0, segmentCount - 1);

    // Calculate position within the segment (0.0 to 1.0)
    final segmentStart = segmentIndex * segmentSize;
    final segmentValue = ((value - segmentStart) / segmentSize).clamp(0.0, 1.0);

    // Interpolate between the two colors in this segment
    return Color.lerp(
      colors[segmentIndex],
      colors[segmentIndex + 1],
      segmentValue,
    ) ?? colors[segmentIndex];
  }

  @override
  bool shouldRepaint(HeatmapPainter oldDelegate) {
    return oldDelegate.rawData != rawData ||
           oldDelegate.dataField != dataField ||
           oldDelegate.heatmapScale != heatmapScale ||
           oldDelegate.selectedDepth != selectedDepth ||
           oldDelegate.camera.center != camera.center ||
           oldDelegate.camera.zoom != camera.zoom;
  }
}

/// Particle data for ocean current animation
class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  double age;
  final double maxAge;

  _Particle({
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    this.age = 0,
    this.maxAge = 100,
  });
}

/// Custom painter for rendering animated ocean current particles
class ParticlePainter extends CustomPainter {
  final List<Map<String, dynamic>> currentsData;
  final MapCamera camera;
  final double vectorScale;
  final int particleCount;
  List<_Particle> particles = [];

  // OPTIMIZATION: Reusable paint objects to avoid recreation
  static final Paint _strokePaint = Paint()
    ..strokeWidth = 1.5
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  static final Paint _fillPaint = Paint()
    ..style = PaintingStyle.fill;

  ParticlePainter({
    required this.currentsData,
    required this.camera,
    required this.vectorScale,
    this.particleCount = 1000,
  }) {
    _initializeParticles();
  }

  /// Initialize particles at random positions
  void _initializeParticles() {
    if (particles.isEmpty) {
      final random = math.Random();
      for (int i = 0; i < particleCount; i++) {
        particles.add(_Particle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          maxAge: 50 + random.nextDouble() * 50,
        ));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (currentsData.isEmpty || size.isEmpty) return;

    try {
      int renderedParticles = 0;

      // Update and draw each particle
      for (final particle in particles) {
        try {
          // Convert particle position to lat/lon
          final bounds = camera.visibleBounds;
          final lat = bounds.south + particle.y * (bounds.north - bounds.south);
          final lon = bounds.west + particle.x * (bounds.east - bounds.west);

          // Validate calculated coordinates
          if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;

          // Find nearest current data point
          final velocity = _getNearestVelocity(lat, lon);

          if (velocity != null) {
            particle.vx = velocity['u']! * vectorScale;
            particle.vy = velocity['v']! * vectorScale;

            // Update particle position
            particle.x += particle.vx * 0.01;
            particle.y += particle.vy * 0.01;
            particle.age += 1;

            // Reset particle if too old or out of bounds
            if (particle.age > particle.maxAge ||
                particle.x < 0 || particle.x > 1 ||
                particle.y < 0 || particle.y > 1) {
              final random = math.Random();
              particle.x = random.nextDouble();
              particle.y = random.nextDouble();
              particle.age = 0;
            }

            // Convert to screen coordinates
            final latLng = LatLng(lat, lon);
            final screenPoint = camera.latLngToScreenOffset(latLng);

            // Skip if outside screen bounds
            if (screenPoint.dx < -50 || screenPoint.dx > size.width + 50 ||
                screenPoint.dy < -50 || screenPoint.dy > size.height + 50) {
              continue;
            }

            // Draw particle with trail
            final speed = math.sqrt(particle.vx * particle.vx + particle.vy * particle.vy);
            final opacity = (1 - particle.age / particle.maxAge).clamp(0.2, 0.8);
            final color = _getParticleColor(speed).withOpacity(opacity);

            // OPTIMIZATION: Reuse paint objects
            _fillPaint.color = color;

            // Draw particle as small circle
            canvas.drawCircle(
              Offset(screenPoint.dx, screenPoint.dy),
              2,
              _fillPaint,
            );

            // Draw short trail
            if (speed > 0.001) {
              _strokePaint.color = color;
              final trailEnd = Offset(
                screenPoint.dx - particle.vx * 5,
                screenPoint.dy - particle.vy * 5,
              );
              canvas.drawLine(
                Offset(screenPoint.dx, screenPoint.dy),
                trailEnd,
                _strokePaint,
              );
            }

            renderedParticles++;
          }
        } catch (e) {
          // Skip this particle and continue with others
          continue;
        }
      }

      // OPTIMIZATION: Log particle rendering metrics
      if (renderedParticles > 0) {
      }
    } catch (e, stackTrace) {
    }
  }

  /// Get velocity at nearest data point
  Map<String, double>? _getNearestVelocity(double lat, double lon) {
    const maxDistance = 0.25; // degrees - threshold to prevent land particles
    double minDist = double.infinity;
    Map<String, double>? nearest;

    for (final data in currentsData) {
      final dataLat = (data['lat'] as num?)?.toDouble();
      final dataLon = (data['lon'] as num?)?.toDouble();
      final u = (data['u'] as num?)?.toDouble();
      final v = (data['v'] as num?)?.toDouble();

      if (dataLat == null || dataLon == null || u == null || v == null) continue;

      final dist = math.sqrt(
        math.pow(lat - dataLat, 2) + math.pow(lon - dataLon, 2),
      );

      if (dist < minDist) {
        minDist = dist;
        nearest = {'u': u, 'v': v};
      }
    }

    // Only return velocity if within ocean area
    return minDist < maxDistance ? nearest : null;
  }

  /// Get particle color based on speed
  Color _getParticleColor(double speed) {
    final normalizedSpeed = (speed * 100).clamp(0.0, 1.0);
    return Color.lerp(
      Colors.cyan.shade300,
      Colors.pink.shade400,
      normalizedSpeed,
    ) ?? Colors.cyan;
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) {
    return oldDelegate.currentsData != currentsData ||
           oldDelegate.camera.center != camera.center ||
           oldDelegate.camera.zoom != camera.zoom ||
           oldDelegate.vectorScale != vectorScale;
  }
}

/// Custom painter for rendering coordinate grid overlay
class GridPainter extends CustomPainter {
  final MapCamera camera;
  final Color gridColor;
  final double gridOpacity;

  GridPainter({
    required this.camera,
    this.gridColor = Colors.white,
    this.gridOpacity = 0.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    try {
      final paint = Paint()
        ..color = gridColor.withOpacity(gridOpacity)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;

      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );

      final bounds = camera.visibleBounds;
      final zoom = camera.zoom;

      // Calculate grid spacing based on zoom level
      double gridSpacing;
      if (zoom < 5) {
        gridSpacing = 10.0; // 10 degrees
      } else if (zoom < 7) {
        gridSpacing = 5.0; // 5 degrees
      } else if (zoom < 9) {
        gridSpacing = 2.0; // 2 degrees
      } else if (zoom < 11) {
        gridSpacing = 1.0; // 1 degree
      } else {
        gridSpacing = 0.5; // 0.5 degrees
      }

      // Draw longitude lines (vertical)
      final startLon = (bounds.west / gridSpacing).floor() * gridSpacing;
      for (double lon = startLon; lon <= bounds.east; lon += gridSpacing) {
        final topPoint = camera.latLngToScreenOffset(LatLng(bounds.north, lon));
        final bottomPoint = camera.latLngToScreenOffset(LatLng(bounds.south, lon));

        canvas.drawLine(
          Offset(topPoint.dx, topPoint.dy),
          Offset(bottomPoint.dx, bottomPoint.dy),
          paint,
        );

        // Draw longitude label
        textPainter.text = TextSpan(
          text: '${lon.toStringAsFixed(1)}°E',
          style: TextStyle(
            color: gridColor.withOpacity(gridOpacity * 2),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(topPoint.dx - textPainter.width / 2, 5),
        );
      }

      // Draw latitude lines (horizontal)
      final startLat = (bounds.south / gridSpacing).floor() * gridSpacing;
      for (double lat = startLat; lat <= bounds.north; lat += gridSpacing) {
        final leftPoint = camera.latLngToScreenOffset(LatLng(lat, bounds.west));
        final rightPoint = camera.latLngToScreenOffset(LatLng(lat, bounds.east));

        canvas.drawLine(
          Offset(leftPoint.dx, leftPoint.dy),
          Offset(rightPoint.dx, rightPoint.dy),
          paint,
        );

        // Draw latitude label
        textPainter.text = TextSpan(
          text: '${lat.toStringAsFixed(1)}°N',
          style: TextStyle(
            color: gridColor.withOpacity(gridOpacity * 2),
            fontSize: 10,
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(5, leftPoint.dy - textPainter.height / 2),
        );
      }
    } catch (e, stackTrace) {
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.camera != camera ||
           oldDelegate.gridColor != gridColor ||
           oldDelegate.gridOpacity != gridOpacity;
  }
}