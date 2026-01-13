import 'package:flutter/material.dart';
import 'package:usm_tap/core/services/onnx_inference_service.dart';
import 'package:usm_tap/injection_container.dart';
import 'package:usm_tap/presentation/pages/onnx_dev_page.dart'; // Will reuse ScenarioLab widget from here

class OnnxManagementPage extends StatefulWidget {
  const OnnxManagementPage({super.key});

  @override
  State<OnnxManagementPage> createState() => _OnnxManagementPageState();
}

class _OnnxManagementPageState extends State<OnnxManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OnnxInferenceService _onnxService = sl<OnnxInferenceService>();

  // Model State
  OnnxModelInfo? _selectedModel;
  dynamic _currentSession;
  bool _isLoading = false;
  Map<String, dynamic>? _modelMetadata;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_currentSession != null) {
      _onnxService.releaseSession(_currentSession);
    }
    super.dispose();
  }

  Future<void> _loadModel(OnnxModelInfo model) async {
    setState(() {
      _isLoading = true;
      _error = null;
      if (_currentSession != null) {
        _onnxService.releaseSession(_currentSession);
        _currentSession = null;
        _modelMetadata = null;
      }
    });

    try {
      final session = await _onnxService.createSession(model.assetPath);
      
      // Extract metadata
      final inputs = _onnxService.getSessionInputNames(session);
      final outputs = _onnxService.getSessionOutputNames(session);

      setState(() {
        _currentSession = session;
        _selectedModel = model;
        _modelMetadata = {
          'inputs': inputs,
          'outputs': outputs,
          'status': 'Loaded',
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('ONNX Management'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          tabs: const [
            Tab(text: 'Model Registry', icon: Icon(Icons.list)),
            Tab(text: 'Inspector', icon: Icon(Icons.analytics)),
            Tab(text: 'Scenario Lab', icon: Icon(Icons.science)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildModelRegistry(),
          _buildModelInspector(),
          // Re-using the refactored widget from dev page
          const OnnxScenarioLab(), 
        ],
      ),
    );
  }

  Widget _buildModelRegistry() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kAvailableOnnxModels.length,
      itemBuilder: (context, index) {
        final model = kAvailableOnnxModels[index];
        final isSelected = _selectedModel?.name == model.name;

        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Icon(
              Icons.api, 
              color: isSelected ? Colors.green : Colors.blueGrey
            ),
            title: Text(
              model.name, 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
            ),
            subtitle: Text(
              model.description,
              style: const TextStyle(color: Colors.grey),
            ),
            trailing: isSelected 
              ? const Icon(Icons.check_circle, color: Colors.green)
              : ElevatedButton(
                  onPressed: _isLoading ? null : () => _loadModel(model),
                  child: const Text('Load'),
                ),
            onTap: () => _loadModel(model),
          ),
        );
      },
    );
  }

  Widget _buildModelInspector() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                'Error loading model: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedModel == null || _currentSession == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'Select a model from the Registry to inspect',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Model Details',
            [
              _buildDetailRow('Name', _selectedModel!.name),
              _buildDetailRow('Path', _selectedModel!.assetPath),
              _buildDetailRow('Status', 'Active Session'),
            ],
            Icons.memory,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Inputs',
            (_modelMetadata!['inputs'] as List<String>).map((e) => 
              _buildDetailRow('Tensor', e)
            ).toList(),
            Icons.input,
            Colors.orange,
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Outputs',
            (_modelMetadata!['outputs'] as List<String>).map((e) => 
              _buildDetailRow('Tensor', e)
            ).toList(),
            Icons.output,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.white24, height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
