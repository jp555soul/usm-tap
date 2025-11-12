import 'package:flutter/material.dart';
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
      'zoom': 10,
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
  }) : super(key: key);

  @override
  State<NativeOceanMapWidget> createState() => _NativeOceanMapWidgetState();
}

class _NativeOceanMapWidgetState extends State<NativeOceanMapWidget> {
  late MapController _mapController;
  Map<String, dynamic>? _selectedStation;
  Map<String, dynamic>? _selectedVector;
  bool _isLoading = false;
  bool _mapReady = false;
  int _rebuildCount = 0;
  DateTime? _lastUpdateTime;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    debugPrint('🗺️ NATIVE MAP INIT: ${DateTime.now()} - Instance: $hashCode');

    // Listen to map events (zoom, pan, rotate) and force redraw
    _mapController.mapEventStream.listen((event) {
      if (event is MapEventMove || event is MapEventRotate) {
        // Log zoom changes for debugging
        if (event is MapEventMove && event.source == MapEventSource.mapController) {
          debugPrint('🔍 ZOOM: level ${event.camera.zoom.toStringAsFixed(2)} | forcing redraw');
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
      debugPrint('🗺️ NATIVE MAP DISPOSE: ${DateTime.now()} - Instance: $hashCode | Rebuilds: $_rebuildCount');
      _mapController.dispose();
      _mapReady = false;
      _selectedStation = null;
      _selectedVector = null;
    } catch (e) {
      debugPrint('⚠️ Error during map disposal: $e');
    } finally {
      super.dispose();
    }
  }

  void _initializeMapView() {
    try {
      final longitude = (widget.initialViewState['longitude'] as num?)?.toDouble() ?? -89.0;
      final latitude = (widget.initialViewState['latitude'] as num?)?.toDouble() ?? 30.1;
      final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 10.0;

      _mapController.move(LatLng(latitude, longitude), zoom);
      debugPrint('🗺️ Map initialized: lat=$latitude, lon=$longitude, zoom=$zoom');
    } catch (e) {
      debugPrint('⚠️ Error initializing map view: $e');
    }
  }

  @override
  void didUpdateWidget(NativeOceanMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    _rebuildCount++;
    final now = DateTime.now();
    final timeSinceLastUpdate = _lastUpdateTime != null
        ? now.difference(_lastUpdateTime!).inMilliseconds
        : 0;
    _lastUpdateTime = now;

    // Track all critical prop changes with enhanced logging
    final List<String> changes = [];

    if (oldWidget.currentFrame != widget.currentFrame) {
      changes.add('frame(${oldWidget.currentFrame}→${widget.currentFrame})');
    }

    if (oldWidget.selectedDepth != widget.selectedDepth) {
      changes.add('depth(${oldWidget.selectedDepth}→${widget.selectedDepth})');
    }

    if (oldWidget.selectedArea != widget.selectedArea) {
      changes.add('area(${oldWidget.selectedArea}→${widget.selectedArea})');
    }

    if (oldWidget.mapLayerVisibility != widget.mapLayerVisibility) {
      final oldLayers = oldWidget.mapLayerVisibility.entries.where((e) => e.value).map((e) => e.key).toList();
      final newLayers = widget.mapLayerVisibility.entries.where((e) => e.value).map((e) => e.key).toList();
      changes.add('layers($oldLayers→$newLayers)');
    }

    if (oldWidget.rawData.length != widget.rawData.length) {
      changes.add('rawData(${oldWidget.rawData.length}→${widget.rawData.length} pts)');
    }

    if (oldWidget.currentsGeoJSON != widget.currentsGeoJSON) {
      final oldFeatures = (oldWidget.currentsGeoJSON['features'] as List?)?.length ?? 0;
      final newFeatures = (widget.currentsGeoJSON['features'] as List?)?.length ?? 0;
      changes.add('currents($oldFeatures→$newFeatures features)');
    }

    if (oldWidget.windVelocityGeoJSON != widget.windVelocityGeoJSON) {
      final oldFeatures = (oldWidget.windVelocityGeoJSON['features'] as List?)?.length ?? 0;
      final newFeatures = (widget.windVelocityGeoJSON['features'] as List?)?.length ?? 0;
      changes.add('wind($oldFeatures→$newFeatures features)');
    }

    if (oldWidget.heatmapScale != widget.heatmapScale) {
      changes.add('heatmapScale(${oldWidget.heatmapScale.toStringAsFixed(2)}→${widget.heatmapScale.toStringAsFixed(2)})');
    }

    if (oldWidget.currentsVectorScale != widget.currentsVectorScale) {
      changes.add('vectorScale(${oldWidget.currentsVectorScale.toStringAsFixed(4)}→${widget.currentsVectorScale.toStringAsFixed(4)})');
    }

    // Log changes if any occurred
    if (changes.isNotEmpty) {
      debugPrint('🗺️ UPDATE [${now.toIso8601String().split('T')[1].substring(0, 12)}]: ${changes.join(', ')} | Rebuild #$_rebuildCount | Δt: ${timeSinceLastUpdate}ms');

      // Trigger map redraw when critical data changes
      if (_mapReady) {
        setState(() {
          // Force rebuild of custom painters
        });
      }
    }

    // Handle map controller updates when view state changes
    if (oldWidget.initialViewState != widget.initialViewState && _mapReady) {
      try {
        final longitude = (widget.initialViewState['longitude'] as num?)?.toDouble() ?? -89.0;
        final latitude = (widget.initialViewState['latitude'] as num?)?.toDouble() ?? 30.1;
        final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 10.0;

        _mapController.move(LatLng(latitude, longitude), zoom);
        debugPrint('🗺️ Map view animated to: lat=$latitude, lon=$longitude, zoom=$zoom');
      } catch (e) {
        debugPrint('⚠️ Error updating map view: $e');
      }
    }
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
      debugPrint('🌊 CURRENTS EXTRACTION: oceanCurrents layer visible=${widget.mapLayerVisibility['oceanCurrents']}');

      if (widget.currentsGeoJSON.isEmpty) {
        debugPrint('🌊 Ocean currents GeoJSON is empty');
        return [];
      }

      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        debugPrint('⚠️ No currents features found in GeoJSON');
        return [];
      }

      debugPrint('🌊 OCEAN CURRENTS: Extracting ${features.length} current features for particles');

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

        // Debug first 3 coordinate parses
        if (currentsData.length < 3) {
          debugPrint('🌊 CURRENT #${currentsData.length + 1}: GeoJSON coords=[$lon,$lat] | lat=$lat, lon=$lon, u=$u, v=$v');
        }

        currentsData.add({
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
        });
      }

      debugPrint('🌊 Extracted ${currentsData.length} current data points');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error extracting currents data: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return currentsData;
  }

  List<Map<String, dynamic>> _extractWindVelocityData() {
    final List<Map<String, dynamic>> windData = [];

    try {
      debugPrint('🌬️ WIND VELOCITY EXTRACTION: windVelocity layer visible=${widget.mapLayerVisibility['windVelocity']}');

      if (widget.windVelocityGeoJSON.isEmpty) {
        debugPrint('🌬️ Wind velocity GeoJSON is empty');
        return [];
      }

      final features = widget.windVelocityGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        debugPrint('⚠️ No wind features found in GeoJSON');
        return [];
      }

      debugPrint('🌬️ WIND VELOCITY: Extracting ${features.length} wind features');

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

        // Debug first 3 coordinate parses
        if (windData.length < 3) {
          debugPrint('🌬️ WIND #${windData.length + 1}: GeoJSON coords=[$lon,$lat] | lat=$lat, lon=$lon, u=$u, v=$v');
        }

        windData.add({
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
        });
      }

      debugPrint('🌬️ Extracted ${windData.length} wind data points');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error extracting wind velocity data: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    return windData;
  }

  /// Build ocean currents vector markers
  List<Marker> _buildCurrentsVectorMarkers() {
    final showCurrents = widget.mapLayerVisibility['oceanCurrents'] ?? false;

    if (!showCurrents || widget.currentsGeoJSON.isEmpty) {
      return [];
    }

    final List<Marker> vectors = [];
    // Debug tracking
    double minSpeed = double.infinity;
    double maxSpeed = 0.0;
    double totalSpeed = 0.0;
    int speedCount = 0;
    Map<String, int> colorDistribution = {'cyan': 0, 'blue': 0, 'red': 0, 'gradient': 0};

    try {
      // Parse GeoJSON features
      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null || features.isEmpty) {
        debugPrint('⚠️ No current vector features to render');
        return [];
      }

      debugPrint('🎨 VECTOR DEBUG: currentsColorBy="${widget.currentsColorBy}"');
      debugPrint('📦 GEOJSON DEBUG: features.length=${features.length}');

      // Log first feature properties to understand data structure
      if (features.isNotEmpty && features[0] != null) {
        final firstFeature = features[0];
        final firstProps = firstFeature['properties'] as Map<String, dynamic>?;
        if (firstProps != null) {
          debugPrint('🔍 FIRST FEATURE PROPERTIES: ${firstProps.keys.join(', ')}');
          debugPrint('🔍 SAMPLE VALUES: ${firstProps.toString()}');
        }
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

        // Debug coordinate parsing for first 3 vectors
        if (vectors.length < 3) {
          debugPrint('🎯 MARKER #${vectors.length + 1}: GeoJSON coords=[$lon,$lat] → LatLng($lat,$lon) | u=$u, v=$v, speed=${speed.toStringAsFixed(4)}');
        }

        // Track speed statistics
        minSpeed = math.min(minSpeed, speed);
        maxSpeed = math.max(maxSpeed, speed);
        totalSpeed += speed;
        speedCount++;

        // Calculate color based on speed
        final vectorColor = _getVectorColor(speed, properties);

        // Track color distribution
        if (vectorColor == Colors.cyan.shade400) {
          colorDistribution['cyan'] = (colorDistribution['cyan'] ?? 0) + 1;
        } else if (vectorColor == Colors.blue || vectorColor == Colors.blue.shade300) {
          colorDistribution['blue'] = (colorDistribution['blue'] ?? 0) + 1;
        } else if (vectorColor.red > 200) {
          colorDistribution['red'] = (colorDistribution['red'] ?? 0) + 1;
        } else {
          colorDistribution['gradient'] = (colorDistribution['gradient'] ?? 0) + 1;
        }

        // Log first 3 vectors for debugging
        if (vectors.length < 3) {
          final normalizedSpeed = (speed * 10).clamp(0.0, 1.0);
          debugPrint('🎨 VECTOR #${vectors.length + 1}: speed=${speed.toStringAsFixed(4)} | normalized=${normalizedSpeed.toStringAsFixed(4)} | color=rgb(${vectorColor.red},${vectorColor.green},${vectorColor.blue})');
        }

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
            child: GestureDetector(
              onTap: () {
                // Show SnackBar with vector details
                final direction = (vectorData['direction'] as num?)?.toDouble() ?? 0.0;
                final ssh = (vectorData['ssh'] as num?)?.toDouble();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lat: ${lat.toStringAsFixed(4)}, Lon: ${lon.toStringAsFixed(4)}'),
                        Text('Direction: ${direction.toStringAsFixed(1)}°'),
                        Text('Speed: ${speed.toStringAsFixed(3)} m/s'),
                        if (ssh != null)
                          Text('SSH: ${ssh.toStringAsFixed(3)} m'),
                      ],
                    ),
                    duration: const Duration(seconds: 3),
                    backgroundColor: const Color(0xFF1E293B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                debugPrint('🎯 Vector selected: lat=$lat, lon=$lon, speed=${speed.toStringAsFixed(3)}m/s, dir=${direction.toStringAsFixed(1)}°');
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
        );
      }

      final avgSpeed = speedCount > 0 ? totalSpeed / speedCount : 0.0;
      debugPrint('🌊 Built ${vectors.length} current vector markers');
      debugPrint('📊 SPEED STATS: min=${minSpeed.toStringAsFixed(4)} | max=${maxSpeed.toStringAsFixed(4)} | avg=${avgSpeed.toStringAsFixed(4)}');
      debugPrint('🎨 COLOR DISTRIBUTION: cyan=${colorDistribution['cyan']} | blue=${colorDistribution['blue']} | gradient=${colorDistribution['gradient']} | red=${colorDistribution['red']}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error building current vectors: $e');
      debugPrint('Stack trace: $stackTrace');
    }

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

    // Default color for other modes (shouldn't happen)
    debugPrint('⚠️ UNEXPECTED currentsColorBy: "${widget.currentsColorBy}" - using default cyan');
    return Colors.cyan.shade400;
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🗺️ MAP BUILD: rawData.length=${widget.rawData.length}');
    debugPrint('🗺️ MAP BUILD: temperature=${widget.mapLayerVisibility['temperature']}');
    debugPrint('🗺️ MAP BUILD: stationData=${widget.stationData.length}, currentsGeoJSON=${widget.currentsGeoJSON.isNotEmpty}');

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
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HeatmapPainter(
                  rawData: widget.rawData,
                  dataField: 'temp',
                  heatmapScale: widget.heatmapScale,
                  camera: _mapController.camera,
                ),
                size: Size.infinite,
              ),
            ),
          ),

        // Salinity heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['salinity'] ?? false))
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HeatmapPainter(
                  rawData: widget.rawData,
                  dataField: 'salinity',
                  heatmapScale: widget.heatmapScale,
                  camera: _mapController.camera,
                ),
                size: Size.infinite,
              ),
            ),
          ),

        // SSH heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['ssh'] ?? false))
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HeatmapPainter(
                  rawData: widget.rawData,
                  dataField: 'ssh',
                  heatmapScale: widget.heatmapScale,
                  camera: _mapController.camera,
                ),
                size: Size.infinite,
              ),
            ),
          ),

        // Pressure heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['pressure'] ?? false))
          IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: HeatmapPainter(
                  rawData: widget.rawData,
                  dataField: 'pressure_dbars',
                  heatmapScale: widget.heatmapScale,
                  camera: _mapController.camera,
                ),
                size: Size.infinite,
              ),
            ),
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

        // Loading indicator
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC4899)),
            ),
          ),

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

        // Vector info overlay
        if (_selectedVector != null)
          Positioned(
            bottom: 10,
            left: 10,
            child: _VectorInfoCard(
              vector: _selectedVector!,
              onClose: () {
                setState(() {
                  _selectedVector = null;
                });
              },
            ),
          ),

        // Map info overlay (date/time, depth, etc.)
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEC4899).withOpacity(0.3),
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
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (widget.currentTime.isNotEmpty)
                  Text(
                    widget.currentTime,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 11,
                    ),
                  ),
                if (widget.selectedDepth > 0)
                  Text(
                    'Depth: ${widget.selectedDepth.toStringAsFixed(1)}m',
                    style: TextStyle(
                      color: Colors.cyan.shade300,
                      fontSize: 11,
                    ),
                  ),
                if (widget.currentFrame > 0)
                  Text(
                    'Frame: ${widget.currentFrame}/${widget.totalFrames}',
                    style: TextStyle(
                      color: Colors.pink.shade300,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.black.withOpacity(0.8),
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
              style: TextStyle(
                color: Colors.black.withOpacity(0.7),
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
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.1),
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
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
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
            style: TextStyle(
              color: Colors.black.withOpacity(0.65),
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
              color: Colors.black,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Colors.black.withOpacity(0.8),
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
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.1),
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
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
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

/// Custom painter for rendering heatmaps (temperature, salinity, SSH, pressure)
class HeatmapPainter extends CustomPainter {
  final List<Map<String, dynamic>> rawData;
  final String dataField;
  final double heatmapScale;
  final MapCamera camera;

  HeatmapPainter({
    required this.rawData,
    required this.dataField,
    required this.heatmapScale,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (rawData.isEmpty) return;

    try {
      // Calculate zoom-dependent spacing and radius for proper scaling
      // Base spacing at zoom 10, scales proportionally with zoom level
      final zoomFactor = math.pow(2, camera.zoom - 10).toDouble();
      final sampleSpacing = (25.0 * zoomFactor).clamp(10.0, 100.0);
      final heatRadius = (sampleSpacing / 2 * heatmapScale).clamp(5.0, 50.0);

      // Create paint for heatmap points with sharper blur for better detail
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, heatRadius * 0.3);

      // Track drawn points to avoid overlap
      final drawnPoints = <String>{};
      int renderedPoints = 0;

      // Draw each data point as a colored circle
      for (final point in rawData) {
        if (point == null) continue;

        final lat = (point['lat'] as num?)?.toDouble();
        final lon = (point['lon'] as num?)?.toDouble();
        final value = (point[dataField] as num?)?.toDouble();

        if (lat == null || lon == null || value == null) continue;

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
        paint.color = color.withOpacity((0.85 * heatmapScale).clamp(0.3, 1.0));

        // Draw heatmap point with zoom-scaled radius for proper coverage
        canvas.drawCircle(
          Offset(screenPoint.dx, screenPoint.dy),
          heatRadius,
          paint,
        );

        renderedPoints++;
      }

      debugPrint('🎨 HeatmapPainter ($dataField): Rendered $renderedPoints/${rawData.length} points | zoom=${camera.zoom.toStringAsFixed(2)} radius=${heatRadius.toStringAsFixed(1)}');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error painting heatmap ($dataField): $e');
      debugPrint('Stack trace: $stackTrace');
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
      final paint = Paint()
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

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

            paint.color = color;

            // Draw particle as small circle
            canvas.drawCircle(
              Offset(screenPoint.dx, screenPoint.dy),
              2,
              paint..style = PaintingStyle.fill,
            );

            // Draw short trail
            if (speed > 0.001) {
              final trailEnd = Offset(
                screenPoint.dx - particle.vx * 5,
                screenPoint.dy - particle.vy * 5,
              );
              canvas.drawLine(
                Offset(screenPoint.dx, screenPoint.dy),
                trailEnd,
                paint..style = PaintingStyle.stroke,
              );
            }

            renderedParticles++;
          }
        } catch (e) {
          // Skip this particle and continue with others
          continue;
        }
      }

      debugPrint('🎨 ParticlePainter: Rendered $renderedParticles/${particles.length} particles');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error painting particles: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  /// Get velocity at nearest data point
  Map<String, double>? _getNearestVelocity(double lat, double lon) {
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

    return nearest;
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
      debugPrint('⚠️ Error painting grid: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.camera != camera ||
           oldDelegate.gridColor != gridColor ||
           oldDelegate.gridOpacity != gridOpacity;
  }
}