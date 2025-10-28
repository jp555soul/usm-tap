import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'dart:io' show Platform;

/// Flutter widget that embeds the React MapContainer via WebView
/// Handles bidirectional communication between Flutter and React
class MapContainerWidget extends StatefulWidget {
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

  const MapContainerWidget({
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
  State<MapContainerWidget> createState() => _MapContainerWidgetState();
}

class _MapContainerWidgetState extends State<MapContainerWidget> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    // DEBUG: Track map instance creation
    debugPrint('🗺️ MAP INIT: ${DateTime.now()} - Instance: ${hashCode}');
    _initializeWebView();
  }

  @override
  void dispose() {
    // DEBUG: Track map instance disposal
    debugPrint('🗺️ MAP DISPOSE: ${DateTime.now()} - Instance: ${hashCode}');
    _isDisposed = true;
    // Note: WebViewController doesn't have an explicit dispose method
    // but marking _isDisposed prevents any pending operations from executing
    super.dispose();
  }

  Future<void> _initializeWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    
    // Only set background color on mobile platforms where it's supported
    // macOS doesn't support the setOpaque method used internally by setBackgroundColor
    if (Platform.isAndroid || Platform.isIOS) {
      _controller.setBackgroundColor(const Color(0x00000000));
    }
    
    _controller
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading status
            if (progress == 100 && !_isDisposed) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            if (!_isDisposed) {
              setState(() => _isLoading = true);
            }
          },
          onPageFinished: (String url) {
            if (!_isDisposed) {
              setState(() => _isLoading = false);
              _sendInitialData();
            }
          },
          onWebResourceError: (WebResourceError error) {
            if (!_isDisposed) {
              setState(() {
                _error = 'Failed to load map: ${error.description}';
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (!_isDisposed) {
            _handleMessageFromReact(message.message);
          }
        },
      );

    // Load HTML from assets using loadFlutterAsset to preserve relative paths
    try {
      if (!_isDisposed) {
        await _controller.loadFlutterAsset('assets/web/map_bridge.html');
      }
    } catch (e) {
      debugPrint('Error loading map_bridge.html: $e');
      // Fallback to inline HTML if asset loading fails
      final inlineHtml = _getInlineHtml();
      final dataUri = 'data:text/html;base64,${base64Encode(utf8.encode(inlineHtml))}';
      if (!_isDisposed) {
        await _controller.loadRequest(Uri.parse(dataUri));
      }
    }
  }

  /// Generate inline HTML that loads React and MapContainer
  /// This is a simplified version - in production, use a proper HTML file
  String _getInlineHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Map Container</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { 
      width: 100%; 
      height: 100%; 
      overflow: hidden; 
      background-color: #1e293b; 
      color: white;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
    }
    #root { 
      width: 100%; 
      height: 100%; 
      display: flex;
      align-items: center;
      justify-content: center;
      flex-direction: column;
      gap: 20px;
      padding: 40px;
    }
    .warning {
      background: rgba(236, 72, 153, 0.1);
      border: 2px solid rgb(236, 72, 153);
      padding: 20px;
      border-radius: 8px;
      max-width: 600px;
    }
    h2 { color: rgb(236, 72, 153); margin-bottom: 10px; }
    code { 
      background: rgba(0,0,0,0.3); 
      padding: 2px 6px; 
      border-radius: 3px;
      font-size: 0.9em;
    }
  </style>
</head>
<body>
  <div id="root">
    <div class="warning">
      <h2>⚠️ Map Bundle Not Configured</h2>
      <p>The React map bundle is not loaded. You need to either:</p>
      <ul style="margin: 15px 0; padding-left: 20px;">
        <li>Create <code>assets/web/map_bridge.html</code> with your React bundle</li>
        <li>Or update <code>_getInlineHtml()</code> with your bundle URL</li>
      </ul>
      <p>WebView is working - this message proves it.</p>
    </div>
  </div>
  
  <script>
    window.flutterBridge = {
      sendToFlutter: function(type, data) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({ type, data }));
        }
      },
      
      receiveFromFlutter: function(message) {
        console.log('Received from Flutter:', message);
      }
    };
    
    // Notify Flutter when ready
    window.addEventListener('load', function() {
      window.flutterBridge.sendToFlutter('MAP_READY', { message: 'WebView loaded but no map bundle' });
    });
  </script>
</body>
</html>
    ''';
  }

  /// Send initial data to React component after page loads
  void _sendInitialData() {
    if (_isDisposed) return;
    final props = _buildPropsObject();
    _sendMessageToReact('UPDATE_PROPS', props);
  }

  /// Convert any DateTime objects to ISO8601 strings for JSON serialization
  dynamic _serializeForJson(dynamic value) {
    if (value is DateTime) {
      return value.toIso8601String();
    } else if (value is Map) {
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        result[key.toString()] = _serializeForJson(val);
      });
      return result;
    } else if (value is List) {
      return value.map((item) => _serializeForJson(item)).toList();
    }
    return value;
  }

  /// Build props object from Flutter state
  Map<String, dynamic> _buildPropsObject() {
    return _serializeForJson({
      'stationData': widget.stationData,
      'timeSeriesData': widget.timeSeriesData,
      'rawData': widget.rawData,
      'totalFrames': widget.totalFrames,
      'currentFrame': widget.currentFrame,
      'selectedDepth': widget.selectedDepth,
      'selectedArea': widget.selectedArea,
      'holoOceanPOV': widget.holoOceanPOV,
      'currentDate': widget.currentDate,
      'currentTime': widget.currentTime,
      'mapboxToken': widget.mapboxToken,
      'isOutputCollapsed': widget.isOutputCollapsed,
      'initialViewState': widget.initialViewState,
      'mapLayerVisibility': widget.mapLayerVisibility,
      'currentsVectorScale': widget.currentsVectorScale,
      'currentsColorBy': widget.currentsColorBy,
      'heatmapScale': widget.heatmapScale,
      'availableDepths': widget.availableDepths,
      'currentsGeoJSON': widget.currentsGeoJSON,
    }) as Map<String, dynamic>;
  }

  /// Send message to React component
  void _sendMessageToReact(String type, dynamic data) {
    if (_isDisposed) return;
    final message = jsonEncode({'type': type, 'data': data});
    _controller.runJavaScript(
      'window.flutterBridge.receiveFromFlutter(\'${message.replaceAll("'", "\\'")}\')'
    );
  }

  /// Handle messages received from React
  void _handleMessageFromReact(String message) {
    if (_isDisposed) return;
    try {
      final decoded = jsonDecode(message);
      final type = decoded['type'];
      final data = decoded['data'];

      switch (type) {
        case 'POV_CHANGED':
          widget.onPOVChange?.call({
            'x': data['x'].toDouble(),
            'y': data['y'].toDouble(),
            'depth': data['depth'].toDouble(),
          });
          break;
        
        case 'DEPTH_CHANGED':
          widget.onDepthChange?.call(data['depth'].toDouble());
          break;
        
        case 'STATION_SELECTED':
          widget.onStationSelect?.call(data);
          break;
        
        case 'ENVIRONMENT_UPDATE':
          widget.onEnvironmentUpdate?.call(data);
          break;
        
        case 'MAP_ERROR':
          if (!_isDisposed) {
            setState(() => _error = data['message']);
          }
          break;
        
        default:
          // debugPrint('Unknown message type from React: $type');
      }
    } catch (e) {
      // debugPrint('Error handling message from React: $e');
    }
  }

  @override
  void didUpdateWidget(MapContainerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (_isDisposed) return;
    
    // DEBUG: Track widget updates
    if (oldWidget.currentFrame != widget.currentFrame) {
      debugPrint('🗺️ MAP UPDATE: Frame changed ${oldWidget.currentFrame} -> ${widget.currentFrame}');
    }
    
    // Send updates to React when props change
    if (oldWidget.currentFrame != widget.currentFrame) {
      _sendMessageToReact('UPDATE_FRAME', {'currentFrame': widget.currentFrame});
    }
    
    if (oldWidget.selectedDepth != widget.selectedDepth) {
      _sendMessageToReact('UPDATE_DEPTH', {'selectedDepth': widget.selectedDepth});
    }
    
    if (oldWidget.mapLayerVisibility != widget.mapLayerVisibility) {
      _sendMessageToReact('UPDATE_LAYER_VISIBILITY', widget.mapLayerVisibility);
    }
    
    // For complete prop updates
    if (oldWidget.rawData != widget.rawData ||
        oldWidget.stationData != widget.stationData ||
        oldWidget.timeSeriesData != widget.timeSeriesData) {
      final props = _buildPropsObject();
      _sendMessageToReact('UPDATE_PROPS', props);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // KEY: WebViewWidget with proper key to maintain identity
        WebViewWidget(
          key: ValueKey('webview_$hashCode'),
          controller: _controller,
        ),
        
        // Loading indicator
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(),
          ),
        
        // Error display
        if (_error != null)
          Center(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade700),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _isLoading = true;
                      });
                      _controller.reload();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}