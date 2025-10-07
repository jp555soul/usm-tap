import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

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

  const MapWebViewContainer({
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
  }) : super(key: key);

  @override
  State<MapContainerWidget> createState() => _MapContainerWidgetState();
}

class _MapContainerWidgetState extends State<MapContainerWidget> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading status
            if (progress == 100) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _sendInitialData();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _error = 'Failed to load map: ${error.description}';
              _isLoading = false;
            });
          },
        ),
      )
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (JavaScriptMessage message) {
          _handleMessageFromReact(message.message);
        },
      )
      ..loadRequest(Uri.parse(_getMapHtmlUrl()));
  }

  /// Get URL for the HTML file that hosts the React MapContainer
  /// In production, this should point to your hosted HTML file
  /// For development, you can use assets or a local server
  String _getMapHtmlUrl() {
    // Option 1: Use a local asset (requires flutter pub add flutter_inappwebview or similar)
    // return 'file:///android_asset/flutter_assets/assets/map_bridge.html';
    
    // Option 2: Use a hosted URL
    // return 'https://your-domain.com/map_bridge.html';
    
    // Option 3: Use data URL with inline HTML (shown below for completeness)
    // return 'data:text/html;base64,${base64Encode(utf8.encode(_getInlineHtml()))}';
    return 'assets/web/map_bridge.html';
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
  <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    html, body { width: 100%; height: 100%; overflow: hidden; }
    #root { width: 100%; height: 100%; }
  </style>
</head>
<body>
  <div id="root"></div>
  
  <script>
    // JavaScript bridge for Flutter communication
    window.flutterBridge = {
      sendToFlutter: function(type, data) {
        if (window.FlutterBridge) {
          window.FlutterBridge.postMessage(JSON.stringify({ type, data }));
        }
      },
      
      receiveFromFlutter: function(message) {
        const { type, data } = JSON.parse(message);
        
        // Handle messages from Flutter
        switch(type) {
          case 'UPDATE_PROPS':
            window.updateMapProps(data);
            break;
          case 'UPDATE_FRAME':
            window.updateFrame(data.currentFrame);
            break;
          case 'UPDATE_DEPTH':
            window.updateDepth(data.selectedDepth);
            break;
          case 'UPDATE_LAYER_VISIBILITY':
            window.updateLayerVisibility(data);
            break;
          default:
            console.log('Unknown message type:', type);
        }
      }
    };
  </script>
  
  <!-- Load your bundled React app here -->
  <!-- In production, this would be your built React bundle -->
  <script src="YOUR_REACT_BUNDLE_URL"></script>
  
  <script>
    // Notify Flutter when map is ready
    window.addEventListener('load', function() {
      window.flutterBridge.sendToFlutter('MAP_READY', {});
    });
  </script>
</body>
</html>
    ''';
  }

  /// Send initial data to React component after page loads
  void _sendInitialData() {
    final props = _buildPropsObject();
    _sendMessageToReact('UPDATE_PROPS', props);
  }

  /// Build props object from Flutter state
  Map<String, dynamic> _buildPropsObject() {
    return {
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
    };
  }

  /// Send message to React component
  void _sendMessageToReact(String type, dynamic data) {
    final message = jsonEncode({'type': type, 'data': data});
    _controller.runJavaScript(
      'window.flutterBridge.receiveFromFlutter(\'${message.replaceAll("'", "\\'")}\')'
    );
  }

  /// Handle messages received from React
  void _handleMessageFromReact(String message) {
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
          setState(() => _error = data['message']);
          break;
        
        default:
          debugPrint('Unknown message type from React: $type');
      }
    } catch (e) {
      debugPrint('Error handling message from React: $e');
    }
  }

  @override
  void didUpdateWidget(MapContainerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    
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
        WebViewWidget(controller: _controller),
        
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