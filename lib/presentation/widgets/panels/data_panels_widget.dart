import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:video_player/video_player.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../domain/entities/env_data_entity.dart';

// Assuming these BLoCs exist based on previous context
// import '../blocs/ocean_data/ocean_data_bloc.dart';
// import '../blocs/holoocean/holoocean_bloc.dart';

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

    final data = widget.timeSeriesData.length > range
        ? widget.timeSeriesData.sublist(widget.timeSeriesData.length - range)
        : widget.timeSeriesData;

    return data.asMap().entries.map((entry) {
      final value = (entry.value[dataKey] as num?)?.toDouble() ?? 0.0;
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
        final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1024;

        return GridView.count(
          crossAxisCount: isMobile ? 1 : isTablet ? 2 : 4,
          childAspectRatio: isMobile ? 1.2 : 1.0,
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          children: [
            // Video Panel (spans 2 columns on larger screens)
            if (!isMobile)
              GridTile(
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

            // Environmental Data Panel
            if (widget.showEnvironmental)
              _buildEnvironmentalPanel(dataQuality),

            // HoloOcean Panel
            if (widget.showHoloOcean)
              _buildHoloOceanPanel(),

            // Charts Panel
            if (widget.showCharts)
              _buildChartsPanel(),
          ],
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: dataQuality['color'],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dataQuality['level'],
                    style: TextStyle(
                      fontSize: 12,
                      color: dataQuality['color'],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              children: [
                _buildMetricCard(
                  'Temperature',
                  formatValue(widget.envData?.temperature ?? getCurrentValue('Temperature'), 'temperature'),
                  Icons.thermostat,
                  Colors.red.shade400,
                ),
                _buildMetricCard(
                  'Salinity',
                  formatValue(widget.envData?.salinity ?? getCurrentValue('Salinity'), 'salinity'),
                  Icons.water_drop,
                  Colors.blue.shade400,
                ),
                _buildMetricCard(
                  'Current Dir',
                  formatValue(widget.envData?.currentDirection ?? getCurrentValue('Current Direction'), 'direction'),
                  Icons.navigation,
                  Colors.cyan.shade400,
                ),
                _buildMetricCard(
                  'Wind Speed',
                  formatValue(widget.envData?.currentSpeed ?? getCurrentValue('Wind Speed'), 'speed'),
                  Icons.air,
                  Colors.amber.shade400,
                ),
                _buildMetricCard(
                  'Pressure',
                  formatValue(widget.envData?.pressure ?? getCurrentValue('Pressure'), 'pressure'),
                  Icons.compress,
                  Colors.purple.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade700.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
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
              DropdownButton<int>(
                value: _chartTimeRange,
                dropdownColor: Colors.grey.shade700,
                style: const TextStyle(fontSize: 12, color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 12, child: Text('12h')),
                  DropdownMenuItem(value: 24, child: Text('24h')),
                  DropdownMenuItem(value: 48, child: Text('48h')),
                ],
                onChanged: (value) {
                  setState(() {
                    _chartTimeRange = value ?? 24;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _buildChartCard(
                  'Wind Speed (m/s)',
                  formatValue(getCurrentValue('Wind Speed'), 'speed'),
                  getChartData('Wind Speed', _chartTimeRange),
                  Colors.amber.shade400,
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  'Current Direction (°)',
                  formatValue(getCurrentValue('Current Direction'), 'direction'),
                  getChartData('Current Direction', _chartTimeRange),
                  Colors.green.shade400,
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  'Sound Speed (m/s)',
                  formatValue(getCurrentValue('Sound Speed'), 'soundSpeed'),
                  getChartData('Sound Speed', _chartTimeRange),
                  Colors.green.shade300,
                ),
                const SizedBox(height: 16),
                _buildChartCard(
                  'Temperature (°F)',
                  formatValue(getCurrentValue('Temperature'), 'temperature'),
                  getChartData('Temperature', _chartTimeRange),
                  Colors.orange.shade400,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, String value, List<FlSpot> data, Color color) {
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
          SizedBox(
            height: 60,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.isEmpty ? [const FlSpot(0, 0)] : data,
                    isCurved: true,
                    color: color,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
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
