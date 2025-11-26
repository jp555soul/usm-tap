import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../../domain/entities/env_data_entity.dart';



class DataPanelsWidget extends StatefulWidget {
  final EnvDataEntity? envData;
  final Map<String, double>? holoOceanPOV;
  final double selectedDepth;
  final String selectedParameter;
  final List<Map<String, dynamic>> timeSeriesData;
  final int currentFrame;
  final List<double> availableDepths;
  final bool showHoloOcean;
  final bool showEnvironmental;
  final bool showCharts;
  final bool showAdvancedMetrics;
  final Function(double)? onDepthChange;
  final Function(String)? onParameterChange;
  final Function(Map<String, double>)? onPOVChange;
  final VoidCallback? onRefreshData;

  const DataPanelsWidget({
    Key? key,
    this.envData,
    this.holoOceanPOV,
    this.selectedDepth = 0,
    this.selectedParameter = 'Wind Speed',
    this.timeSeriesData = const [],
    this.currentFrame = 0,
    this.availableDepths = const [],
    this.showHoloOcean = true,
    this.showEnvironmental = true,
    this.showCharts = true,
    this.showAdvancedMetrics = false,
    this.onDepthChange,
    this.onParameterChange,
    this.onPOVChange,
    this.onRefreshData,
  }) : super(key: key);

  @override
  State<DataPanelsWidget> createState() => _DataPanelsWidgetState();
}

class _DataPanelsWidgetState extends State<DataPanelsWidget> {
  late VideoPlayerController _videoController;
  String? _expandedPanel;
  int _chartTimeRange = 24;
  bool _isStreaming = true;
  
  // Track window start indices for each metric to enable correct tooltip timestamps
  final Map<String, int> _chartWindowStarts = {};

  // Parameter mapping
  final Map<String, String> parameterMapping = {
    'Wind Speed': 'currentSpeed',
    'Current Direction': 'heading',
    'Temperature': 'temperature',
    'Sound Speed': 'soundSpeed',
    'SSH': 'ssh',
    'Salinity': 'salinity',
    'Pressure': 'pressure',
    'Wind Direction': 'windDirection',
  };

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _startStreamingSimulation();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset('assets/vids/recording.mp4')
      ..initialize().then((_) {
        setState(() {});
        _videoController.setLooping(true);
        _videoController.setPlaybackSpeed(1.8);
        _videoController.play();
      });
  }

  void _startStreamingSimulation() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isStreaming = true;
        });
        _startStreamingSimulation();
      }
    });
  }

  double get maxDepth {
    if (widget.availableDepths.isEmpty) return 200;
    return widget.availableDepths.reduce((a, b) => a > b ? a : b);
  }

  Map<String, dynamic>? getCurrentData() {
    if (widget.timeSeriesData.isEmpty) return null;
    final dataIndex = widget.currentFrame < widget.timeSeriesData.length
        ? widget.currentFrame
        : widget.timeSeriesData.length - 1;
    final data = widget.timeSeriesData[dataIndex];
    final dataKey = parameterMapping[widget.selectedParameter] ?? 'currentSpeed';
    return {...data, 'selectedValue': data[dataKey]};
  }

  String formatValue(dynamic value, String type) {
    if (value == null || (value is num && value.isNaN)) return 'No Data';
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0;
    
    switch (type) {
      case 'temperature':
        return '${numValue.toStringAsFixed(2)}°F';
      case 'salinity':
        return '${numValue.toStringAsFixed(2)} PSU';
      case 'pressure':
        return '${numValue.toStringAsFixed(1)} dbar';
      case 'depth':
        return '${numValue.toInt()} m';
      case 'speed':
        return '${numValue.toStringAsFixed(3)} m/s';
      case 'direction':
        return '${numValue.toStringAsFixed(1)}°';
      case 'height':
        return '${numValue.toStringAsFixed(2)} m';
      case 'soundSpeed':
        return '${numValue.toStringAsFixed(2)} m/s';
      case 'windSpeed':
        return '${numValue.toStringAsFixed(2)} m/s';
      case 'distance':
        return numValue < 1000
            ? '${numValue.toStringAsFixed(1)}m'
            : '${(numValue / 1000).toStringAsFixed(2)}km';
      case 'coordinate':
        return '${numValue.toStringAsFixed(6)}°';
      default:
        return numValue.toString();
    }
  }

  Map<String, dynamic> getDataQuality() {
    if (widget.timeSeriesData.isEmpty) {
      return {'level': 'No Data', 'color': Colors.red.shade400};
    }

    final lastItem = widget.timeSeriesData.last;
    final timestamp = lastItem['timestamp'] ?? lastItem['time'] ?? DateTime.now().millisecondsSinceEpoch;
    final dataAge = DateTime.now().millisecondsSinceEpoch - 
        (timestamp is DateTime ? timestamp.millisecondsSinceEpoch : timestamp as int);
    final hoursOld = dataAge / (1000 * 60 * 60);

    if (hoursOld < 1) return {'level': 'Real-time', 'color': Colors.green.shade400};
    if (hoursOld < 6) return {'level': 'Recent', 'color': Colors.blue.shade400};
    if (hoursOld < 24) return {'level': 'Delayed', 'color': Colors.yellow.shade400};
    return {'level': 'Historical', 'color': Colors.orange.shade400};
  }

  List<FlSpot> getChartData(String metric, int range) {
    final dataKey = parameterMapping[metric] ?? 'currentSpeed';
    
    if (widget.timeSeriesData.isEmpty) return [];

    final len = widget.timeSeriesData.length;
    
    // Handle "All" selection
    if (range == -1) {
      _chartWindowStarts[metric] = 0;
      return widget.timeSeriesData.asMap().entries.map((entry) {
        final value = (entry.value[dataKey] as num?)?.toDouble() ?? 0.0;
        return FlSpot(entry.key.toDouble(), value);
      }).toList();
    }
    
    // Smart Window Logic: Try to center currentFrame in the window
    int start = widget.currentFrame - (range ~/ 2);
    
    // Clamp start to bounds
    if (start < 0) start = 0;
    if (start + range > len) start = len - range;
    if (start < 0) start = 0; // Handle case where len < range

    final end = (start + range).clamp(0, len);
    
    // Store the window start for this metric so tooltips can use it
    _chartWindowStarts[metric] = start;
    
    final data = widget.timeSeriesData.sublist(start, end);

    return data.asMap().entries.map((entry) {
      final value = (entry.value[dataKey] as num?)?.toDouble() ?? 0.0;
      // Use relative index (0 to range) for sliding window effect
      return FlSpot(entry.key.toDouble(), value);
    }).toList();
  }

  dynamic getCurrentValue(String parameter) {
    final currentData = getCurrentData();
    if (currentData == null) return null;
    final dataKey = parameterMapping[parameter] ?? 'currentSpeed';
    return currentData[dataKey];
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataQuality = getDataQuality();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;

        if (isMobile) {
          // Mobile layout - single column
          return Column(
            children: [
              if (widget.showCharts) _buildChartsPanel(),
              if (widget.showHoloOcean) _buildHoloOceanPanel(),
              if (widget.showEnvironmental) _buildEnvironmentalPanel(dataQuality),
              const SizedBox(height: 24),
            ],
          );
        }

        // Desktop layout
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // First row: Time Series Analysis (full width)
              if (widget.showCharts)
                SizedBox(
                  height: 650,
                  child: _buildChartsPanel(),
                ),
              const SizedBox(height: 16),
              // Second row: HoloOcean Video (50%) | HoloOcean Viz (25%) | Environmental Data (25%)
              SizedBox(
                height: 700,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // HoloOcean Video Panel (50%)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green.shade900.withOpacity(0.2),
                              Colors.teal.shade900.withOpacity(0.2),
                            ],
                          ),
                          border: Border.all(color: Colors.green.shade500.withOpacity(0.1)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _videoController.value.isInitialized
                              ? AspectRatio(
                                  aspectRatio: _videoController.value.aspectRatio,
                                  child: VideoPlayer(_videoController),
                                )
                              : const Center(child: CircularProgressIndicator()),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // HoloOcean Viz Panel (25%)
                    if (widget.showHoloOcean)
                      Expanded(
                        flex: 1,
                        child: _buildHoloOceanPanel(),
                      ),
                    const SizedBox(width: 16),
                    // Environmental Data Panel (25%)
                    if (widget.showEnvironmental)
                      Expanded(
                        flex: 1,
                        child: _buildEnvironmentalPanel(dataQuality),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnvironmentalPanel(Map<String, dynamic> dataQuality) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.analytics, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Environmental Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Historical',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildNewMetricCard(
                  title: 'Temperature',
                  value: widget.envData?.temperature ?? getCurrentValue('Temperature'),
                  unit: '°F',
                  icon: Icons.thermostat,
                  color: const Color(0xFFEF5350), // Red
                  type: 'temperature',
                ),
                _buildNewMetricCard(
                  title: 'Salinity',
                  value: widget.envData?.salinity ?? getCurrentValue('Salinity'),
                  unit: 'PSU',
                  icon: Icons.water_drop,
                  color: const Color(0xFF42A5F5), // Blue
                  type: 'salinity',
                ),
                _buildNewMetricCard(
                  title: 'Current Dir',
                  value: widget.envData?.currentDirection ?? getCurrentValue('Current Direction'),
                  unit: '°',
                  icon: Icons.navigation,
                  color: const Color(0xFF26A69A), // Teal
                  type: 'direction',
                  isCompass: true,
                ),
                _buildNewMetricCard(
                  title: 'Wind Speed',
                  value: widget.envData?.currentSpeed ?? getCurrentValue('Wind Speed'),
                  unit: 'm/s',
                  icon: Icons.air,
                  color: const Color(0xFFFFCA28), // Amber/Yellow
                  type: 'speed',
                ),
                _buildNewMetricCard(
                  title: 'Pressure',
                  value: widget.envData?.pressure ?? getCurrentValue('Pressure'),
                  unit: 'hPa',
                  icon: Icons.compress,
                  color: const Color(0xFFAB47BC), // Purple
                  type: 'pressure',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewMetricCard({
    required String title,
    required dynamic value,
    required String unit,
    required IconData icon,
    required Color color,
    required String type,
    bool isCompass = false,
  }) {
    final numValue = value is num ? value : double.tryParse(value.toString()) ?? 0.0;
    final displayValue = numValue.toStringAsFixed(type == 'pressure' ? 0 : 2); // Pressure usually integer-like
    
    // Get historical data for sparkline
    final sparklineData = getChartData(title, 24); // Last 24 points

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D3E), // Dark card background
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          
          // Gauge Area
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size(120, 60),
                  painter: isCompass 
                      ? _CompassGaugePainter(color: color, degrees: numValue.toDouble())
                      : _RadialGaugePainter(
                          color: color, 
                          percent: _calculatePercent(type, numValue.toDouble()),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayValue,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        unit,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer (Value + Sparkline)
          Expanded(
            flex: 1,
            child: Row(
              children: [
                Text(
                  '$displayValue $unit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      minX: sparklineData.isNotEmpty ? sparklineData.first.x : 0,
                      maxX: sparklineData.isNotEmpty ? sparklineData.last.x : 0,
                      minY: sparklineData.isNotEmpty 
                          ? sparklineData.map((e) => e.y).reduce(math.min) 
                          : 0.0,
                      maxY: sparklineData.isNotEmpty 
                          ? sparklineData.map((e) => e.y).reduce(math.max) 
                          : 1.0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: sparklineData,
                          isCurved: true,
                          color: color,
                          barWidth: 2,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _calculatePercent(String type, double value) {
    // Approximate ranges for visualization
    switch (type) {
      case 'temperature': // 0 - 100 F
        return (value / 100).clamp(0.0, 1.0);
      case 'salinity': // 0 - 40 PSU
        return (value / 40).clamp(0.0, 1.0);
      case 'speed': // 0 - 20 m/s
        return (value / 20).clamp(0.0, 1.0);
      case 'pressure': // 950 - 1050 hPa (normalized)
        return ((value - 950) / 100).clamp(0.0, 1.0);
      default:
        return 0.5;
    }
  }

  Widget _buildHoloOceanPanel() {
    final pov = widget.holoOceanPOV ?? {'x': 0.0, 'y': 0.0, 'depth': 0.0};
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.shade900.withOpacity(0.2),
            Colors.teal.shade900.withOpacity(0.2),
          ],
        ),
        border: Border.all(color: Colors.green.shade500.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.explore, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'HoloOcean Visualization',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _isStreaming 
                          ? Colors.green.shade600.withOpacity(0.2)
                          : Colors.red.shade600.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isStreaming ? Colors.green : Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isStreaming ? 'Connected' : 'Offline',
                          style: TextStyle(
                            fontSize: 12,
                            color: _isStreaming ? Colors.green.shade400 : Colors.red.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _expandedPanel == 'holo' ? Icons.fullscreen_exit : Icons.fullscreen,
                      size: 16,
                      color: Colors.green.shade400,
                    ),
                    onPressed: () {
                      setState(() {
                        _expandedPanel = _expandedPanel == 'holo' ? null : 'holo';
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '3D Environmental Data Display',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.shade900.withOpacity(0.3),
                    Colors.blue.shade900.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade500.withOpacity(0.2)),
              ),
              child: Stack(
                children: [
                  // Center placeholder
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.green.shade400.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.green.shade400.withOpacity(0.5),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                              Center(
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade400.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'HoloOcean 3D Stream',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isStreaming ? 'WebRTC Connected' : 'Connecting...',
                          style: const TextStyle(fontSize: 12, color: Colors.white60),
                        ),
                      ],
                    ),
                  ),
                  // Status badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isStreaming ? Colors.green.shade600 : Colors.yellow.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _isStreaming ? 'LIVE' : 'BUFFER',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Text(
                      'POV: ${pov['x']?.toStringAsFixed(1)}, ${pov['y']?.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12, color: Colors.green),
                    ),
                  ),
                  // Depth profile
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Depth Profile',
                                style: TextStyle(fontSize: 12, color: Colors.white60),
                              ),
                              Text(
                                '${widget.selectedDepth.toInt()}m',
                                style: const TextStyle(fontSize: 12, color: Colors.white60),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTapDown: (details) {
                              final box = context.findRenderObject() as RenderBox?;
                              if (box != null) {
                                final localX = details.localPosition.dx;
                                final width = box.size.width;
                                final newDepth = (localX / width * maxDepth).round().toDouble();
                                widget.onDepthChange?.call(newDepth);
                              }
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF3B82F6),
                                    Color(0xFF60A5FA),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(
                                    left: (widget.selectedDepth / maxDepth) * 100,
                                    child: Container(
                                      width: 4,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.yellow.shade400,
                                        borderRadius: BorderRadius.circular(2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.yellow.shade400.withOpacity(0.5),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Surface',
                                style: TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                              Text(
                                '200m',
                                style: TextStyle(fontSize: 10, color: Colors.white60),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.trending_up, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Time Series Analysis',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Depth dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton<double>(
                      value: widget.selectedDepth,
                      dropdownColor: Colors.grey.shade700,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white70),
                      onChanged: widget.availableDepths.isNotEmpty
                          ? (value) {
                              if (value != null) {
                                widget.onDepthChange?.call(value);
                              }
                            }
                          : null,
                      items: widget.availableDepths.isEmpty
                          ? [const DropdownMenuItem(value: 0, child: Text('0m'))]
                          : widget.availableDepths.map((depth) {
                              return DropdownMenuItem<double>(
                                value: depth,
                                child: Text('${depth.toInt()}m'),
                              );
                            }).toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Time range dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: DropdownButton<int>(
                      value: _chartTimeRange,
                      dropdownColor: Colors.grey.shade700,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, size: 20, color: Colors.white70),
                      onChanged: (value) {
                        setState(() {
                          _chartTimeRange = value ?? 24;
                        });
                      },
                      items: const [
                        DropdownMenuItem(value: 12, child: Text('12h')),
                        DropdownMenuItem(value: 24, child: Text('24h')),
                        DropdownMenuItem(value: 48, child: Text('48h')),
                        DropdownMenuItem(value: -1, child: Text('All')),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildChartCard(
                    'Wind Speed (m/s)',
                    formatValue(getCurrentValue('Wind Speed'), 'speed'),
                    getChartData('Wind Speed', _chartTimeRange),
                    Colors.amber.shade400,
                    _chartTimeRange,
                    'Wind Speed',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildChartCard(
                    'Current Direction (°)',
                    formatValue(getCurrentValue('Current Direction'), 'direction'),
                    getChartData('Current Direction', _chartTimeRange),
                    Colors.green.shade400,
                    _chartTimeRange,
                    'Current Direction',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildChartCard(
                    'Sound Speed (m/s)',
                    formatValue(getCurrentValue('Sound Speed'), 'soundSpeed'),
                    getChartData('Sound Speed', _chartTimeRange),
                    Colors.green.shade300,
                    _chartTimeRange,
                    'Sound Speed',
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _buildChartCard(
                    'Temperature (°F)',
                    formatValue(getCurrentValue('Temperature'), 'temperature'),
                    getChartData('Temperature', _chartTimeRange),
                    Colors.orange.shade400,
                    _chartTimeRange,
                    'Temperature',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String value, List<FlSpot> data, Color color, int range, String metricKey) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12, color: Colors.white60),
              ),
              Text(
                value,
                style: TextStyle(fontSize: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: range == -1 
                    ? (widget.timeSeriesData.isEmpty ? 0 : widget.timeSeriesData.length - 1).toDouble()
                    : (range - 1).toDouble(),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.grey.shade800.withOpacity(0.9),
                    tooltipRoundedRadius: 8,
                    tooltipPadding: const EdgeInsets.all(8),
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        // Calculate the actual data index by adding window start offset
                        final chartIndex = touchedSpot.x.toInt();
                        final windowStart = _chartWindowStarts[metricKey] ?? 0;
                        final actualDataIndex = windowStart + chartIndex;
                        
                        // Get the timestamp from the time series data
                        String dateTimeStr = '';
                        String valueStr = touchedSpot.y.toStringAsFixed(2);
                        
                        if (widget.timeSeriesData.isNotEmpty && actualDataIndex < widget.timeSeriesData.length) {
                          final dataPoint = widget.timeSeriesData[actualDataIndex];
                          final timestamp = dataPoint['timestamp'] ?? dataPoint['time'];
                          
                          if (timestamp != null) {
                            final dateTime = timestamp is DateTime 
                                ? timestamp 
                                : DateTime.fromMillisecondsSinceEpoch(timestamp as int);
                            
                            // Format date and time
                            final date = '${dateTime.month}/${dateTime.day}/${dateTime.year}';
                            final time = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                            dateTimeStr = '$date\n$time';
                          }
                        }
                        
                        
                        return LineTooltipItem(
                          '$dateTimeStr\n$title\n$valueStr',
                          TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.isEmpty ? [const FlSpot(0, 0)] : data,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    // Show dots on all data points so users know where to hover
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 3,
                          color: color,
                          strokeWidth: 1,
                          strokeColor: color.withOpacity(0.5),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadialGaugePainter extends CustomPainter {
  final Color color;
  final double percent;

  _RadialGaugePainter({required this.color, required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = math.min(size.width / 2, size.height);
    final strokeWidth = 12.0;

    // Background Arc
    final bgPaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi,
      math.pi,
      false,
      bgPaint,
    );

    // Foreground Arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      math.pi,
      math.pi * percent,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialGaugePainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.color != color;
  }
}

class _CompassGaugePainter extends CustomPainter {
  final Color color;
  final double degrees;

  _CompassGaugePainter({required this.color, required this.degrees});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10); // Adjust center
    final radius = math.min(size.width / 2, size.height / 2) - 5;

    // Compass Circle
    final circlePaint = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, circlePaint);

    // Ticks
    final tickPaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 1;

    for (int i = 0; i < 360; i += 45) {
      final angle = i * math.pi / 180;
      final p1 = Offset(
        center.dx + (radius - 5) * math.cos(angle),
        center.dy + (radius - 5) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Arrow
    final angle = (degrees - 90) * math.pi / 180; // -90 to point 0 degrees North (up)
    final arrowLength = radius - 10;
    
    final arrowPath = Path();
    final tip = Offset(
      center.dx + arrowLength * math.cos(angle),
      center.dy + arrowLength * math.sin(angle),
    );
    final base1 = Offset(
      center.dx + 6 * math.cos(angle + 2.5), // ~140 degrees
      center.dy + 6 * math.sin(angle + 2.5),
    );
    final base2 = Offset(
      center.dx + 6 * math.cos(angle - 2.5),
      center.dy + 6 * math.sin(angle - 2.5),
    );

    arrowPath.moveTo(tip.dx, tip.dy);
    arrowPath.lineTo(base1.dx, base1.dy);
    arrowPath.lineTo(base2.dx, base2.dy);
    arrowPath.close();

    final arrowPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(arrowPath, arrowPaint);
    
    // Center Dot
    canvas.drawCircle(center, 3, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _CompassGaugePainter oldDelegate) {
    return oldDelegate.degrees != degrees || oldDelegate.color != color;
  }
}
