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
  }) : super(key: key);

  @override
  State<NativeOceanMapWidget> createState() => _NativeOceanMapWidgetState();
}

class _NativeOceanMapWidgetState extends State<NativeOceanMapWidget> {
  late MapController _mapController;
  Map<String, dynamic>? _selectedStation;
  bool _isLoading = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    debugPrint('🗺️ NATIVE MAP INIT: ${DateTime.now()} - Instance: $hashCode');

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
    debugPrint('🗺️ NATIVE MAP DISPOSE: ${DateTime.now()} - Instance: $hashCode');
    _mapController.dispose();
    super.dispose();
  }

  void _initializeMapView() {
    try {
      final longitude = (widget.initialViewState['longitude'] as num?)?.toDouble() ?? -89.0;
      final latitude = (widget.initialViewState['latitude'] as num?)?.toDouble() ?? 30.1;
      final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 8.0;

      _mapController.move(LatLng(latitude, longitude), zoom);
    } catch (e) {
      debugPrint('Error initializing map view: $e');
    }
  }

  @override
  void didUpdateWidget(NativeOceanMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // DEBUG: Track widget updates
    if (oldWidget.currentFrame != widget.currentFrame) {
      debugPrint('🗺️ NATIVE MAP UPDATE: Frame changed ${oldWidget.currentFrame} -> ${widget.currentFrame}');
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
      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null) return [];

      for (final feature in features) {
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

        currentsData.add({
          'lat': lat,
          'lon': lon,
          'u': u,
          'v': v,
        });
      }
    } catch (e) {
      debugPrint('Error extracting currents data: $e');
    }

    return currentsData;
  }

  /// Build ocean currents vector markers
  List<Marker> _buildCurrentsVectorMarkers() {
    final showCurrents = widget.mapLayerVisibility['oceanCurrents'] ?? false;

    // DEBUG: Check currents data availability
    debugPrint('🌊 CURRENTS: currentsGeoJSON.isEmpty=${widget.currentsGeoJSON.isEmpty}');
    debugPrint('🌊 CURRENTS: rawData.length=${widget.rawData.length}');
    if (widget.rawData.isNotEmpty) {
      final sample = widget.rawData.first;
      debugPrint('🌊 CURRENTS: sample has ucur=${sample['ucur']}, vcur=${sample['vcur']}, direction=${sample['direction']}, nspeed=${sample['nspeed']}');
    }

    if (!showCurrents || widget.currentsGeoJSON.isEmpty) {
      return [];
    }

    final List<Marker> vectors = [];

    try {
      // Parse GeoJSON features
      final features = widget.currentsGeoJSON['features'] as List<dynamic>?;
      if (features == null) return [];

      for (final feature in features) {
        final geometry = feature['geometry'] as Map<String, dynamic>?;
        final properties = feature['properties'] as Map<String, dynamic>?;

        if (geometry == null || properties == null) continue;

        final coordinates = geometry['coordinates'] as List<dynamic>?;
        if (coordinates == null || coordinates.length < 2) continue;

        final lon = (coordinates[0] as num?)?.toDouble() ?? 0.0;
        final lat = (coordinates[1] as num?)?.toDouble() ?? 0.0;

        // Get velocity components
        final u = (properties['u'] as num?)?.toDouble() ?? 0.0;
        final v = (properties['v'] as num?)?.toDouble() ?? 0.0;
        final speed = math.sqrt(u * u + v * v);

        if (speed == 0) continue;

        // Calculate color based on speed
        final vectorColor = _getVectorColor(speed, properties);

        vectors.add(
          Marker(
            width: 30,
            height: 30,
            point: LatLng(lat, lon),
            child: CustomPaint(
              painter: _VectorArrowPainter(
                angle: math.atan2(v, u),
                length: (speed * widget.currentsVectorScale * 100).clamp(5.0, 30.0),
                color: vectorColor,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error building current vectors: $e');
    }

    return vectors;
  }

  /// Get color for vector based on speed
  Color _getVectorColor(double speed, Map<String, dynamic> properties) {
    if (widget.currentsColorBy == 'speed') {
      // Color by speed: blue (slow) to red (fast)
      final normalizedSpeed = (speed * 10).clamp(0.0, 1.0);
      return Color.lerp(
        Colors.blue.shade300,
        Colors.red.shade600,
        normalizedSpeed,
      ) ?? Colors.blue;
    }

    // Default color
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
    final zoom = (widget.initialViewState['zoom'] as num?)?.toDouble() ?? 8.0;

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
              // Deselect station when tapping on map
              if (_selectedStation != null) {
                setState(() {
                  _selectedStation = null;
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

        // Salinity heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['salinity'] ?? false))
          IgnorePointer(
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

        // SSH heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['ssh'] ?? false))
          IgnorePointer(
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

        // Pressure heatmap layer (overlay)
        if (_mapReady && (widget.mapLayerVisibility['pressure'] ?? false))
          IgnorePointer(
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

        // Particle animation layer for ocean currents (overlay)
        if (_mapReady && (widget.mapLayerVisibility['oceanCurrents'] ?? false))
          IgnorePointer(
            child: CustomPaint(
              painter: ParticlePainter(
                currentsData: _extractCurrentsData(),
                camera: _mapController.camera,
                vectorScale: widget.currentsVectorScale,
              ),
              size: Size.infinite,
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
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEC4899).withOpacity(0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: Colors.white.withOpacity(0.7),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (station['type'] != null)
            _InfoRow(
              label: 'Type',
              value: station['type'],
            ),
          _InfoRow(
            label: 'Latitude',
            value: (station['latitude'] as num?)?.toStringAsFixed(4) ?? 'N/A',
          ),
          _InfoRow(
            label: 'Longitude',
            value: (station['longitude'] as num?)?.toStringAsFixed(4) ?? 'N/A',
          ),
          if (station['description'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                station['description'],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
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

    // Spacing between sample points for reduced density
    const sampleSpacing = 50.0;

    // Create paint for heatmap points
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    // Track drawn points to avoid overlap
    final drawnPoints = <String>{};

    // Draw each data point as a colored circle
    for (final point in rawData) {
      final lat = (point['lat'] as num?)?.toDouble();
      final lon = (point['lon'] as num?)?.toDouble();
      final value = (point[dataField] as num?)?.toDouble();

      if (lat == null || lon == null || value == null) continue;

      // Convert lat/lon to screen coordinates
      final latLng = LatLng(lat, lon);
      final screenPoint = camera.latLngToScreenPoint(latLng);

      // Skip if point is outside visible area
      if (screenPoint.x < -100 || screenPoint.x > size.width + 100 ||
          screenPoint.y < -100 || screenPoint.y > size.height + 100) {
        continue;
      }

      // Sample points based on spacing to reduce density
      final gridX = (screenPoint.x / sampleSpacing).floor();
      final gridY = (screenPoint.y / sampleSpacing).floor();
      final gridKey = '$gridX,$gridY';

      // Skip if we've already drawn a point in this grid cell
      if (drawnPoints.contains(gridKey)) {
        continue;
      }
      drawnPoints.add(gridKey);

      // Get color based on value and data type
      final color = _getColorForValue(value, dataField);
      paint.color = color.withOpacity((0.7 * heatmapScale).clamp(0.0, 1.0));

      // Draw heatmap point with smaller radius
      canvas.drawCircle(
        Offset(screenPoint.x, screenPoint.y),
        sampleSpacing / 4,
        paint,
      );
    }
  }

  /// Get color based on value and data field type
  Color _getColorForValue(double value, String field) {
    switch (field) {
      case 'temp':
      case 'temperature':
        // Temperature: blue (cold) to red (warm)
        // Range: 0-30°C
        final normalized = ((value - 0) / 30).clamp(0.0, 1.0);
        return Color.lerp(
          Colors.blue.shade700,
          Colors.red.shade600,
          normalized,
        ) ?? Colors.blue;

      case 'salinity':
        // Salinity: green (low) to purple (high)
        // Range: 30-37 PSU
        final normalized = ((value - 30) / 7).clamp(0.0, 1.0);
        return Color.lerp(
          Colors.green.shade400,
          Colors.purple.shade600,
          normalized,
        ) ?? Colors.green;

      case 'ssh':
        // Sea Surface Height: blue (low) to yellow (high)
        // Range: -0.5 to 0.5 meters
        final normalized = ((value + 0.5) / 1.0).clamp(0.0, 1.0);
        return Color.lerp(
          Colors.blue.shade600,
          Colors.yellow.shade600,
          normalized,
        ) ?? Colors.blue;

      case 'pressure_dbars':
        // Pressure: cyan (low) to orange (high)
        // Range: 0-5000 dbars
        final normalized = (value / 5000).clamp(0.0, 1.0);
        return Color.lerp(
          Colors.cyan.shade400,
          Colors.orange.shade600,
          normalized,
        ) ?? Colors.cyan;

      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(HeatmapPainter oldDelegate) {
    return oldDelegate.rawData != rawData ||
           oldDelegate.dataField != dataField ||
           oldDelegate.heatmapScale != heatmapScale ||
           oldDelegate.camera != camera;
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
    this.particleCount = 2000,
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
    if (currentsData.isEmpty) return;

    final paint = Paint()
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Update and draw each particle
    for (final particle in particles) {
      // Convert particle position to lat/lon
      final bounds = camera.visibleBounds;
      final lat = bounds.south + particle.y * (bounds.north - bounds.south);
      final lon = bounds.west + particle.x * (bounds.east - bounds.west);

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
        final screenPoint = camera.latLngToScreenPoint(latLng);

        // Draw particle with trail
        final speed = math.sqrt(particle.vx * particle.vx + particle.vy * particle.vy);
        final opacity = (1 - particle.age / particle.maxAge).clamp(0.2, 0.8);
        final color = _getParticleColor(speed).withOpacity(opacity);

        paint.color = color;

        // Draw particle as small circle
        canvas.drawCircle(
          Offset(screenPoint.x, screenPoint.y),
          2,
          paint..style = PaintingStyle.fill,
        );

        // Draw short trail
        if (speed > 0.001) {
          final trailEnd = Offset(
            screenPoint.x - particle.vx * 5,
            screenPoint.y - particle.vy * 5,
          );
          canvas.drawLine(
            Offset(screenPoint.x, screenPoint.y),
            trailEnd,
            paint..style = PaintingStyle.stroke,
          );
        }
      }
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
           oldDelegate.camera != camera ||
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
      final topPoint = camera.latLngToScreenPoint(LatLng(bounds.north, lon));
      final bottomPoint = camera.latLngToScreenPoint(LatLng(bounds.south, lon));

      canvas.drawLine(
        Offset(topPoint.x, topPoint.y),
        Offset(bottomPoint.x, bottomPoint.y),
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
        Offset(topPoint.x - textPainter.width / 2, 5),
      );
    }

    // Draw latitude lines (horizontal)
    final startLat = (bounds.south / gridSpacing).floor() * gridSpacing;
    for (double lat = startLat; lat <= bounds.north; lat += gridSpacing) {
      final leftPoint = camera.latLngToScreenPoint(LatLng(lat, bounds.west));
      final rightPoint = camera.latLngToScreenPoint(LatLng(lat, bounds.east));

      canvas.drawLine(
        Offset(leftPoint.x, leftPoint.y),
        Offset(rightPoint.x, rightPoint.y),
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
        Offset(5, leftPoint.y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return oldDelegate.camera != camera ||
           oldDelegate.gridColor != gridColor ||
           oldDelegate.gridOpacity != gridOpacity;
  }
}
