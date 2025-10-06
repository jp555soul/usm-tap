import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'connection_status_widget.dart';
import 'target_form_widget.dart';

// Assuming HoloOceanBloc exists from previous conversions
// import '../../blocs/holoocean/holoocean_bloc.dart';

/// Main HoloOcean control panel component
/// Provides interface for WebSocket connection management and agent control
class HoloOceanPanelWidget extends StatefulWidget {
  final bool autoConnect;

  const HoloOceanPanelWidget({
    Key? key,
    this.autoConnect = false,
  }) : super(key: key);

  @override
  State<HoloOceanPanelWidget> createState() => _HoloOceanPanelWidgetState();
}

class _HoloOceanPanelWidgetState extends State<HoloOceanPanelWidget> {
  bool _showAdvanced = false;
  bool _showRawData = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoConnect) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // context.read<HoloOceanBloc>().add(ConnectHoloOceanEvent());
      });
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return 'Unknown';
    try {
      final dt = DateTime.parse(timeStr);
      return '${dt.month}/${dt.day}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (e) {
      return timeStr;
    }
  }

  String _formatDistance(double? distance) {
    if (distance == null) return 'Unknown';
    if (distance < 1000) {
      return '${distance.toStringAsFixed(1)}m';
    }
    return '${(distance / 1000).toStringAsFixed(2)}km';
  }

  String _formatDepth(double? depth) {
    if (depth == null) return 'Unknown';
    return '${depth.toStringAsFixed(1)}m';
  }

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual BlocBuilder<HoloOceanBloc, HoloOceanState>
    // For now, using mock data
    return _buildPanel(
      isConnected: false,
      isConnecting: false,
      reconnectAttempts: 0,
      connectionError: null,
      isSubscribed: false,
      status: null,
      target: null,
      current: null,
      lastUpdated: null,
      isHoloOceanRunning: false,
      tickCount: 0,
      holoOceanError: null,
      hasTarget: false,
      hasCurrent: false,
      distanceToTarget: null,
      depthDifference: null,
      isAtTarget: false,
      error: null,
      serverError: null,
      isSettingTarget: false,
      isGettingStatus: false,
      connectionStatus: ConnectionStatusData(
        endpoint: 'ws://localhost:8080',
        readyState: 'CLOSED',
        maxAttempts: 5,
      ),
    );
  }

  Widget _buildPanel({
    required bool isConnected,
    required bool isConnecting,
    required int reconnectAttempts,
    required String? connectionError,
    required bool isSubscribed,
    required HoloOceanStatus? status,
    required TargetPosition? target,
    required CurrentPosition? current,
    required String? lastUpdated,
    required bool isHoloOceanRunning,
    required int tickCount,
    required String? holoOceanError,
    required bool hasTarget,
    required bool hasCurrent,
    required double? distanceToTarget,
    required double? depthDifference,
    required bool isAtTarget,
    required String? error,
    required String? serverError,
    required bool isSettingTarget,
    required bool isGettingStatus,
    required ConnectionStatusData connectionStatus,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'HoloOcean Agent Control',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ConnectionStatusWidget(
                isConnected: isConnected,
                isConnecting: isConnecting,
                reconnectAttempts: reconnectAttempts,
                error: connectionError,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Error Display
          if (error != null || serverError != null || connectionError != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.2),
                border: Border.all(color: Colors.red.shade700),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Error',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          serverError ?? error ?? connectionError ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () {
                      // context.read<HoloOceanBloc>().add(ClearErrorEvent());
                    },
                    tooltip: 'Clear error',
                  ),
                ],
              ),
            ),

          // Connection Controls
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade600),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!isConnected && !isConnecting)
                      ElevatedButton(
                        onPressed: () {
                          // context.read<HoloOceanBloc>().add(ConnectHoloOceanEvent());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Connect'),
                      ),
                    if (isConnected)
                      ElevatedButton(
                        onPressed: () {
                          // context.read<HoloOceanBloc>().add(DisconnectHoloOceanEvent());
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Disconnect'),
                      ),
                    if (connectionError != null || reconnectAttempts > 0)
                      ElevatedButton(
                        onPressed: isConnecting
                            ? null
                            : () {
                                // context.read<HoloOceanBloc>().add(ReconnectHoloOceanEvent());
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isConnecting ? 'Connecting...' : 'Reconnect'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Endpoint: ${connectionStatus.endpoint}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                Text(
                  'Status: ${connectionStatus.readyState}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (reconnectAttempts > 0)
                  Text(
                    'Reconnect attempts: $reconnectAttempts/${connectionStatus.maxAttempts}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
              ],
            ),
          ),

          // Target Setting Form
          if (isConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: TargetFormWidget(
                isLoading: isSettingTarget,
                onSetTarget: (lat, lon, depth, time) {
                  // context.read<HoloOceanBloc>().add(
                  //   SetTargetEvent(lat: lat, lon: lon, depth: depth, time: time),
                  // );
                },
              ),
            ),

          // Status Controls
          if (isConnected)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Updates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: isGettingStatus
                            ? null
                            : () {
                                // context.read<HoloOceanBloc>().add(GetStatusEvent());
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isGettingStatus ? 'Getting Status...' : 'Refresh Status'),
                      ),
                      if (!isSubscribed)
                        ElevatedButton(
                          onPressed: () {
                            // context.read<HoloOceanBloc>().add(SubscribeEvent());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Subscribe to Updates'),
                        )
                      else
                        ElevatedButton(
                          onPressed: () {
                            // context.read<HoloOceanBloc>().add(UnsubscribeEvent());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade600,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Unsubscribe'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isSubscribed)
                    const Text(
                      '✓ Receiving live updates (~1 second interval)',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                  if (lastUpdated != null)
                    Text(
                      'Last updated: ${_formatTime(lastUpdated)}',
                      style: const TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                ],
              ),
            ),

          // Current Status Display
          if (status != null)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade600),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Agent Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isHoloOceanRunning
                                  ? Colors.green.shade900.withOpacity(0.3)
                                  : Colors.red.shade900.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isHoloOceanRunning ? 'Running' : 'Stopped',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isHoloOceanRunning
                                    ? Colors.green.shade400
                                    : Colors.red.shade400,
                              ),
                            ),
                          ),
                          if (tickCount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Tick: ${tickCount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                              style: const TextStyle(fontSize: 12, color: Colors.white60),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Target Position
                  if (hasTarget && target != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade900.withOpacity(0.2),
                        border: Border.all(color: Colors.blue.shade700.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Position',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.blue.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Latitude: ${target.lat.toStringAsFixed(6)}°',
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade300),
                          ),
                          Text(
                            'Longitude: ${target.lon.toStringAsFixed(6)}°',
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade300),
                          ),
                          Text(
                            'Depth: ${_formatDepth(target.depth)}',
                            style: TextStyle(fontSize: 14, color: Colors.blue.shade300),
                          ),
                          if (target.time != null)
                            Text(
                              'Time: ${_formatTime(target.time)}',
                              style: TextStyle(fontSize: 14, color: Colors.blue.shade300),
                            ),
                        ],
                      ),
                    ),

                  // Current Position
                  if (hasCurrent && current != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900.withOpacity(0.2),
                        border: Border.all(color: Colors.green.shade700.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Position',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Latitude: ${current.lat.toStringAsFixed(6)}°',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade300),
                          ),
                          Text(
                            'Longitude: ${current.lon.toStringAsFixed(6)}°',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade300),
                          ),
                          Text(
                            'Depth: ${_formatDepth(current.depth)}',
                            style: TextStyle(fontSize: 14, color: Colors.green.shade300),
                          ),
                          if (current.time != null)
                            Text(
                              'Time: ${_formatTime(current.time)}',
                              style: TextStyle(fontSize: 14, color: Colors.green.shade300),
                            ),
                        ],
                      ),
                    ),

                  // Distance to Target
                  if (hasTarget && hasCurrent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.yellow.shade900.withOpacity(0.2),
                        border: Border.all(color: Colors.yellow.shade700.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Navigation',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.yellow.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Distance to target: ${_formatDistance(distanceToTarget)}',
                            style: TextStyle(fontSize: 14, color: Colors.yellow.shade300),
                          ),
                          if (depthDifference != null)
                            Text(
                              'Depth difference: ${_formatDistance(depthDifference)}',
                              style: TextStyle(fontSize: 14, color: Colors.yellow.shade300),
                            ),
                          Text(
                            isAtTarget ? '✓ At target position' : '→ Moving to target',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isAtTarget ? Colors.green.shade400 : Colors.yellow.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // HoloOcean Error
                  if (holoOceanError != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withOpacity(0.2),
                        border: Border.all(color: Colors.red.shade700.withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Simulation Error',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            holoOceanError,
                            style: TextStyle(fontSize: 14, color: Colors.red.shade300),
                          ),
                        ],
                      ),
                    ),

                  // Advanced Controls
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade600)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _showAdvanced = !_showAdvanced;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showAdvanced ? Icons.arrow_drop_down : Icons.arrow_right,
                                color: Colors.white70,
                              ),
                              const Text(
                                'Advanced Controls',
                                style: TextStyle(fontSize: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        if (_showAdvanced) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _showRawData = !_showRawData;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.grey.shade700,
                                  foregroundColor: Colors.white70,
                                  textStyle: const TextStyle(fontSize: 14),
                                ),
                                child: Text(_showRawData ? 'Hide Raw Data' : 'Show Raw Data'),
                              ),
                            ],
                          ),
                          if (_showRawData) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                border: Border.all(color: Colors.grey.shade600),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Raw Status Data',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Text(
                                      status.toJson(),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade900,
                              border: Border.all(color: Colors.grey.shade600),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Connection Info',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Table(
                                  columnWidths: const {
                                    0: FlexColumnWidth(1),
                                    1: FlexColumnWidth(1),
                                  },
                                  children: [
                                    TableRow(children: [
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          'Subscribed: ${isSubscribed ? 'Yes' : 'No'}',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          'Ready State: ${connectionStatus.readyState}',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        ),
                                      ),
                                    ]),
                                    TableRow(children: [
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          'Reconnects: $reconnectAttempts',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(4),
                                        child: Text(
                                          'Endpoint: ${connectionStatus.endpoint}',
                                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                                        ),
                                      ),
                                    ]),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // No Connection State
          if (!isConnected && !isConnecting)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade700,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wifi_off,
                        size: 32,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const Text(
                      'Not connected to HoloOcean',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Connect to start controlling the underwater agent',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                      ),
                    ),
                    if (connectionError != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade900.withOpacity(0.2),
                          border: Border.all(color: Colors.red.shade700),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Connection failed: $connectionError',
                          style: TextStyle(fontSize: 14, color: Colors.red.shade300),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: isConnecting
                          ? null
                          : () {
                              // context.read<HoloOceanBloc>().add(ConnectHoloOceanEvent());
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(isConnecting ? 'Connecting...' : 'Connect to HoloOcean'),
                    ),
                  ],
                ),
              ),
            ),

          // Loading State
          if (isConnecting)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 32),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 4),
                    const SizedBox(height: 12),
                    const Text(
                      'Connecting to HoloOcean...',
                      style: TextStyle(color: Colors.white70),
                    ),
                    if (reconnectAttempts > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Attempt $reconnectAttempts/${connectionStatus.maxAttempts}',
                          style: const TextStyle(fontSize: 14, color: Colors.white60),
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

// Supporting classes
class ConnectionStatusData {
  final String endpoint;
  final String readyState;
  final int maxAttempts;

  ConnectionStatusData({
    required this.endpoint,
    required this.readyState,
    required this.maxAttempts,
  });
}

class HoloOceanStatus {
  final bool running;
  final int tick;
  final String? error;

  HoloOceanStatus({
    required this.running,
    required this.tick,
    this.error,
  });

  String toJson() {
    return '{\n  "running": $running,\n  "tick": $tick,\n  "error": ${error != null ? '"$error"' : 'null'}\n}';
  }
}

class TargetPosition {
  final double lat;
  final double lon;
  final double depth;
  final String? time;

  TargetPosition({
    required this.lat,
    required this.lon,
    required this.depth,
    this.time,
  });
}

class CurrentPosition {
  final double lat;
  final double lon;
  final double depth;
  final String? time;

  CurrentPosition({
    required this.lat,
    required this.lon,
    required this.depth,
    this.time,
  });
}