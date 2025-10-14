// lib/presentation/widgets/panels/control_panel.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MapLayer {
  final String key;
  final String label;
  final IconData icon;
  final String color;

  const MapLayer({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
  });
}

const List<MapLayer> allMapLayers = [
  MapLayer(key: 'oceanCurrents', label: 'Ocean Currents', icon: Icons.navigation_rounded, color: 'blue'),
  MapLayer(key: 'temperature', label: 'Temperature', icon: Icons.thermostat_rounded, color: 'red'),
  MapLayer(key: 'ssh', label: 'Sea Surface Elevation', icon: Icons.bar_chart_rounded, color: 'indigo'),
  MapLayer(key: 'salinity', label: 'Salinity', icon: Icons.water_drop_rounded, color: 'emerald'),
  MapLayer(key: 'pressure', label: 'Pressure', icon: Icons.speed_rounded, color: 'orange'),
  MapLayer(key: 'windVelocity', label: 'Wind Velocity', icon: Icons.flash_on_rounded, color: 'red'),
];

class ControlPanel extends StatefulWidget {
  final bool isLoading;
  final String selectedArea;
  final String selectedModel;
  final double selectedDepth;
  final DateTime? startDate;
  final DateTime? endDate;
  final String timeZone;
  final int currentFrame;
  final double playbackSpeed;
  final String loopMode;
  final Map<String, double> holoOceanPOV;
  final Map<String, bool> mapLayerVisibility;
  final bool isSstHeatmapVisible;
  final double currentsVectorScale;
  final String currentsColorBy;
  final List<String> availableModels;
  final List<double> availableDepths;
  final int totalFrames;
  final List<dynamic> data;
  final bool dataLoaded;
  final double heatmapScale;
  final bool isPlaying;

  // Callbacks
  final ValueChanged<String>? onAreaChange;
  final ValueChanged<String>? onModelChange;
  final ValueChanged<double>? onDepthChange;
  final Function(DateTime start, DateTime end)? onDateRangeChange;
  final ValueChanged<String>? onTimeZoneChange;
  final ValueChanged<double>? onSpeedChange;
  final ValueChanged<String>? onLoopModeChange;
  final ValueChanged<int>? onFrameChange;
  final VoidCallback? onReset;
  final ValueChanged<String>? onLayerToggle;
  final VoidCallback? onSstHeatmapToggle;
  final ValueChanged<double>? onCurrentsScaleChange;
  final ValueChanged<String>? onCurrentsColorChange;
  final ValueChanged<double>? onHeatmapScaleChange;
  final VoidCallback? togglePlay;

  const ControlPanel({
    Key? key,
    this.isLoading = false,
    this.selectedArea = '',
    this.selectedModel = 'NGOFS2',
    this.selectedDepth = 0,
    this.startDate,
    this.endDate,
    this.timeZone = 'UTC',
    this.currentFrame = 0,
    this.playbackSpeed = 10,
    this.loopMode = 'Repeat',
    this.holoOceanPOV = const {'x': 0, 'y': 0, 'depth': 0},
    this.mapLayerVisibility = const {},
    this.isSstHeatmapVisible = false,
    this.currentsVectorScale = 0.009,
    this.currentsColorBy = 'speed',
    this.availableModels = const [],
    this.availableDepths = const [],
    this.totalFrames = 24,
    this.data = const [],
    this.dataLoaded = false,
    this.heatmapScale = 1,
    this.isPlaying = false,
    this.onAreaChange,
    this.onModelChange,
    this.onDepthChange,
    this.onDateRangeChange,
    this.onTimeZoneChange,
    this.onSpeedChange,
    this.onLoopModeChange,
    this.onFrameChange,
    this.onReset,
    this.onLayerToggle,
    this.onSstHeatmapToggle,
    this.onCurrentsScaleChange,
    this.onCurrentsColorChange,
    this.onHeatmapScaleChange,
    this.togglePlay,
  }) : super(key: key);

  @override
  State<ControlPanel> createState() => _ControlPanelState();
}

class _ControlPanelState extends State<ControlPanel> {
  bool _showLayerControls = true;
  bool _showLayerToggles = false;
  Map<String, String> _errors = {};

  @override
  void didUpdateWidget(ControlPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _validateInputs();
  }

  void _validateInputs() {
    final newErrors = <String, String>{};
    if (widget.selectedDepth < 0) {
      newErrors['depth'] = 'Depth cannot be negative';
    }
    if (widget.dataLoaded &&
        widget.availableModels.isNotEmpty &&
        widget.selectedModel.isNotEmpty &&
        !widget.availableModels.contains(widget.selectedModel)) {
      newErrors['model'] = 'Model "${widget.selectedModel}" not found';
    }
    setState(() => _errors = newErrors);
  }

  Color _getLayerIconColor(String color) {
    switch (color) {
      case 'blue': return Colors.blue[400]!;
      case 'red': return Colors.red[400]!;
      case 'indigo': return Colors.indigo[400]!;
      case 'emerald': return Colors.green[400]!;
      case 'orange': return Colors.orange[400]!;
      default: return Colors.grey[400]!;
    }
  }

  Color _getLayerButtonColor(String color) {
    switch (color) {
      case 'blue': return Colors.blue[600]!;
      case 'red': return Colors.red[600]!;
      case 'indigo': return Colors.indigo[600]!;
      case 'emerald': return Colors.green[600]!;
      case 'orange': return Colors.orange[600]!;
      default: return Colors.grey[600]!;
    }
  }

  String _getLayerEmoji(String key) {
    switch (key) {
      case 'oceanCurrents': return '🌊';
      case 'temperature': return '🌡️';
      case 'ssh': return '🌊';
      case 'salinity': return '🧂';
      case 'pressure': return '⚖️';
      case 'windVelocity': return '⚡';
      default: return '';
    }
  }

  List<MapLayer> _getActiveLayers() {
    return allMapLayers.where((layer) => widget.mapLayerVisibility[layer.key] == true).toList();
  }

  bool get _isAnyVectorLayerActive {
    return widget.mapLayerVisibility['oceanCurrents'] == true ||
           widget.mapLayerVisibility['windVelocity'] == true;
  }

  bool get _isAnyHeatmapLayerActive {
    const heatmapKeys = ['temperature', 'salinity', 'pressure'];
    return heatmapKeys.any((key) => widget.mapLayerVisibility[key] == true);
  }

  String _getFrameTimeDisplay() {
    if (widget.data.isNotEmpty && widget.currentFrame < widget.data.length) {
      final frameData = widget.data[widget.currentFrame];
      if (frameData is Map && frameData.containsKey('time')) {
        try {
          final time = DateTime.parse(frameData['time']);
          return DateFormat('MMM d, y HH:mm:ss').format(time);
        } catch (e) {
          return 'Frame ${widget.currentFrame + 1} of ${widget.totalFrames}';
        }
      }
    }
    return 'Frame ${widget.currentFrame + 1} of ${widget.totalFrames}';
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: widget.startDate != null && widget.endDate != null
          ? DateTimeRange(start: widget.startDate!, end: widget.endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Colors.pink[600]!,
              surface: const Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && widget.onDateRangeChange != null) {
      widget.onDateRangeChange!(picked.start, picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.pink[500]!.withOpacity(0.2))),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.pink[900]!.withOpacity(0.1),
            Colors.purple[900]!.withOpacity(0.1),
          ],
        ),
      ),
      padding: EdgeInsets.all(isSmall ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isSmall),
          SizedBox(height: isSmall ? 8 : 16),
          _buildMainControls(isSmall),
          const SizedBox(height: 16),
          _buildLayerControls(isSmall),
          const SizedBox(height: 16),
          _buildAnimationControls(isSmall),
          const SizedBox(height: 16),
          _buildFooter(isSmall),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmall) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.bar_chart_rounded, size: isSmall ? 16 : 20, color: Colors.pink[300]),
            const SizedBox(width: 8),
            Text(
              '${widget.selectedModel.isEmpty ? "Ocean Model" : widget.selectedModel} Control Panel',
              style: TextStyle(
                fontSize: isSmall ? 14 : 16,
                fontWeight: FontWeight.w600,
                color: Colors.pink[300],
              ),
            ),
          ],
        ),
        if (widget.isLoading)
          Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.cyan[400]!),
                ),
              ),
              const SizedBox(width: 4),
              Text('Loading...', style: TextStyle(fontSize: 12, color: Colors.cyan[400])),
            ],
          )
        else if (!widget.dataLoaded)
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.yellow[400],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text('Initializing', style: TextStyle(fontSize: 12, color: Colors.yellow[400])),
            ],
          ),
      ],
    );
  }

  Widget _buildMainControls(bool isSmall) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLarge = constraints.maxWidth >= 1024;
        return Wrap(
          spacing: isSmall ? 8 : 16,
          runSpacing: isSmall ? 8 : 16,
          children: [
            _buildAreaSelector(isSmall, isLarge),
            _buildModelSelector(isSmall, isLarge),
            _buildDateSelector(isSmall, isLarge),
            _buildDepthSelector(isSmall, isLarge),
          ],
        );
      },
    );
  }

  Widget _buildAreaSelector(bool isSmall, bool isLarge) {
    // Validate that the selected value exists in the dropdown items
    // If "default" or invalid, use 'USM' as the default
    const validAreas = ['', 'USM', 'MBL', 'MSR'];
    final safeValue = validAreas.contains(widget.selectedArea) 
        ? (widget.selectedArea.isEmpty ? 'USM' : widget.selectedArea)
        : 'USM';
    
    return SizedBox(
      width: isLarge ? 200 : (isSmall ? double.infinity : 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text('Study Area', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: safeValue,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
              border: OutlineInputBorder(borderSide: BorderSide(color: const Color(0xFF475569))),
              filled: true,
              fillColor: const Color(0xFF334155),
            ),
            style: TextStyle(fontSize: isSmall ? 12 : 14, color: Colors.white),
            dropdownColor: const Color(0xFF334155),
            items: const [
              DropdownMenuItem(value: 'USM', child: Text('USM')),
              DropdownMenuItem(value: 'MBL', child: Text('MBL')),
              DropdownMenuItem(value: 'MSR', child: Text('MSR')),
            ],
            onChanged: (value) => widget.onAreaChange?.call(value ?? 'USM'),
          ),
        ],
      ),
    );
  }
  Widget _buildModelSelector(bool isSmall, bool isLarge) {
    return SizedBox(
      width: isLarge ? 200 : (isSmall ? double.infinity : 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.layers_rounded, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text('Ocean Model', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: widget.selectedModel,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _errors.containsKey('model') ? Colors.red[500]! : const Color(0xFF475569),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFF334155),
            ),
            style: TextStyle(fontSize: isSmall ? 12 : 14, color: Colors.white),
            dropdownColor: const Color(0xFF334155),
            items: widget.availableModels.isEmpty
                ? [const DropdownMenuItem(value: '', child: Text('Loading...'))]
                : widget.availableModels.map((model) {
                    return DropdownMenuItem(value: model, child: Text(model));
                  }).toList(),
            onChanged: widget.dataLoaded && widget.availableModels.isNotEmpty
                ? (value) => widget.onModelChange?.call(value ?? '')
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isSmall, bool isLarge) {
    return SizedBox(
      width: isLarge ? 250 : (isSmall ? double.infinity : 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text('Date/Time Range', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: widget.dataLoaded ? _selectDateRange : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 12, vertical: 12),
              alignment: Alignment.centerLeft,
            ),
            child: Text(
              widget.startDate != null && widget.endDate != null
                  ? '${DateFormat('M/d/y').format(widget.startDate!)} - ${DateFormat('M/d/y').format(widget.endDate!)}'
                  : 'Select Range',
              style: TextStyle(fontSize: isSmall ? 12 : 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepthSelector(bool isSmall, bool isLarge) {
    return SizedBox(
      width: isLarge ? 200 : (isSmall ? double.infinity : 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 12, color: const Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text('Depth (m)', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8))),
            ],
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<double>(
            value: widget.selectedDepth,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 4 : 8, vertical: 4),
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: _errors.containsKey('depth') ? Colors.red[500]! : const Color(0xFF475569),
                ),
              ),
              filled: true,
              fillColor: const Color(0xFF334155),
            ),
            style: TextStyle(fontSize: isSmall ? 12 : 14, color: Colors.white),
            dropdownColor: const Color(0xFF334155),
            items: widget.availableDepths.isEmpty
                ? [const DropdownMenuItem(value: 0.0, child: Text('Loading...'))]
                : widget.availableDepths.map((depth) {
                    return DropdownMenuItem(
                      value: depth,
                      child: Text(depth == 0 ? '0 m (Surface)' : '$depth m'),
                    );
                  }).toList(),
            onChanged: widget.dataLoaded && widget.availableDepths.isNotEmpty
                ? (value) => widget.onDepthChange?.call(value ?? 0)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLayerControls(bool isSmall) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF475569))),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.settings_rounded, size: 12, color: const Color(0xFFCBD5E1)),
                  const SizedBox(width: 4),
                  const Text('Map Controls', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFCBD5E1))),
                ],
              ),
              TextButton(
                onPressed: () => setState(() => _showLayerControls = !_showLayerControls),
                child: Text(_showLayerControls ? 'Hide' : 'Show', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
              ),
            ],
          ),
          if (_showLayerControls) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 768 ? 3 : 1;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: columns == 3 ? constraints.maxWidth / 3 - 8 : double.infinity,
                      child: _buildLayerToggles(),
                    ),
                    SizedBox(
                      width: columns == 3 ? constraints.maxWidth / 3 - 8 : double.infinity,
                      child: _buildLayerSettings(),
                    ),
                    SizedBox(
                      width: columns == 3 ? constraints.maxWidth / 3 - 8 : double.infinity,
                      child: _buildLayerInfo(),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLayerToggles() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.map_rounded, size: 12, color: const Color(0xFFCBD5E1)),
                const SizedBox(width: 4),
                const Text('Map Layers', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFFCBD5E1))),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _showLayerToggles = !_showLayerToggles),
              child: Text(_showLayerToggles ? 'Hide' : 'Show', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          ],
        ),
        if (_showLayerToggles) ...[
          const SizedBox(height: 8),
          ...allMapLayers.map((layer) {
            final isActive = widget.mapLayerVisibility[layer.key] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(layer.icon, size: 12, color: const Color(0xFFCBD5E1)),
                      const SizedBox(width: 8),
                      Text(layer.label, style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1))),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: widget.dataLoaded ? () => widget.onLayerToggle?.call(layer.key) : null,
                    icon: Icon(isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 12),
                    label: Text(isActive ? 'On' : 'Off', style: const TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isActive ? _getLayerButtonColor(layer.color) : const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: const Size(60, 28),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildLayerSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Heatmap Scale', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: widget.heatmapScale,
                min: 0.1,
                max: 2.0,
                divisions: 38,
                onChanged: widget.dataLoaded && _isAnyHeatmapLayerActive
                    ? (value) => widget.onHeatmapScaleChange?.call(value)
                    : null,
                activeColor: Colors.red[500],
              ),
            ),
            SizedBox(
              width: 48,
              child: Text('${widget.heatmapScale.toStringAsFixed(2)}x', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLayerInfo() {
    final activeLayers = _getActiveLayers();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Active Layers:', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        if (activeLayers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Text('No layers active', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          )
        else
          ...activeLayers.map((layer) => Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  '${_getLayerEmoji(layer.key)} ${layer.label}',
                  style: TextStyle(fontSize: 12, color: _getLayerIconColor(layer.color)),
                ),
              )),
      ],
    );
  }

  Widget _buildAnimationControls(bool isSmall) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 768 ? 2 : 1;
        return Wrap(
          spacing: isSmall ? 8 : 16,
          runSpacing: isSmall ? 8 : 16,
          children: [
            SizedBox(
              width: columns == 2 ? constraints.maxWidth / 2 - 8 : double.infinity,
              child: _buildPlaybackControls(isSmall),
            ),
            SizedBox(
              width: columns == 2 ? constraints.maxWidth / 2 - 8 : double.infinity,
              child: _buildSpeedControls(isSmall),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPlaybackControls(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Animation', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              onPressed: widget.dataLoaded && widget.totalFrames > 1
                  ? () {
                      final prevFrame = widget.currentFrame > 0 ? widget.currentFrame - 1 : widget.totalFrames - 1;
                      widget.onFrameChange?.call(prevFrame);
                    }
                  : null,
              icon: const Icon(Icons.skip_previous_rounded, size: 16),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.dataLoaded && widget.totalFrames > 1 ? widget.togglePlay : null,
                icon: Icon(widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 16),
                label: Text(widget.isPlaying ? 'Pause' : 'Play', style: const TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.dataLoaded && widget.totalFrames > 1
                  ? () {
                      final nextFrame = (widget.currentFrame + 1) % widget.totalFrames;
                      widget.onFrameChange?.call(nextFrame);
                    }
                  : null,
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: widget.dataLoaded ? widget.onReset : null,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFF475569), foregroundColor: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpeedControls(bool isSmall) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Speed: ${widget.playbackSpeed.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: widget.playbackSpeed,
                min: 0.1,
                max: 20.0,
                divisions: 199,
                onChanged: widget.dataLoaded ? (value) => widget.onSpeedChange?.call(value) : null,
                activeColor: Colors.pink[500],
              ),
            ),
            Wrap(
              spacing: 4,
              children: [1.0, 5.0, 10.0, 20.0].map((speed) {
                return SizedBox(
                  width: 32,
                  child: ElevatedButton(
                    onPressed: widget.dataLoaded ? () => widget.onSpeedChange?.call(speed) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF475569),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(32, 24),
                    ),
                    child: Text('${speed.toInt()}x', style: const TextStyle(fontSize: 10)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter(bool isSmall) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Wrap(
          spacing: 16,
          children: [
            Text('Frame: ${widget.currentFrame + 1}/${widget.totalFrames}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            Text('Loop: ${widget.loopMode}', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time_rounded, size: 12, color: const Color(0xFF94A3B8)),
            const SizedBox(width: 4),
            Text(_getFrameTimeDisplay(), style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          ],
        ),
      ],
    );
  }
}