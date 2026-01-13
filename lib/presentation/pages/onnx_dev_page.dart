import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:usm_tap/core/services/onnx_inference_service.dart';
import 'package:usm_tap/injection_container.dart';

/// ONNX Scenario Lab - Widget for testing and demonstrating ONNX capabilities
/// with mock oceanographic analysis scenarios.
class OnnxScenarioLab extends StatefulWidget {
  const OnnxScenarioLab({super.key});

  @override
  State<OnnxScenarioLab> createState() => _OnnxScenarioLabState();
}

class _OnnxScenarioLabState extends State<OnnxScenarioLab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Service and session state
  late OnnxInferenceService _onnxService;
  bool _isInitialized = false;
  String _statusMessage = 'Ready to initialize...';
  bool _isLoading = false;
  
  // Mock inference results
  Map<String, dynamic>? _inferenceResults;
  
  // Demo scenario inputs
  final _sstController = TextEditingController(text: '22.5');
  final _salinityController = TextEditingController(text: '35.2');
  final _currentUController = TextEditingController(text: '0.15');
  final _currentVController = TextEditingController(text: '-0.08');
  final _waveHeightController = TextEditingController(text: '1.2');
  final _windSpeedController = TextEditingController(text: '8.5');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _onnxService = sl<OnnxInferenceService>();
    // Auto-init for smoother UX in the new separate tab
    _initializeOnnx();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sstController.dispose();
    _salinityController.dispose();
    _currentUController.dispose();
    _currentVController.dispose();
    _waveHeightController.dispose();
    _windSpeedController.dispose();
    super.dispose();
  }

  Future<void> _initializeOnnx() async {
    if (_isInitialized) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Initializing Runtime...';
    });

    try {
      await _onnxService.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _statusMessage = 'Runtime Ready';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _runMockInference(String scenario) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Running $scenario...';
      _inferenceResults = null;
    });

    // Simulate inference delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Generate mock results based on scenario
    final results = _generateMockResults(scenario);

    if (mounted) {
      setState(() {
        _inferenceResults = results;
        _statusMessage = '$scenario complete';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _generateMockResults(String scenario) {
    switch (scenario) {
      case 'SST Prediction':
        final currentSST = double.tryParse(_sstController.text) ?? 22.5;
        return {
          'scenario': 'Sea Surface Temperature Prediction',
          'input': {'current_sst': currentSST},
          'prediction': {
            '+6h': (currentSST + 0.3 + (DateTime.now().millisecond % 10) / 20).toStringAsFixed(2),
            '+12h': (currentSST + 0.5 + (DateTime.now().millisecond % 10) / 15).toStringAsFixed(2),
            '+24h': (currentSST + 0.8 + (DateTime.now().millisecond % 10) / 10).toStringAsFixed(2),
          },
          'confidence': '${85 + (DateTime.now().second % 10)}%',
          'model': 'sst_predictor_v1.onnx',
        };

      case 'Anomaly Detection':
        final u = double.tryParse(_currentUController.text) ?? 0.15;
        final v = double.tryParse(_currentVController.text) ?? -0.08;
        final magnitude = (u * u + v * v);
        final isAnomaly = magnitude > 0.05;
        return {
          'scenario': 'Current Velocity Anomaly Detection',
          'input': {'current_u': u, 'current_v': v},
          'analysis': {
            'magnitude': magnitude.toStringAsFixed(4),
            'direction': '${(180 * (v / (u + 0.001)).abs() / 3.14159).toStringAsFixed(1)}°',
            'is_anomaly': isAnomaly,
            'anomaly_score': isAnomaly ? '0.${75 + DateTime.now().second % 20}' : '0.${15 + DateTime.now().second % 15}',
          },
          'confidence': '${90 + (DateTime.now().second % 8)}%',
          'model': 'current_anomaly_v2.onnx',
        };

      case 'Salinity Estimation':
        final salinity = double.tryParse(_salinityController.text) ?? 35.2;
        final sst = double.tryParse(_sstController.text) ?? 22.5;
        return {
          'scenario': 'Salinity Gradient Estimation',
          'input': {'surface_salinity': salinity, 'sst': sst},
          'estimation': {
            'depth_10m': (salinity + 0.2).toStringAsFixed(2),
            'depth_50m': (salinity + 0.5).toStringAsFixed(2),
            'depth_100m': (salinity + 0.8).toStringAsFixed(2),
            'thermocline_depth': '${25 + DateTime.now().second % 20}m',
          },
          'confidence': '${82 + (DateTime.now().second % 12)}%',
          'model': 'salinity_gradient_v1.onnx',
        };

      case 'Wave Forecast':
        final waveHeight = double.tryParse(_waveHeightController.text) ?? 1.2;
        final windSpeed = double.tryParse(_windSpeedController.text) ?? 8.5;
        return {
          'scenario': 'Wave Height Forecasting',
          'input': {'current_wave_height': waveHeight, 'wind_speed': windSpeed},
          'forecast': {
            '+3h': (waveHeight + windSpeed * 0.05).toStringAsFixed(2),
            '+6h': (waveHeight + windSpeed * 0.08).toStringAsFixed(2),
            '+12h': (waveHeight + windSpeed * 0.12).toStringAsFixed(2),
            'max_expected': (waveHeight + windSpeed * 0.15).toStringAsFixed(2),
          },
          'wave_period': '${6 + (DateTime.now().second % 4)}s',
          'confidence': '${78 + (DateTime.now().second % 15)}%',
          'model': 'wave_forecast_v3.onnx',
        };

      default:
        return {'error': 'Unknown scenario'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Custom Header for Lab
        Container(
          color: const Color(0xFF1E293B),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.science, color: Colors.purpleAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Scenario Simulation',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    _buildStatusBadge(),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                labelColor: Colors.white,
                unselectedLabelColor: const Color(0xFF94A3B8),
                isScrollable: true,
                tabs: const [
                  Tab(icon: Icon(Icons.thermostat), text: 'SST'),
                  Tab(icon: Icon(Icons.warning_amber), text: 'Anomaly'),
                  Tab(icon: Icon(Icons.water_drop), text: 'Salinity'),
                  Tab(icon: Icon(Icons.waves), text: 'Waves'),
                ],
              ),
            ],
          ),
        ),
        
        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSSTTab(),
              _buildAnomalyTab(),
              _buildSalinityTab(),
              _buildWaveTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _isInitialized ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isInitialized ? Colors.green.withOpacity(0.5) : Colors.orange.withOpacity(0.5),
        ),
      ),
      child: Text(
        _statusMessage,
        style: TextStyle(
          color: _isInitialized ? Colors.green : Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSSTTab() {
    return _buildScenarioTab(
      title: 'Sea Surface Temperature Prediction',
      description: 'Predict future SST based on current conditions using ML.',
      icon: Icons.thermostat,
      iconColor: Colors.orange,
      inputs: [
        _buildInputField('Current SST (°C)', _sstController, Icons.thermostat),
      ],
      scenarioKey: 'SST Prediction',
    );
  }

  Widget _buildAnomalyTab() {
    return _buildScenarioTab(
      title: 'Current Velocity Anomaly Detection',
      description: 'Detect unusual current patterns that may indicate events.',
      icon: Icons.warning_amber,
      iconColor: Colors.red,
      inputs: [
        _buildInputField('Current U (m/s)', _currentUController, Icons.arrow_forward),
        _buildInputField('Current V (m/s)', _currentVController, Icons.arrow_upward),
      ],
      scenarioKey: 'Anomaly Detection',
    );
  }

  Widget _buildSalinityTab() {
    return _buildScenarioTab(
      title: 'Salinity Gradient Estimation',
      description: 'Estimate salinity at different depths from surface readings.',
      icon: Icons.water_drop,
      iconColor: Colors.blue,
      inputs: [
        _buildInputField('Surface Salinity (PSU)', _salinityController, Icons.water_drop),
        _buildInputField('SST (°C)', _sstController, Icons.thermostat),
      ],
      scenarioKey: 'Salinity Estimation',
    );
  }

  Widget _buildWaveTab() {
    return _buildScenarioTab(
      title: 'Wave Height Forecasting',
      description: 'Forecast wave heights for coastal safety and navigation.',
      icon: Icons.waves,
      iconColor: Colors.cyan,
      inputs: [
        _buildInputField('Current Wave Height (m)', _waveHeightController, Icons.waves),
        _buildInputField('Wind Speed (m/s)', _windSpeedController, Icons.air),
      ],
      scenarioKey: 'Wave Forecast',
    );
  }

  Widget _buildScenarioTab({
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required List<Widget> inputs,
    required String scenarioKey,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Inputs Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Input Parameters',
                  style: TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...inputs,
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _runMockInference(scenarioKey),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(_isLoading ? 'Running...' : 'Run Inference'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: iconColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Results Section
          if (_inferenceResults != null && _inferenceResults!['scenario'] == _getScenarioFullName(scenarioKey))
            _buildResultsDisplay(_inferenceResults!),
        ],
      ),
    );
  }

  String _getScenarioFullName(String key) {
    switch (key) {
      case 'SST Prediction':
        return 'Sea Surface Temperature Prediction';
      case 'Anomaly Detection':
        return 'Current Velocity Anomaly Detection';
      case 'Salinity Estimation':
        return 'Salinity Gradient Estimation';
      case 'Wave Forecast':
        return 'Wave Height Forecasting';
      default:
        return key;
    }
  }

  Widget _buildInputField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsDisplay(Map<String, dynamic> results) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Inference Results',
                style: TextStyle(
                  color: Color(0xFF22C55E),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                'Confidence: ${results['confidence']}',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Model: ${results['model']}',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildResultRows(results),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResultRows(Map<String, dynamic> results) {
    final rows = <Widget>[];
    
    // Find the main result key (prediction, analysis, estimation, forecast)
    final resultKeys = ['prediction', 'analysis', 'estimation', 'forecast'];
    for (final key in resultKeys) {
      if (results.containsKey(key) && results[key] is Map) {
        final data = results[key] as Map;
        for (final entry in data.entries) {
          rows.add(_buildResultRow(
            entry.key.toString(),
            entry.value.toString(),
            entry.value is bool
                ? (entry.value ? Colors.red : Colors.green)
                : const Color(0xFF60A5FA),
          ));
        }
      }
    }
    
    // Add extra fields
    if (results.containsKey('wave_period')) {
      rows.add(_buildResultRow('Wave Period', results['wave_period'], const Color(0xFF60A5FA)));
    }
    
    return rows;
  }

  Widget _buildResultRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
